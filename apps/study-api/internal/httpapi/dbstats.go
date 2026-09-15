package httpapi

import (
	"context"
	"net/http"
	"time"
)

// TEMPORARY diagnostic (founder-requested): aggregate storage report of the
// live Neon database. JWT-gated like every student route, but returns ONLY
// engine-level metadata — table sizes, row counts, per-bank key counts —
// never answer content or personal data. Remove once read.
type dbTable struct {
	Schema     string `json:"schema"`
	Table      string `json:"table"`
	TotalBytes int64  `json:"total_bytes"`
	Total      string `json:"total"`
	Heap       string `json:"heap"`
	Indexes    string `json:"indexes"`
	Toast      string `json:"toast"`
	RowEst     int64  `json:"row_estimate"`
}

// handleDBStats reports what actually consumes space in the database.
func (s *Server) handleDBStats(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	out := map[string]any{}

	var dbName, version string
	var dbBytes int64
	if err := s.store.Pool.QueryRow(ctx,
		`SELECT current_database(), version()::text, pg_database_size(current_database())`,
	).Scan(&dbName, &version, &dbBytes); err == nil {
		out["database"] = dbName
		out["postgres_version"] = version
		out["database_bytes"] = dbBytes
		out["database_pretty"] = humanBytes(dbBytes)
	}

	rows, err := s.store.Pool.Query(ctx, `
		SELECT n.nspname,
		       c.relname,
		       pg_total_relation_size(c.oid),
		       pg_relation_size(c.oid),
		       pg_indexes_size(c.oid),
		       COALESCE(pg_total_relation_size(c.reltoastrelid), 0),
		       GREATEST(c.reltuples, 0)::bigint
		FROM pg_class c
		JOIN pg_namespace n ON n.oid = c.relnamespace
		WHERE c.relkind = 'r'
		  AND n.nspname NOT IN ('pg_catalog','information_schema')
		  AND n.nspname NOT LIKE 'pg_toast%'
		  AND n.nspname NOT LIKE '\_pg%'
		ORDER BY pg_total_relation_size(c.oid) DESC
		LIMIT 30`)
	if err == nil {
		defer rows.Close()
		tables := []dbTable{}
		for rows.Next() {
			var t dbTable
			var total, heap, idx, toast int64
			if err := rows.Scan(&t.Schema, &t.Table, &total, &heap, &idx, &toast, &t.RowEst); err == nil {
				t.TotalBytes = total
				t.Total = humanBytes(total)
				t.Heap = humanBytes(heap)
				t.Indexes = humanBytes(idx)
				t.Toast = humanBytes(toast)
				tables = append(tables, t)
			}
		}
		out["tables"] = tables
	}

	srow, err := s.store.Pool.Query(ctx, `
		SELECT n.nspname, pg_total_relation_size(pg_class.oid), count(*)
		FROM pg_class, pg_namespace n
		WHERE pg_class.relnamespace = n.oid AND pg_class.relkind = 'r'
		  AND n.nspname NOT IN ('pg_catalog','information_schema')
		  AND n.nspname NOT LIKE 'pg_toast%'
		GROUP BY 1, 2`)
	if err == nil {
		schemaBytes := map[string]int64{}
		schemaTables := map[string]int64{}
		for srow.Next() {
			var name string
			var b, n int64
			if err := srow.Scan(&name, &b, &n); err == nil {
				schemaBytes[name] += b
				schemaTables[name] += n
			}
		}
		srow.Close()
		out["schema_bytes"] = schemaBytes
		out["schema_table_counts"] = schemaTables
	}

	// answer_keys: which bank codes carry the most key material (counts only).
	krow, err := s.store.Pool.Query(ctx, `
		SELECT code, count(*),
		       sum(octet_length(letter) + octet_length(explanation) + octet_length(question_id))
		FROM study.answer_keys
		GROUP BY code ORDER BY 3 DESC NULLS LAST LIMIT 15`)
	if err == nil {
		defer krow.Close()
		type keyBank struct {
			Code       string `json:"code"`
			Keys       int64  `json:"keys"`
			PayloadSum int64  `json:"payload_bytes"`
		}
		banks := []keyBank{}
		for krow.Next() {
			var b keyBank
			if err := krow.Scan(&b.Code, &b.Keys, &b.PayloadSum); err == nil {
				banks = append(banks, b)
			}
		}
		out["answer_keys_top_banks"] = banks
		var totalKeys int64
		_ = s.store.Pool.QueryRow(ctx, `SELECT count(*) FROM study.answer_keys`).Scan(&totalKeys)
		out["answer_keys_total"] = totalKeys
	}

	// attempts funnel: how much exam history is stored.
	var attemptsTotal int64
	_ = s.store.Pool.QueryRow(ctx, `SELECT count(*) FROM study.attempts`).Scan(&attemptsTotal)
	out["attempts_total"] = attemptsTotal

	var answersTotal int64
	_ = s.store.Pool.QueryRow(ctx, `SELECT count(*) FROM study.attempt_answers`).Scan(&answersTotal)
	out["attempt_answers_total"] = answersTotal

	var usersTotal int64
	_ = s.store.Pool.QueryRow(ctx, `SELECT count(*) FROM study.users`).Scan(&usersTotal)
	out["users_total"] = usersTotal

	var resultsTotal int64
	var breakdownMax int64
	_ = s.store.Pool.QueryRow(ctx,
		`SELECT count(*), COALESCE(max(octet_length(breakdown::text)),0) FROM study.results`,
	).Scan(&resultsTotal, &breakdownMax)
	out["results_total"] = resultsTotal
	out["results_breakdown_max_bytes"] = breakdownMax

	// legacy ERA-1 schemas still parked on the database (core.*, cbt.*).
	lrow, err := s.store.Pool.Query(ctx, `
		SELECT table_schema, count(*), sum(pg_total_relation_size(quote_ident(table_schema)||'.'||quote_ident(table_name))::bigint)
		FROM information_schema.tables
		WHERE table_type='BASE TABLE' AND table_schema NOT IN ('pg_catalog','information_schema','study','arena')
		  AND table_schema NOT LIKE 'pg_%'
		GROUP BY 1 ORDER BY 3 DESC NULLS LAST`)
	if err == nil {
		defer lrow.Close()
		legacy := map[string]any{}
		for lrow.Next() {
			var name string
			var n, b int64
			if err := lrow.Scan(&name, &n, &b); err == nil {
				legacy[name] = map[string]any{"tables": n, "bytes": b, "pretty": humanBytes(b)}
			}
		}
		if len(legacy) > 0 {
			out["legacy_schemas"] = legacy
		}
	}

	writeJSON(w, http.StatusOK, out)
}

func humanBytes(b int64) string {
	const unit = 1024
	if b < unit {
		return itoa(int64(b)) + " B"
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return ftoa(float64(b)/float64(div)) + "KMGTPE"[exp:exp+1] + "B"
}

func itoa(v int64) string {
	if v == 0 {
		return "0"
	}
	neg := v < 0
	if neg {
		v = -v
	}
	var buf [20]byte
	i := len(buf)
	for v > 0 {
		i--
		buf[i] = byte('0' + v%10)
		v /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

func ftoa(f float64) string {
	whole := int64(f)
	frac := int64((f - float64(whole)) * 100)
	if frac < 0 {
		frac = -frac
	}
	return itoa(whole) + "." + itoa(frac/10) + itoa(frac%10)
}

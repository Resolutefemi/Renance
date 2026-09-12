package main

// Emit: Spec → pack JSON + key JSON + manifest, mirroring tools/cbt-build
// conventions exactly (indent 2, trailing newline, manifest key order).

import (
        "crypto/sha256"
        "encoding/hex"
        "encoding/json"
        "fmt"
        "os"
        "path/filepath"
        "sort"
        "strings"
        "time"
)

// forbiddenInPack: keys that must never appear anywhere in a student-visible
// bundle (mirrors tools/cbt-build/build.py FORBIDDEN_IN_BUNDLE; ADR-0003).
var forbiddenInPack = map[string]bool{
        "answer": true, "answers": true, "correct": true, "correct_letter": true,
        "correctletter": true, "correctoption": true, "explanation": true, "is_correct": true,
}

type qJSON struct {
        ID         string            `json:"id"`
        Type       string            `json:"type"`
        Stem       string            `json:"stem"`
        Options    map[string]string `json:"options,omitempty"`
        Marks      int               `json:"marks"`
        Topic      string            `json:"topic,omitempty"`
        Difficulty string            `json:"difficulty,omitempty"`
}

type bundleJSON struct {
        Code            string  `json:"code"`
        Title           string  `json:"title"`
        Version         int     `json:"version"`
        QuestionCount   int     `json:"questionCount"`
        TotalMarks      int     `json:"totalMarks"`
        DurationMinutes *int    `json:"durationMinutes,omitempty"`
        Category        string  `json:"category,omitempty"`
        Body            string  `json:"body,omitempty"`
        Questions       []qJSON `json:"questions"`
}

type kEntry struct {
        Type        string `json:"type"`
        Letter      string `json:"letter"`
        Explanation string `json:"explanation,omitempty"`
}

type keyJSON struct {
        Code    string            `json:"code"`
        Answers map[string]kEntry `json:"answers"`
}

// buildArtifacts renders the pack + key bytes for a lint-clean Spec.
func buildArtifacts(s *Spec) (pack []byte, key []byte, err error) {
        b := bundleJSON{
                Code:            s.Code,
                Title:           s.Title,
                Version:         s.Version,
                QuestionCount:   len(s.Questions),
                DurationMinutes: s.DurationMinutes,
                Category:        s.Category,
                Body:            s.Body,
                Questions:       make([]qJSON, 0, len(s.Questions)),
        }
        k := keyJSON{Code: s.Code, Answers: map[string]kEntry{}}
        for i, q := range s.Questions {
                marks := q.Marks
                if marks == 0 {
                        marks = 1
                }
                b.Questions = append(b.Questions, qJSON{
                        ID:         fmt.Sprintf("%s-%04d", s.Code, i+1),
                        Type:       "mcq",
                        Stem:       q.Stem,
                        Options:    q.Options,
                        Marks:      marks,
                        Topic:      q.Topic,
                        Difficulty: q.Difficulty,
                })
                b.TotalMarks += marks
                k.Answers[fmt.Sprintf("%s-%04d", s.Code, i+1)] = kEntry{
                        Type:        "mcq",
                        Letter:      q.Answer,
                        Explanation: q.Explanation,
                }
        }
        if b.Version == 0 {
                b.Version = 1
        }
        pack, err = marshalJSON(b)
        if err != nil {
                return nil, nil, err
        }
        key, err = marshalJSON(k)
        if err != nil {
                return nil, nil, err
        }
        if err := scanForForbidden(s.Code, pack); err != nil {
                return nil, nil, err
        }
        return pack, key, nil
}

func marshalJSON(v any) ([]byte, error) {
        out, err := json.MarshalIndent(v, "", "  ")
        if err != nil {
                return nil, err
        }
        return append(out, '\n'), nil
}

// packRelPath mirrors tools/cbt-build/build.py bundle_relpath: generated
// packs land in their body/school folder (WAEC/mathematics.json,
// All_tertiary_Q/futa/BIO101.json, POST_UTME/unilag.json) instead of piling
// flat in questions/. Codes stay untouched — only the file location.
func packRelPath(code string) string {
        c := strings.TrimSpace(code)
        for _, body := range []string{"jamb", "waec", "neco"} {
                if rest, ok := strings.CutPrefix(c, body+"-"); ok {
                        return strings.ToUpper(body) + "/" + strings.TrimSuffix(rest, "-bank") + ".json"
                }
        }
        if rest, ok := strings.CutPrefix(c, "uni-"); ok {
                rest = strings.TrimSuffix(rest, "-bank")
                // Per-school Post-UTME prep banks: <school>-pq-<subject>.
                if school, subject, found := strings.Cut(rest, "-pq-"); found && school != "" && subject != "" {
                        return "POST_UTME/" + school + "/" + subject + ".json"
                }
                // Course banks: <school>-<course>. The school slug may carry
                // dashes (mountain-top), so prefer the last-dash split when
                // the tail is a course code (bio101); wordy course names
                // (financial-sector-and-eco) split at the first dash.
                school, course := "", ""
                if i := strings.LastIndex(rest, "-"); i > 0 {
                        school, course = rest[:i], rest[i+1:]
                }
                if !isCourseCode(course) {
                        if j := strings.Index(rest, "-"); j > 0 {
                                school, course = rest[:j], rest[j+1:]
                        }
                }
                if school != "" && course != "" {
                        name := course
                        if isCourseCode(course) {
                                name = strings.ToUpper(course)
                        }
                        return "All_tertiary_Q/" + school + "/" + name + ".json"
                }
        }
        if strings.Contains(c, "-post-utme") {
                rest := strings.TrimSuffix(c, "-bank")
                rest = strings.Replace(rest, "-post-utme", "", 1)
                return "POST_UTME/" + rest + ".json"
        }
        return c + ".json"
}

// isCourseCode reports whether s looks like a university course code
// (letters run + number run, e.g. bio101, AMS101, cve105).
func isCourseCode(s string) bool {
        if s == "" {
                return false
        }
        i := 0
        for i < len(s) && isLowerLetter(s[i]) {
                i++
        }
        if i < 2 || i == len(s) {
                return false
        }
        for ; i < len(s); i++ {
                if s[i] < '0' || s[i] > '9' {
                        return false
                }
        }
        return true
}

func isLowerLetter(b byte) bool { return b >= 'a' && b <= 'z' }

// scanForForbidden walks the marshaled pack and refuses answer material,
// the same doctrine the API enforces at boot (scanForAnswerMaterial).
func scanForForbidden(code string, pack []byte) error {
        var node any
        if err := json.Unmarshal(pack, &node); err != nil {
                return err
        }
        var walk func(n any, path string) error
        walk = func(n any, path string) error {
                switch v := n.(type) {
                case map[string]any:
                        for k, sub := range v {
                                norm := strings.ToLower(strings.ReplaceAll(k, "-", "_"))
                                if forbiddenInPack[norm] {
                                        return fmt.Errorf("%s: forbidden key %q in pack (answer material leak)", code, k)
                                }
                                if err := walk(sub, path+"."+k); err != nil {
                                        return err
                                }
                        }
                case []any:
                        for _, sub := range v {
                                if err := walk(sub, path); err != nil {
                                        return err
                                }
                        }
                }
                return nil
        }
        return walk(node, code)
}

// ---- manifest ----

type examMeta struct {
        Code            string `json:"code"`
        Title           string `json:"title"`
        QuestionCount   int    `json:"questionCount"`
        TotalMarks      int    `json:"totalMarks"`
        DurationMinutes *int   `json:"durationMinutes,omitempty"`
        Category        string `json:"category,omitempty"`
        Body            string `json:"body,omitempty"`
        BundleSHA256    string `json:"bundleSha256"`
        SizeBytes       int64  `json:"sizeBytes"`
}

type manifestJSON struct {
        GeneratedAt string     `json:"generatedAt"`
        Version     string     `json:"version"`
        Exams       []examMeta `json:"exams"`
}

// writeManifest rebuilds data/manifest.json over EVERY pack under
// <outdir>/questions/ (self-healing, subfolder-aware — like cbt-build) and
// refreshes questions/index.json, the code → relative-path map the API
// loader resolves bundles through. Returns the number of packs fingerprinted.
func writeManifest(outdir, version string) (int, error) {
        if version == "" {
                version = existingVersion(outdir)
        }
        questionsDir := filepath.Join(outdir, "questions")
        var paths []string
        err := filepath.WalkDir(questionsDir, func(path string, d os.DirEntry, werr error) error {
                if werr != nil {
                        return werr
                }
                if d.IsDir() || filepath.Ext(d.Name()) != ".json" || d.Name() == "index.json" {
                        return nil
                }
                paths = append(paths, path)
                return nil
        })
        if err != nil {
                return 0, err
        }
        sort.Strings(paths)

        var exams []examMeta
        index := map[string]string{}
        for _, path := range paths {
                raw, err := os.ReadFile(path)
                if err != nil {
                        return 0, err
                }
                var b struct {
                        Code            string `json:"code"`
                        Title           string `json:"title"`
                        QuestionCount   int    `json:"questionCount"`
                        TotalMarks      int    `json:"totalMarks"`
                        DurationMinutes *int   `json:"durationMinutes"`
                        Category        string `json:"category"`
                        Body            string `json:"body"`
                }
                if err := json.Unmarshal(raw, &b); err != nil {
                        return 0, fmt.Errorf("manifest: %s: %w", path, err)
                }
                if b.Title == "" {
                        b.Title = b.Code
                }
                rel, err := filepath.Rel(questionsDir, path)
                if err != nil {
                        return 0, err
                }
                index[b.Code] = filepath.ToSlash(rel)
                sum := sha256.Sum256(raw)
                exams = append(exams, examMeta{
                        Code:            b.Code,
                        Title:           b.Title,
                        QuestionCount:   b.QuestionCount,
                        TotalMarks:      b.TotalMarks,
                        DurationMinutes: b.DurationMinutes,
                        Category:        b.Category,
                        Body:            b.Body,
                        BundleSHA256:    hex.EncodeToString(sum[:]),
                        SizeBytes:       int64(len(raw)),
                })
        }
        if exams == nil {
                exams = []examMeta{}
        }
        m := manifestJSON{
                GeneratedAt: time.Now().UTC().Format(time.RFC3339),
                Version:     version,
                Exams:       exams,
        }
        out, err := marshalJSON(m)
        if err != nil {
                return len(exams), err
        }
        if err := os.WriteFile(filepath.Join(outdir, "manifest.json"), out, 0o644); err != nil {
                return len(exams), err
        }
        idxRaw, err := marshalJSON(index)
        if err != nil {
                return len(exams), err
        }
        return len(exams), os.WriteFile(filepath.Join(questionsDir, "index.json"), idxRaw, 0o644)
}

func existingVersion(outdir string) string {
        raw, err := os.ReadFile(filepath.Join(outdir, "manifest.json"))
        if err != nil {
                return "era2-g1"
        }
        var m struct {
                Version string `json:"version"`
        }
        if json.Unmarshal(raw, &m) != nil || m.Version == "" {
                return "era2-g1"
        }
        return m.Version
}

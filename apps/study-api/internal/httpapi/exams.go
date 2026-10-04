package httpapi

import "net/http"

// handleManifest serves the pack manifest: titles, counts, sha256
// fingerprints. Clients cache bundles keyed by the fingerprint.
func (s *Server) handleManifest(w http.ResponseWriter, r *http.Request) {
        writeJSON(w, http.StatusOK, s.lib.Manifest())
}

// handleBundle serves one study bundle. Static banks ship their
// per-question answer + explanation material (founder directive
// 2026-09, same content the web's static bundle shelf publishes, so
// the study reader grades and explains offline on every client);
// composed mock papers stay answer-free (ADR-0003: graded sittings
// keep their keys sealed server-side).
func (s *Server) handleBundle(w http.ResponseWriter, r *http.Request) {
        code := r.PathValue("code")
        // Mock papers compose on first fetch (deterministic from the code),
        // so a resumed or reviewed sitting always finds its bundle again.
        bundle, ok := s.ensurePaperRequest(r, code)
        if !ok {
                fail(w, http.StatusNotFound, "unknown_pack", "no study pack with code "+code)
                return
        }
        // Re-attach the harvested key material for STATIC banks only:
        // composed papers never register keys under their own code, so
        // KeysFor misses them and they serve answer-free as before.
        if keys, has := s.lib.KeysFor(code); has {
                bundle = bundle.WithKeyMaterial(keys)
        }
        writeJSON(w, http.StatusOK, bundle)
}

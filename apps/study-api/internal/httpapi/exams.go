package httpapi

import "net/http"

// handleManifest serves the pack manifest: titles, counts, sha256
// fingerprints. Clients cache bundles keyed by the fingerprint.
func (s *Server) handleManifest(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.lib.Manifest())
}

// handleBundle serves one student-safe bundle. Answer keys never route
// through here — cbtdata already refused to boot if any leaked on disk.
func (s *Server) handleBundle(w http.ResponseWriter, r *http.Request) {
	code := r.PathValue("code")
	bundle, ok := s.lib.Bundle(code)
	if !ok {
		fail(w, http.StatusNotFound, "unknown_pack", "no study pack with code "+code)
		return
	}
	writeJSON(w, http.StatusOK, bundle)
}

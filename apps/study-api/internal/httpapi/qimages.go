package httpapi

import (
	"net/http"
	"strings"

	"renance.dev/study-api/internal/cbtdata"
)

// handleQImage serves an embedded question diagram at /qimages/{name}.
//
// Unauthenticated by design: question diagrams are student-visible
// material (the stem says "see the figure"). Worked-solution images ride
// the same namespace, but their question→image mapping lives only in the
// sealed answer key, so the unguessable content-addressed names leak
// nothing (ADR-0003 doctrine, image edition).
//
// Names are sha1-derived and immutable; a one-year immutable cache
// header keeps the mobile app and the web player cheap on data.
func (s *Server) handleQImage(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	raw, err := cbtdata.QImage(name)
	if err != nil {
		fail(w, http.StatusNotFound, "unknown_image", "no such image")
		return
	}
	switch {
	case strings.HasSuffix(name, ".png"):
		w.Header().Set("Content-Type", "image/png")
	case strings.HasSuffix(name, ".gif"):
		w.Header().Set("Content-Type", "image/gif")
	case strings.HasSuffix(name, ".webp"):
		w.Header().Set("Content-Type", "image/webp")
	case strings.HasSuffix(name, ".svg"):
		w.Header().Set("Content-Type", "image/svg+xml")
	default:
		w.Header().Set("Content-Type", "image/jpeg")
	}
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(raw)
}

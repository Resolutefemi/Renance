// Career bridge endpoints (ROADMAP #18).
//
// GET /career, the curated scholarship list + course-path explorer. The
// catalogue is committed data (data/career/*.json), boot-validated, so
// the response is static per release and the clients can cache it like a
// pack. Auth-gated like /lessons; the web bakes the same files at build
// time for signed-out visitors and SEO.
package httpapi

import (
	"net/http"
)

func (s *Server) handleCareer(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.lib.Career())
}

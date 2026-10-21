package httpapi

import (
	"net/http"
	"os"
	"strconv"
)

// handleAppVersion serves the mobile update gate's source of truth
// (founder directive 2026-10-04): the versionCode of the NEWEST build on
// Google Play. The Android gate (apps/mobile/lib/update_gate.dart) fetches
// this through https://renance.app/api/app-version (the Vercel rewrite
// lands here) and locks the app behind the "update to keep practising"
// screen while the store build is newer than the running one.
//
// The values come from the environment so the founder flips the gate from
// the Render dashboard the moment a Play Store release goes live - no
// redeploy needed for the app itself:
//
//	APP_LATEST_VERSION_CODE (default 16 - the 2.6.12 build)
//	APP_LATEST_VERSION      (default "2.6.12")
//
// Keeping the default in sync with apps/mobile/pubspec.yaml's
// version: X.Y.Z+N is enough until the next store release.
func (s *Server) handleAppVersion(w http.ResponseWriter, r *http.Request) {
	code := 16
	if v := os.Getenv("APP_LATEST_VERSION_CODE"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			code = n
		}
	}
	version := "2.6.12"
	if v := os.Getenv("APP_LATEST_VERSION"); v != "" {
		version = v
	}
	// Cache-control: the gate polls once per app start with a 4s timeout;
	// a short edge cache keeps a Play-Store-launch stampede off the free
	// plan without ever shipping a stale "update" verdict for long.
	w.Header().Set("Cache-Control", "public, max-age=60")
	writeJSON(w, http.StatusOK, map[string]any{
		"versionCode": code,
		"version":     version,
		"platform":    "android",
	})
}

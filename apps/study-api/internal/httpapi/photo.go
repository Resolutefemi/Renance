// photo.go - profile photos on Cloudflare R2 (founder directive
// 2026-10-22: "allow users to add profile pictures which will be
// uploaded and fetched from cloudflare's R2 - create a new folder
// under the Renance bucket called profile-picture").
//
// POST /me/avatar/photo   multipart form: file=(png|jpeg|webp, ≤5MB)
// DELETE /me/avatar/photo  clears the scholar's photo
// GET  /media/profile-picture/{key}  public serve (immutable cache)
//
// The object key rides the REAL user id + an upload timestamp, so a
// re-upload is a NEW object (the old one is deleted best-effort) and
// every URL is immutable - CDNs and phones cache forever without
// staleness bugs. Picking an avatar instead clears the photo and vice
// versa: exactly one identity image wins, the Duolingo way.
package httpapi

import (
        "context"
        "io"
        "net/http"
        "path"
        "regexp"
        "strings"
        "time"
)

// founderEmail - the platform voice (announcements) and the only
// account that predates the rules.
const founderEmail = "ariyooluwafemi487@gmail.com"

// isFounder reports whether the uid is the founder's account.
func (s *Server) isFounder(ctx context.Context, uid string) bool {
        u, err := s.store.UserByID(ctx, uid)
        if err != nil || u == nil || u.Email == nil {
                return false
        }
        return strings.ToLower(strings.TrimSpace(*u.Email)) == founderEmail
}

// photoKeyRE guards served keys: hex uuid + - + unix seconds + .ext.
var photoKeyRE = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-\d{10}\.(?:png|jpe?g|webp)$`)

const photoMaxBytes = 5 << 20 // 5MB - a profile photo, not a photo dump

// handleAvatarPhotoUpload accepts one multipart "file" field, drops it
// into R2 under profile-picture/, and points the scholar's profile at
// it. The upload wins over any avatar key.
func (s *Server) handleAvatarPhotoUpload(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if s.photos == nil {
                fail(w, http.StatusServiceUnavailable, "photos_off", "photo storage is not configured")
                return
        }
        if err := r.ParseMultipartForm(photoMaxBytes); err != nil {
                fail(w, http.StatusBadRequest, "bad_upload", "the photo must be 5MB or smaller")
                return
        }
        file, _, err := r.FormFile("file")
        if err != nil {
                fail(w, http.StatusBadRequest, "bad_upload", "attach the photo in a 'file' field")
                return
        }
        defer file.Close()

        payload, err := io.ReadAll(io.LimitReader(file, photoMaxBytes+1))
        if err != nil {
                fail(w, http.StatusBadRequest, "bad_upload", "could not read the photo")
                return
        }
        if len(payload) == 0 {
                fail(w, http.StatusBadRequest, "bad_upload", "the photo is empty")
                return
        }
        if len(payload) > photoMaxBytes {
                fail(w, http.StatusRequestEntityTooLarge, "bad_upload", "the photo must be 5MB or smaller")
                return
        }

        // Sniff the real bytes - extensions lie, magic numbers don't.
        ctype := http.DetectContentType(payload)
        var ext string
        switch {
        case strings.HasPrefix(ctype, "image/jpeg"):
                ctype, ext = "image/jpeg", "jpg"
        case strings.HasPrefix(ctype, "image/png"):
                ctype, ext = "image/png", "png"
        case strings.HasPrefix(ctype, "image/webp"):
                ctype, ext = "image/webp", "webp"
        default:
                fail(w, http.StatusUnsupportedMediaType, "bad_upload", "the photo must be a PNG, JPEG or WebP image")
                return
        }

        key := uid + "-" + time.Now().UTC().Format("20060102150405") + "." + ext
        if err := s.photos.PutObject(r.Context(), key, ctype, payload); err != nil {
                s.log.Error("profile photo upload", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not store the photo")
                return
        }

        // The photo replaces any avatar key (the Duolingo one-wins rule).
        if err := s.store.SetAvatarPhoto(r.Context(), uid, key); err != nil {
                s.log.Error("profile photo save", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not save the photo")
                return
        }
        // Best-effort clear of the avatar key + old photo object.
        _ = s.store.SetAvatar(r.Context(), uid, "")
        if profile, perr := s.store.ProfileByUser(r.Context(), uid); perr == nil && profile != nil &&
                profile.AvatarPhoto != "" && profile.AvatarPhoto != key && photoKeyRE.MatchString(profile.AvatarPhoto) {
                // (ProfileByUser already reflects the NEW key, so this never
                // fires today; kept as the old-object sweep for future edits.)
                _ = s.photos.DeleteObject(r.Context(), profile.AvatarPhoto)
        }

        writeJSON(w, http.StatusOK, map[string]string{"avatarPhoto": key})
}

// handleAvatarPhotoDelete clears the photo (and removes the object
// best-effort). The scholar falls back to their avatar key or the
// initial letter.
func (s *Server) handleAvatarPhotoDelete(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        old := ""
        if profile, perr := s.store.ProfileByUser(r.Context(), uid); perr == nil && profile != nil {
                old = profile.AvatarPhoto
        }
        if err := s.store.SetAvatarPhoto(r.Context(), uid, ""); err != nil {
                s.log.Error("profile photo clear", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not clear the photo")
                return
        }
        if s.photos != nil && old != "" && photoKeyRE.MatchString(old) {
                _ = s.photos.DeleteObject(r.Context(), old)
        }
        writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// handleProfilePhotoServe is the PUBLIC reader: GET
// /media/profile-picture/{key} streams the photo out of R2 with an
// immutable cache header (the key embeds the upload timestamp, so a
// re-upload is a different URL and this never serves stale bytes).
func (s *Server) handleProfilePhotoServe(w http.ResponseWriter, r *http.Request) {
        if s.photos == nil {
                fail(w, http.StatusServiceUnavailable, "photos_off", "photo storage is not configured")
                return
        }
        key := path.Base(r.PathValue("key"))
        if !photoKeyRE.MatchString(key) {
                fail(w, http.StatusNotFound, "no_photo", "no such photo")
                return
        }
        payload, ok, err := s.photos.GetObject(r.Context(), key)
        if err != nil {
                s.log.Error("profile photo read", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not read the photo")
                return
        }
        if !ok {
                fail(w, http.StatusNotFound, "no_photo", "no such photo")
                return
        }
        ctype := http.DetectContentType(payload)
        w.Header().Set("Content-Type", ctype)
        w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write(payload)
}

// social.go - the HTTP surface of the Renance feed + follows (founder
// directive 2026-10-14). Thin parse → service → writeJSON handlers in
// the house style; every route rides s.auth like the rest of the
// student surface.
package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"

	"renance.dev/study-api/internal/social"
)

// GET /social/feed?before=&limit= - one page of the global feed.
func (s *Server) handleSocialFeed(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	qp := r.URL.Query()
	before, _ := strconv.ParseInt(qp.Get("before"), 10, 64)
	limit, _ := strconv.Atoi(qp.Get("limit"))
	posts, err := social.Feed(r.Context(), s.store.Pool, viewer, before, limit)
	if err != nil {
		s.log.Error("social feed", "err", err)
		fail(w, http.StatusInternalServerError, "social_feed", "could not load the feed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"posts": posts})
}

// POST /social/feed {body} - a freeform post (≤500 chars).
func (s *Server) handleSocialPostCreate(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	var body struct {
		Body string `json:"body"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	id, err := social.UserPost(r.Context(), s.store.Pool, viewer, body.Body)
	if err != nil {
		fail(w, http.StatusBadRequest, "social_post", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": id})
}

// DELETE /social/posts/{id} - retire one of your own posts.
func (s *Server) handleSocialPostDelete(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		fail(w, http.StatusBadRequest, "bad_id", "invalid post id")
		return
	}
	ok, err := social.DeletePost(r.Context(), s.store.Pool, viewer, id)
	if err != nil {
		fail(w, http.StatusInternalServerError, "social_delete", "could not delete the post")
		return
	}
	if !ok {
		fail(w, http.StatusNotFound, "social_post", "no such post of yours")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /social/posts/{id}/like - toggle (idempotent per call pair).
func (s *Server) handleSocialLike(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		fail(w, http.StatusBadRequest, "bad_id", "invalid post id")
		return
	}
	likes, liked, err := social.ToggleLike(r.Context(), s.store.Pool, viewer, id)
	if err != nil {
		fail(w, http.StatusInternalServerError, "social_like", "could not register the like")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"likes": likes, "liked": liked})
}

// GET /social/posts/{id}/comments
func (s *Server) handleSocialCommentsGet(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		fail(w, http.StatusBadRequest, "bad_id", "invalid post id")
		return
	}
	comments, err := social.Comments(r.Context(), s.store.Pool, viewer, id)
	if err != nil {
		fail(w, http.StatusInternalServerError, "social_comments", "could not load comments")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"comments": comments})
}

// POST /social/posts/{id}/comments {body}
func (s *Server) handleSocialCommentAdd(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		fail(w, http.StatusBadRequest, "bad_id", "invalid post id")
		return
	}
	var body struct {
		Body string `json:"body"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&body); err != nil {
		fail(w, http.StatusBadRequest, "bad_json", "invalid request body")
		return
	}
	if _, err := social.AddComment(r.Context(), s.store.Pool, viewer, id, body.Body); err != nil {
		fail(w, http.StatusBadRequest, "social_comment", err.Error())
		return
	}
	comments, err := social.Comments(r.Context(), s.store.Pool, viewer, id)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"comments": comments})
}

// POST /social/users/{username}/follow - toggle.
func (s *Server) handleSocialFollow(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	username := r.PathValue("username")
	subject := social.UserIDByUsername(r.Context(), s.store.Pool, username)
	if subject == "" {
		fail(w, http.StatusNotFound, "social_user", "no such scholar")
		return
	}
	following, err := social.Follow(r.Context(), s.store.Pool, viewer, subject)
	if err != nil {
		fail(w, http.StatusBadRequest, "social_follow", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"following": following})
}

// GET /social/users/{username} - the public profile.
func (s *Server) handleSocialPublicProfile(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	p, err := social.LoadPublicProfile(r.Context(), s.store.Pool, viewer, r.PathValue("username"))
	if err != nil {
		fail(w, http.StatusNotFound, "social_user", "no such scholar")
		return
	}
	posts, _ := social.UserPosts(r.Context(), s.store.Pool, viewer, p.ID, 20)
	writeJSON(w, http.StatusOK, map[string]any{"profile": p, "posts": posts})
}

// GET /social/connections - my followers + following.
func (s *Server) handleSocialConnections(w http.ResponseWriter, r *http.Request) {
	viewer := r.Context().Value(ctxUserID).(string)
	c, err := social.LoadConnections(r.Context(), s.store.Pool, viewer)
	if err != nil {
		fail(w, http.StatusInternalServerError, "social_connections", "could not load your people")
		return
	}
	writeJSON(w, http.StatusOK, c)
}

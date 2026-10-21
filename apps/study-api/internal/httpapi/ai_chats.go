// Renance AI persistent chats (founder directive, 2026-09-30): the
// studio's conversation engine with everything the big AI chat products
// ship - folders, history, durable memories and visible thinking
// phases - all server-side so a closed app or a reloaded tab loses
// nothing.
//
//      GET    /ai/chats?folder=      list threads (newest first)
//      POST   /ai/chats {title?,folder?}   open a thread
//      GET    /ai/chats/{id}         thread + full message history
//      POST   /ai/chats/{id}/messages {content, class?, subject?}
//             append the student's turn, generate the grounded reply
//             (memories + past-question bridge + thinking phases),
//             persist both, return them
//      PATCH  /ai/chats/{id} {title?,folder?}   rename / move
//      DELETE /ai/chats/{id}         delete thread + messages
//      GET    /ai/folders            folders with thread counts
//      GET    /ai/memories           the student's durable facts
//      POST   /ai/memories {content} remember a fact
//      DELETE /ai/memories/{id}      forget one
//
// The first message of a thread names it (first words of the turn), the
// way ChatGPT does. A message starting with "remember" stores a memory
// and the reply says so.
package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"

	"renance.dev/study-api/internal/store"
	"renance.dev/study-api/internal/tutor"
)

const (
	chatContextTurns = 12 // history turns sent to the model
	chatMaxContent   = 4000
	memoryMaxContent = 400
	memoryMaxCount   = 50
)

// handleListAIChats serves GET /ai/chats.
func (s *Server) handleListAIChats(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	chats, err := s.store.ListAIChats(r.Context(), uid, strings.TrimSpace(r.URL.Query().Get("folder")))
	if err != nil {
		s.log.Error("list ai chats", "err", err)
		fail(w, http.StatusInternalServerError, "list_failed", "could not load your chats")
		return
	}
	if chats == nil {
		chats = []store.AIChat{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"chats": chats})
}

// handleCreateAIChat serves POST /ai/chats.
func (s *Server) handleCreateAIChat(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req struct {
		Title  string `json:"title"`
		Folder string `json:"folder"`
	}
	// An empty body is fine: defaults kick in.
	_ = decodeJSONLoose(r, &req)
	chat, err := s.store.CreateAIChat(r.Context(), uid,
		trimTo(req.Folder, 60), trimTo(req.Title, studioMaxTitle))
	if err != nil {
		s.log.Error("create ai chat", "err", err)
		fail(w, http.StatusInternalServerError, "create_failed", "could not open the chat")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"chat": chat})
}

// handleGetAIChat serves GET /ai/chats/{id}.
func (s *Server) handleGetAIChat(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	chat, err := s.store.GetAIChat(r.Context(), uid, r.PathValue("id"))
	if err != nil {
		fail(w, http.StatusNotFound, "not_found", "that chat does not exist")
		return
	}
	msgs, err := s.store.ListAIMessages(r.Context(), uid, chat.ID)
	if err != nil {
		s.log.Error("list ai messages", "err", err)
		fail(w, http.StatusInternalServerError, "list_failed", "could not load the chat")
		return
	}
	if msgs == nil {
		msgs = []store.AIMessage{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"chat": chat, "messages": msgs})
}

// handleDeleteAIChat serves DELETE /ai/chats/{id}.
func (s *Server) handleDeleteAIChat(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	if err := s.store.DeleteAIChat(r.Context(), uid, r.PathValue("id")); err != nil {
		fail(w, http.StatusNotFound, "not_found", "that chat does not exist")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// handleUpdateAIChat serves PATCH /ai/chats/{id} - rename and/or move
// to a folder.
func (s *Server) handleUpdateAIChat(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req struct {
		Title  *string `json:"title"`
		Folder *string `json:"folder"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	var title, folder *string
	if req.Title != nil {
		t := trimTo(*req.Title, studioMaxTitle)
		if t == "" {
			fail(w, http.StatusBadRequest, "invalid_title", "title cannot be empty")
			return
		}
		title = &t
	}
	if req.Folder != nil {
		f := trimTo(*req.Folder, 60)
		if f == "" {
			f = "General"
		}
		folder = &f
	}
	if err := s.store.UpdateAIChat(r.Context(), uid, r.PathValue("id"), title, folder); err != nil {
		fail(w, http.StatusNotFound, "not_found", "that chat does not exist")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// handleAIFolders serves GET /ai/folders.
func (s *Server) handleAIFolders(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	folders, err := s.store.ListAIFolders(r.Context(), uid)
	if err != nil {
		s.log.Error("list ai folders", "err", err)
		fail(w, http.StatusInternalServerError, "list_failed", "could not load folders")
		return
	}
	if folders == nil {
		folders = []store.AIFolder{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"folders": folders})
}

// ---------------------------------------------------------------------------
// The chat loop
// ---------------------------------------------------------------------------

type chatMessageRequest struct {
	Content string `json:"content"`
	Class   string `json:"class"`
	Subject string `json:"subject"`
}

type chatMessageResponse struct {
	UserMessage      store.AIMessage `json:"userMessage"`
	AssistantMessage store.AIMessage `json:"assistantMessage"`
	Mode             string          `json:"mode"`
	Phases           []string        `json:"phases"`
	Bridged          int             `json:"bridged"`
	MemorySaved      bool            `json:"memorySaved,omitempty"`
}

// handlePostChatMessage is the heart of the studio: it persists the
// student's turn, grounds the reply in memories + the past-question
// bridge, streams the thinking phases for the UI to replay and stores
// the answer.
func (s *Server) handlePostChatMessage(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	// Rate limiting rides on the route registration (userLimit "ai"),
	// the same budget as every other AI surface.
	chatID := r.PathValue("id")
	chat, err := s.store.GetAIChat(r.Context(), uid, chatID)
	if err != nil {
		fail(w, http.StatusNotFound, "not_found", "that chat does not exist")
		return
	}
	var req chatMessageRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	content := strings.TrimSpace(req.Content)
	if content == "" {
		fail(w, http.StatusBadRequest, "invalid_content", "content is required")
		return
	}
	if len(content) > chatMaxContent {
		fail(w, http.StatusBadRequest, "invalid_content", "message too long")
		return
	}

	userMsg, err := s.store.AppendAIMessage(r.Context(), chat.ID, "user", content, "", 0)
	if err != nil {
		s.log.Error("append user message", "err", err)
		fail(w, http.StatusInternalServerError, "send_failed", "could not send the message")
		return
	}

	// First real message names the thread, the way the big chats do.
	if chat.Title == "New chat" {
		if t := titleFromContent(content); t != "" {
			_ = s.store.UpdateAIChat(r.Context(), uid, chat.ID, &t, nil)
		}
	}
	_ = s.store.TouchAIChat(r.Context(), uid, chat.ID)

	// "remember that ..." saves a durable memory.
	memorySaved := false
	lower := strings.ToLower(content)
	if strings.HasPrefix(lower, "remember ") || strings.HasPrefix(lower, "remember that ") {
		if fact := trimTo(content, memoryMaxContent); fact != "" {
			if existing, _ := s.store.ListAIMemories(r.Context(), uid); len(existing) < memoryMaxCount {
				if _, err := s.store.AddAIMemory(r.Context(), uid, fact); err == nil {
					memorySaved = true
				}
			}
		}
	}

	// Context: the last turns of this thread.
	history, err := s.store.ListAIMessages(r.Context(), uid, chat.ID)
	if err != nil {
		s.log.Error("chat history", "err", err)
		fail(w, http.StatusInternalServerError, "send_failed", "could not load the chat")
		return
	}
	var msgs []tutor.Message
	for _, m := range history {
		if m.ID == userMsg.ID {
			break // history already includes the turn we just wrote
		}
		msgs = append(msgs, tutor.Message{Role: m.Role, Content: m.Content})
	}
	if len(msgs) > chatContextTurns {
		msgs = msgs[len(msgs)-chatContextTurns:]
	}
	msgs = append(msgs, tutor.Message{Role: "user", Content: content})

	// System prompt: doctrine + memories + optional class grounding +
	// the past-question bridge. `base` (doctrine + memories) is kept
	// separate: it is the lean retry prompt when the grounded first
	// attempt misses its budget.
	base := renanceAISystemPrompt()
	if mems, err := s.store.ListAIMemories(r.Context(), uid); err == nil && len(mems) > 0 {
		var b strings.Builder
		b.WriteString("\n\nKNOWN FACTS ABOUT THIS STUDENT (apply automatically, never ask again):\n")
		for i, m := range mems {
			if i >= 12 {
				break
			}
			b.WriteString("- " + m.Content + "\n")
		}
		base += b.String()
	}
	system := base
	if req.Class != "" && req.Subject != "" {
		system += "\n\n" + s.corpusGrounding(r, req.Class, req.Subject)
	}
	bridging, bridged := "", 0
	if s.lib != nil {
		bridging, bridged = s.bridgeGrounding([]string{content}, "")
	}
	if bridging != "" {
		system += "\n\n" + bridging
	}

	// Founder directive 2026-10-12 ("remove the feature completely,
	// make sure the AI answers directly"): no canned study-guide
	// fallback is EVER saved into a thread. The provider gets two
	// attempts - the full grounded prompt first, then the lean
	// doctrine+memories prompt - and if both genuinely fail the
	// request fails honestly BEFORE an assistant bubble exists, so
	// the client can show a normal retryable error like every
	// real AI chat app.
	reply := ""
	if s.tutor != nil && s.tutor.Provider != nil {
		first, retry, done := aiChatAttempts(r)
		out, err := s.tutor.Provider.Complete(first, system, msgs, 1024)
		if err == nil && strings.TrimSpace(out) != "" {
			reply = strings.TrimSpace(out)
		} else {
			if err != nil {
				s.log.Error("studio chat provider attempt 1 failed", "err", err)
			}
			out, err = s.tutor.Provider.Complete(retry, base, msgs, 1024)
			if err == nil && strings.TrimSpace(out) != "" {
				reply = strings.TrimSpace(out)
			} else if err != nil {
				s.log.Error("studio chat provider retry failed", "err", err)
			}
		}
		done()
	}
	if reply == "" {
		fail(w, http.StatusServiceUnavailable, "ai_unavailable",
			"Renance AI could not answer just now. Send the message again.")
		return
	}
	mode := "ai"
	if memorySaved {
		reply = "Saved to memory. I will bring it into every chat from now on.\n\n" + reply
	}

	thinking := chatThinkingTrace(bridged)
	assistantMsg, err := s.store.AppendAIMessage(r.Context(), chat.ID, "assistant", reply, thinking, bridged)
	if err != nil {
		s.log.Error("append assistant message", "err", err)
		fail(w, http.StatusInternalServerError, "send_failed", "could not save the reply")
		return
	}
	_ = s.store.TouchAIChat(r.Context(), uid, chat.ID)

	writeJSON(w, http.StatusOK, chatMessageResponse{
		UserMessage:      userMsg,
		AssistantMessage: assistantMsg,
		Mode:             mode,
		Phases:           studioPhases(bridged),
		Bridged:          bridged,
		MemorySaved:      memorySaved,
	})
}

// chatThinkingTrace is the stored trace the UI can replay later.
func chatThinkingTrace(bridged int) string {
	if bridged > 0 {
		return "Researched " + strconv.Itoa(bridged) + " past questions from the corpus before answering."
	}
	return "Thought through the topic before answering."
}

// titleFromContent names a thread from its first message.
func titleFromContent(content string) string {
	words := strings.Fields(content)
	if len(words) > 6 {
		words = words[:6]
	}
	t := strings.Trim(strings.Join(words, " "), " .,!?")
	if len(t) > studioMaxTitle {
		t = t[:studioMaxTitle]
	}
	return t
}

// ---------------------------------------------------------------------------
// Memories
// ---------------------------------------------------------------------------

func (s *Server) handleListAIMemories(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	mems, err := s.store.ListAIMemories(r.Context(), uid)
	if err != nil {
		s.log.Error("list memories", "err", err)
		fail(w, http.StatusInternalServerError, "list_failed", "could not load memories")
		return
	}
	if mems == nil {
		mems = []store.AIMemory{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"memories": mems})
}

func (s *Server) handleAddAIMemory(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	var req struct {
		Content string `json:"content"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	content := strings.TrimSpace(req.Content)
	if content == "" || len(content) > memoryMaxContent {
		fail(w, http.StatusBadRequest, "invalid_content", "memory content is required (max 400 chars)")
		return
	}
	mems, _ := s.store.ListAIMemories(r.Context(), uid)
	if len(mems) >= memoryMaxCount {
		fail(w, http.StatusBadRequest, "memory_limit", "memory is full, remove one first")
		return
	}
	m, err := s.store.AddAIMemory(r.Context(), uid, content)
	if err != nil {
		s.log.Error("add memory", "err", err)
		fail(w, http.StatusInternalServerError, "add_failed", "could not save the memory")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"memory": m})
}

func (s *Server) handleDeleteAIMemory(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		fail(w, http.StatusBadRequest, "invalid_id", "bad memory id")
		return
	}
	if err := s.store.DeleteAIMemory(r.Context(), uid, id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			fail(w, http.StatusNotFound, "not_found", "that memory does not exist")
			return
		}
		s.log.Error("delete memory", "err", err)
		fail(w, http.StatusInternalServerError, "delete_failed", "could not remove the memory")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

func trimTo(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(s) > max {
		s = s[:max]
	}
	return s
}

// decodeJSONLoose tolerates an empty body (POST /ai/chats with no
// payload still opens a default chat).
func decodeJSONLoose(r *http.Request, dst any) bool {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<17))
	if err != nil || len(body) == 0 {
		return false
	}
	return json.Unmarshal(body, dst) == nil
}

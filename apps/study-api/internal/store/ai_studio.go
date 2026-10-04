// AI Studio persistence (founder directive, 2026-09-30): chats with
// folders, durable memories, and generated artifacts (quizzes, notes,
// notebooks, lesson notes). The same design law as the rest of the
// package: these methods only move bytes, every rule lives above.
package store

import (
	"context"
	"encoding/json"
	"errors"
	"time"
)

// ErrNotFound is returned when a row the caller owns does not exist.
var ErrNotFound = errors.New("store: not found")

// AIChat is one conversation thread.
type AIChat struct {
	ID        string    `json:"id"`
	Folder    string    `json:"folder"`
	Title     string    `json:"title"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// AIMessage is one turn with the thinking trace the UI replays.
type AIMessage struct {
	ID        int64     `json:"id"`
	Role      string    `json:"role"` // user | assistant
	Content   string    `json:"content"`
	Thinking  string    `json:"thinking,omitempty"`
	Bridged   int       `json:"bridged,omitempty"` // past questions grounded into the reply
	CreatedAt time.Time `json:"createdAt"`
}

// AIMemory is one durable fact about the student.
type AIMemory struct {
	ID        int64     `json:"id"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"createdAt"`
}

// AIArtifact is one generated document. Kind: quiz | note | notebook |
// lesson_note. Data is the full generated JSON (shape per kind).
type AIArtifact struct {
	ID         string          `json:"id"`
	UserID     string          `json:"-"`
	Kind       string          `json:"kind"`
	Title      string          `json:"title"`
	Subject    string          `json:"subject"`
	ClassLevel string          `json:"classLevel"`
	Data       json.RawMessage `json:"data"`
	ShareSlug  string          `json:"shareSlug,omitempty"`
	CreatedAt  time.Time       `json:"createdAt"`
}

// ---------------------------------------------------------------------------
// Chats + folders
// ---------------------------------------------------------------------------

// CreateAIChat opens a new conversation in a folder (default General).
func (s *Store) CreateAIChat(ctx context.Context, userID, folder, title string) (AIChat, error) {
	if folder == "" {
		folder = "General"
	}
	if title == "" {
		title = "New chat"
	}
	var c AIChat
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.ai_chats (user_id, folder, title)
                VALUES ($1, $2, $3)
                RETURNING id, folder, title, updated_at`,
		userID, folder, title,
	).Scan(&c.ID, &c.Folder, &c.Title, &c.UpdatedAt)
	return c, err
}

// ListAIChats returns the user's threads, newest first. folder == ""
// means every folder.
func (s *Store) ListAIChats(ctx context.Context, userID, folder string) ([]AIChat, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, folder, title, updated_at
                FROM study.ai_chats
                WHERE user_id = $1 AND ($2 = '' OR folder = $2)
                ORDER BY updated_at DESC
                LIMIT 100`,
		userID, folder,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AIChat
	for rows.Next() {
		var c AIChat
		if err := rows.Scan(&c.ID, &c.Folder, &c.Title, &c.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// GetAIChat returns one thread when it belongs to the user.
func (s *Store) GetAIChat(ctx context.Context, userID, chatID string) (AIChat, error) {
	var c AIChat
	err := s.Pool.QueryRow(ctx, `
                SELECT id, folder, title, updated_at
                FROM study.ai_chats
                WHERE id = $1 AND user_id = $2`,
		chatID, userID,
	).Scan(&c.ID, &c.Folder, &c.Title, &c.UpdatedAt)
	return c, err
}

// UpdateAIChat renames a thread and/or moves it to another folder.
func (s *Store) UpdateAIChat(ctx context.Context, userID, chatID string, title, folder *string) error {
	tag, err := s.Pool.Exec(ctx, `
                UPDATE study.ai_chats SET
                        title = COALESCE($3, title),
                        folder = COALESCE($4, folder),
                        updated_at = now()
                WHERE id = $1 AND user_id = $2`,
		chatID, userID, title, folder,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// TouchAIChat bumps updated_at so the thread floats to the top of history.
func (s *Store) TouchAIChat(ctx context.Context, userID, chatID string) error {
	_, err := s.Pool.Exec(ctx, `
                UPDATE study.ai_chats SET updated_at = now()
                WHERE id = $1 AND user_id = $2`,
		chatID, userID,
	)
	return err
}

// DeleteAIChat removes a thread and (via CASCADE) its messages.
func (s *Store) DeleteAIChat(ctx context.Context, userID, chatID string) error {
	tag, err := s.Pool.Exec(ctx, `
                DELETE FROM study.ai_chats
                WHERE id = $1 AND user_id = $2`,
		chatID, userID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListAIMessages returns a thread's turns in order.
func (s *Store) ListAIMessages(ctx context.Context, userID, chatID string) ([]AIMessage, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT m.id, m.role, m.content, m.thinking, m.bridged, m.created_at
                FROM study.ai_messages m
                JOIN study.ai_chats c ON c.id = m.chat_id
                WHERE m.chat_id = $1 AND c.user_id = $2
                ORDER BY m.id ASC
                LIMIT 400`,
		chatID, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AIMessage
	for rows.Next() {
		var m AIMessage
		if err := rows.Scan(&m.ID, &m.Role, &m.Content, &m.Thinking, &m.Bridged, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// AppendAIMessage stores one turn.
func (s *Store) AppendAIMessage(ctx context.Context, chatID, role, content, thinking string, bridged int) (AIMessage, error) {
	var m AIMessage
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.ai_messages (chat_id, role, content, thinking, bridged)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id, role, content, thinking, bridged, created_at`,
		chatID, role, content, thinking, bridged,
	).Scan(&m.ID, &m.Role, &m.Content, &m.Thinking, &m.Bridged, &m.CreatedAt)
	return m, err
}

// AIFolder is a folder name plus its thread count.
type AIFolder struct {
	Name  string `json:"name"`
	Count int    `json:"count"`
}

// ListAIFolders returns every folder that holds at least one thread.
func (s *Store) ListAIFolders(ctx context.Context, userID string) ([]AIFolder, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT folder, count(*)
                FROM study.ai_chats
                WHERE user_id = $1
                GROUP BY folder
                ORDER BY min(updated_at) ASC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AIFolder
	for rows.Next() {
		var f AIFolder
		if err := rows.Scan(&f.Name, &f.Count); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// ---------------------------------------------------------------------------
// Memories
// ---------------------------------------------------------------------------

// ListAIMemories returns the student's durable facts, newest last.
func (s *Store) ListAIMemories(ctx context.Context, userID string) ([]AIMemory, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, content, created_at
                FROM study.ai_memories
                WHERE user_id = $1
                ORDER BY id ASC
                LIMIT 100`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AIMemory
	for rows.Next() {
		var m AIMemory
		if err := rows.Scan(&m.ID, &m.Content, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// AddAIMemory stores one fact.
func (s *Store) AddAIMemory(ctx context.Context, userID, content string) (AIMemory, error) {
	var m AIMemory
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO study.ai_memories (user_id, content)
                VALUES ($1, $2)
                RETURNING id, content, created_at`,
		userID, content,
	).Scan(&m.ID, &m.Content, &m.CreatedAt)
	return m, err
}

// DeleteAIMemory drops one fact when it belongs to the user.
func (s *Store) DeleteAIMemory(ctx context.Context, userID string, id int64) error {
	tag, err := s.Pool.Exec(ctx, `
                DELETE FROM study.ai_memories
                WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ---------------------------------------------------------------------------
// Artifacts
// ---------------------------------------------------------------------------

// SaveAIArtifact stores one generated document and returns it with
// the server-assigned id and timestamp.
func (s *Store) SaveAIArtifact(ctx context.Context, a *AIArtifact) error {
	return s.Pool.QueryRow(ctx, `
                INSERT INTO study.ai_artifacts
                        (user_id, kind, title, subject, class_level, data, share_slug)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id, created_at`,
		a.UserID, a.Kind, a.Title, a.Subject, a.ClassLevel, a.Data, a.ShareSlug,
	).Scan(&a.ID, &a.CreatedAt)
}

// ListAIArtifacts returns the user's documents, newest first. kind ==
// "" means every kind.
func (s *Store) ListAIArtifacts(ctx context.Context, userID, kind string) ([]AIArtifact, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, kind, title, subject, class_level, data, share_slug, created_at
                FROM study.ai_artifacts
                WHERE user_id = $1 AND ($2 = '' OR kind = $2)
                ORDER BY created_at DESC
                LIMIT 100`,
		userID, kind,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AIArtifact
	for rows.Next() {
		var a AIArtifact
		if err := rows.Scan(&a.ID, &a.Kind, &a.Title, &a.Subject, &a.ClassLevel, &a.Data, &a.ShareSlug, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// GetAIArtifact returns one document when it belongs to the user.
func (s *Store) GetAIArtifact(ctx context.Context, userID, id string) (AIArtifact, error) {
	var a AIArtifact
	err := s.Pool.QueryRow(ctx, `
                SELECT id, kind, title, subject, class_level, data, share_slug, created_at
                FROM study.ai_artifacts
                WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&a.ID, &a.Kind, &a.Title, &a.Subject, &a.ClassLevel, &a.Data, &a.ShareSlug, &a.CreatedAt)
	return a, err
}

// DeleteAIArtifact removes one document when it belongs to the user.
func (s *Store) DeleteAIArtifact(ctx context.Context, userID, id string) error {
	tag, err := s.Pool.Exec(ctx, `
                DELETE FROM study.ai_artifacts
                WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// GetAIArtifactBySlug returns the PUBLIC quiz payload for a share link.
// No user filter: share links are public by design. Caller checks kind.
func (s *Store) GetAIArtifactBySlug(ctx context.Context, slug string) (AIArtifact, error) {
	var a AIArtifact
	err := s.Pool.QueryRow(ctx, `
                SELECT id, kind, title, subject, class_level, data, share_slug, created_at
                FROM study.ai_artifacts
                WHERE share_slug = $1`,
		slug,
	).Scan(&a.ID, &a.Kind, &a.Title, &a.Subject, &a.ClassLevel, &a.Data, &a.ShareSlug, &a.CreatedAt)
	return a, err
}

// SetAIArtifactShareSlug stamps (or restamps) an artifact's public
// share slug. Quizzes only by caller convention.
func (s *Store) SetAIArtifactShareSlug(ctx context.Context, userID, id, slug string) error {
	tag, err := s.Pool.Exec(ctx, `
                UPDATE study.ai_artifacts
                SET share_slug = $3, updated_at = now()
                WHERE id = $1 AND user_id = $2`,
		id, userID, slug,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateAIArtifactData fills (or refills) an artifact's generated
// payload. The async generators: the row is created pending, the
// goroutine lands the real document here when the provider answers.
func (s *Store) UpdateAIArtifactData(ctx context.Context, userID, id string, data json.RawMessage) error {
	tag, err := s.Pool.Exec(ctx, `
                UPDATE study.ai_artifacts
                SET data = $3, updated_at = now()
                WHERE id = $1 AND user_id = $2`,
		id, userID, data,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

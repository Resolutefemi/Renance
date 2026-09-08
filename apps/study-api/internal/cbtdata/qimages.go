// Package cbtdata — embedded question images.
//
// myschool-sourced past questions reference diagrams (graphs, geometric
// figures, circuit sketches) by URL. Those images are vendored into this
// directory (content-addressed names, sha1(url)[:20].<ext>) and compiled
// into the binary so a single Render deploy carries them. The HTTP layer
// exposes them, unauthenticated, at /qimages/{name}: a question image is
// student-visible material by definition; a worked-solution image is
// sealed server-side (its question→image mapping lives only in the
// answer key), so the flat namespace leaks nothing.
package cbtdata

import (
	"embed"
	"io/fs"
)

//go:embed qimages/*
var qimageFS embed.FS

// QImage returns the raw bytes of the embedded image file, or
// fs.ErrNotExist when the name is unknown.
func QImage(name string) ([]byte, error) {
	if len(name) > 64 || name != safeQImageName(name) {
		return nil, fs.ErrNotExist
	}
	return qimageFS.ReadFile("qimages/" + name)
}

// QImageNames lists every embedded image file (used by a debug/health
// endpoint and by tests to assert the embed is not empty).
func QImageNames() []string {
	entries, err := fs.ReadDir(qimageFS, "qimages")
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() {
			out = append(out, e.Name())
		}
	}
	return out
}

// safeQImageName rejects anything that is not a plain lowercase
// hex-ish filename with an image extension — traversal can never reach
// the embed anyway (embed paths cannot escape), this just keeps
// lookups cheap and predictable.
func safeQImageName(name string) bool {
	if name == "" {
		return false
	}
	dot := -1
	for i := 0; i < len(name); i++ {
		c := name[i]
		switch {
		case c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '_':
		case c == '.':
			if i == 0 || dot == i-1 {
				return false
			}
			dot = i
		default:
			return false
		}
	}
	if dot < 0 || dot == len(name)-1 {
		return false
	}
	switch name[dot:] {
	case ".jpg", ".jpeg", ".png", ".gif", ".webp":
		return true
	}
	return false
}

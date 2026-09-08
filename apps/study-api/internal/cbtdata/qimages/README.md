# qimages — embedded question diagrams

Content-addressed image files (name = `sha1(source URL)[:20]` + extension)
vendored from the myschool.ng classroom archive. Compiled into the binary
via `go:embed` (see ../qimages.go) and served unauthenticated at
`/qimages/{name}`.

- Question images (graphs, figures, circuit sketches) are student-visible
  material: bundles reference them by the `image` / inline `img` fields.
- Worked-solution images are sealed: the question → image mapping lives
  only in the server-side answer key, so the flat namespace leaks nothing.

Regenerate with `node scripts/download_qimages.js` in the workspace.

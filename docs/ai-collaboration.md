# Human + AI Pairing Protocol (Renance)

This project is built by one human developer plus AI assistants. These rules
keep sessions fast and safe.

## Session rhythm (~20h/week)

1. `pnpm sync` — local matches GitHub before anything else.
2. Read `docs/ACTIVE_PHASE.md` — pick ONE task from the current gate list.
3. Say the scope out loud in the prompt, e.g. "implement verification state
   transitions in core only". Scope discipline beats speed.
4. Review EVERY generated diff before committing. Run `pnpm typecheck &&
   pnpm test` — green gates, then commit.
5. `pnpm sync --push` at the end.

## Division of labour

| AI does well | You must own |
|--------------|--------------|
| scaffolding boilerplate | product decisions |
| migration drafts | reviewing migrations |
| test generation | acceptance criteria |
| repetitive CRUD wiring | security-sensitive code (auth, payments) |

## Hard safety rules

- Secrets never enter prompts, chats or repos — `.env` is gitignored; keys
  live only in `.env` / deploy dashboard.
- Payments and auth flows get line-by-line human review, always.
- Migrations are reviewed for destructive ops (`DROP`, `ALTER ... TYPE`)
  before applying, even in dev branches.

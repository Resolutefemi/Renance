// Public surface of @renance/db.
// Runtime client + every module's table definitions. Importing a FOREIGN
// module's tables from an api feature module violates the boundary contract
// (docs/architecture.md) — reviewers should reject such PRs.
export * from './client';
export * from './types/citext';
export * from './schema';

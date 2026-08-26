// schema-per-module barrel. Every module owns exactly one file here and one
// Postgres schema. Cross-module table imports are FORBIDDEN — see
// docs/architecture.md boundary contract.
export * from './cbt';
export * from './core';
export * from './payroll';
export * from './school';
export * from './sme';
export * from './skills';
export * from './utilities';

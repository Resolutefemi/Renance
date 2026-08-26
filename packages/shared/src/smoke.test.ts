import { describe, expect, it } from 'vitest';
import { MODULE_REGISTRY, emailSchema } from './index';

describe('shared contracts smoke', () => {
  it('registry stays aligned with schema-per-module doctrine', () => {
    expect(MODULE_REGISTRY.map((m) => m.id).sort()).toEqual([
      'cbt',
      'payroll',
      'school',
      'skills',
      'sme',
      'utilities',
    ]);
  });

  it('normalises emails', () => {
    expect(emailSchema.parse('  Ada@Example.COM ')).toBe('ada@example.com');
  });
});

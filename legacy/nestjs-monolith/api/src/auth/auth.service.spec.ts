import 'reflect-metadata';
import { describe, expect, it } from 'vitest';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';

import { AuthService } from './auth.service';

// ---------------------------------------------------------------------------
// Minimal Drizzle query-builder fake — only the chains AuthService uses:
//   select().from().where().limit()        -> Promise<UserRow-ish[]>
//   insert().values().returning()          -> Promise<UserRow-ish[]>
// ---------------------------------------------------------------------------

type Row = Record<string, unknown>;

function makeDbFake(opts: { existing: Row[]; inserted?: Row[] }) {
  return {
    db: {
      select: () => ({
        from: () => ({
          where: () => ({
            limit: async () => opts.existing,
          }),
        }),
      }),
      insert: () => ({
        values: (_v: Row) => ({
          returning: async () => opts.inserted ?? [],
        }),
      }),
    },
  } as unknown as ConstructorParameters<typeof AuthService>[0];
}

function makeJwtFake(): JwtService {
  // real crypto, no Nest DI — proves payload roundtrip too
  const real = new JwtService({ secret: 'test-secret' });
  return real as JwtService;
}

const userRow = (over: Partial<Row> = {}): Row => ({
  id: '11111111-1111-4111-8111-111111111111',
  email: 'ada@example.com',
  passwordHash: '$2a$12$hash',
  displayName: 'Ada',
  status: 'active',
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
  ...over,
});

describe('AuthService', () => {
  it('hashes passwords with bcrypt and never stores plaintext', async () => {
    const hash = await bcrypt.hash('s3cret99', 12);
    expect(hash).not.toContain('s3cret99');
    expect(await bcrypt.compare('s3cret99', hash)).toBe(true);
    expect(await bcrypt.compare('wrongpass1', hash)).toBe(false);
  });

  it('register: happy path returns public user (no hash leak) + verifiable token', async () => {
    const inserted = userRow({
      passwordHash: await bcrypt.hash('Passw0rd1', 12),
    });
    const svc = new AuthService(makeDbFake({ existing: [], inserted: [inserted] }), makeJwtFake());

    const res = await svc.register({
      email: 'ada@example.com',
      password: 'Passw0rd1',
      displayName: 'Ada',
    });

    expect(res.user.email).toBe('ada@example.com');
    expect(res.user.createdAt).toBe('2026-01-01T00:00:00.000Z');
    expect(JSON.stringify(res.user)).not.toContain('passwordHash');

    const payload = await makeJwtFake().verifyAsync(res.accessToken);
    expect(payload.sub).toBe(inserted.id);
  });

  it('register: duplicate email -> ConflictException before any insert', async () => {
    const svc = new AuthService(
      makeDbFake({ existing: [{ id: 'x' }] }), // SELECT finds a hit
      makeJwtFake(),
    );
    await expect(
      svc.register({ email: 'ada@example.com', password: 'Passw0rd1', displayName: 'Ada' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('login: wrong password -> uniform UnauthorizedException', async () => {
    const row = userRow({ passwordHash: await bcrypt.hash('Correct5', 12) });
    const svc = new AuthService(makeDbFake({ existing: [row] }), makeJwtFake());

    await expect(svc.login({ email: 'ada@example.com', password: 'wrong999' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('login: suspended account blocked even with correct password', async () => {
    const row = userRow({ passwordHash: await bcrypt.hash('Correct5', 12), status: 'suspended' });
    const svc = new AuthService(makeDbFake({ existing: [row] }), makeJwtFake());

    await expect(svc.login({ email: 'ada@example.com', password: 'Correct5' })).rejects.toThrow(
      /suspended/,
    );
  });
});

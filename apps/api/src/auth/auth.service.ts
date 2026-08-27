import {
  ConflictException,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { eq } from 'drizzle-orm';
import { users, type Db as DbClient, type UserRow } from '@renance/db';
import type {
  ChangePasswordRequest,
  LoginRequest,
  PublicUser,
  RegisterRequest,
  UpdateProfileRequest,
} from '@renance/shared';
import { DB } from '../db/db.module';

const BCRYPT_COST = 12;

function toPublicUser(row: UserRow): PublicUser {
  return {
    id: row.id,
    email: row.email,
    displayName: row.displayName,
    status: row.status,
    createdAt: row.createdAt.toISOString(),
  };
}

@Injectable()
export class AuthService {
  constructor(
    @Inject(DB) private readonly database: DbClient,
    // Explicit @Inject instead of relying on design:paramtypes: tsx/esbuild
    // does not emit decorator type metadata, and Nest DI must not depend on it.
    @Inject(JwtService) private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterRequest): Promise<{ user: PublicUser; accessToken: string }> {
    const existing = await this.findIdByEmail(dto.email);
    if (existing) {
      throw new ConflictException('email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_COST);

    let created: UserRow | undefined;
    try {
      const rows = await this.database.db
        .insert(users)
        .values({
          email: dto.email,
          passwordHash,
          displayName: dto.displayName,
        })
        .returning();
      created = rows.at(0);
    } catch (err) {
      // Race safety net: citext UNIQUE violation between our SELECT and INSERT
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException('email already registered');
      }
      throw err;
    }
    if (!created) throw new ConflictException('email already registered');

    return { user: toPublicUser(created), accessToken: await this.signToken(created) };
  }

  async login(dto: LoginRequest): Promise<{ user: PublicUser; accessToken: string }> {
    const [row] = await this.database.db
      .select()
      .from(users)
      .where(eq(users.email, dto.email))
      .limit(1);

    // Uniform error for unknown email AND wrong password — never reveal which failed.
    if (!row || !(await bcrypt.compare(dto.password, row.passwordHash))) {
      throw new UnauthorizedException('invalid email or password');
    }
    if (row.status === 'suspended') {
      throw new UnauthorizedException('account suspended');
    }

    return { user: toPublicUser(row), accessToken: await this.signToken(row) };
  }

  async me(userId: string): Promise<PublicUser> {
    const [row] = await this.database.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    if (!row) throw new UnauthorizedException(); // token valid, user vanished
    return toPublicUser(row);
  }

  /** Gate 1.6 — change own display name. */
  async updateProfile(userId: string, dto: UpdateProfileRequest): Promise<PublicUser> {
    const updated = await this.database.db
      .update(users)
      .set({ displayName: dto.displayName, updatedAt: new Date() })
      .where(eq(users.id, userId))
      .returning();
    const row = updated.at(0);
    if (!row) throw new UnauthorizedException(); // token valid, user vanished
    return toPublicUser(row);
  }

  /** Gate 1.6 — change own password. Current must verify (401 otherwise);
   *  new password re-hashed with the same bcrypt cost. Existing tokens stay
   *  valid until expiry by design (12h window; revocation lands Phase 4). */
  async changePassword(userId: string, dto: ChangePasswordRequest): Promise<PublicUser> {
    const [row] = await this.database.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    if (!row || !(await bcrypt.compare(dto.currentPassword, row.passwordHash))) {
      throw new UnauthorizedException('current password is incorrect');
    }
    const passwordHash = await bcrypt.hash(dto.newPassword, 12);
    const updated = await this.database.db
      .update(users)
      .set({ passwordHash, updatedAt: new Date() })
      .where(eq(users.id, userId))
      .returning();
    const updatedRow = updated.at(0);
    if (!updatedRow) throw new UnauthorizedException();
    return toPublicUser(updatedRow);
  }

  private async findIdByEmail(email: string): Promise<string | undefined> {
    const [row] = await this.database.db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, email))
      .limit(1);
    return row?.id;
  }

  private signToken(row: Pick<UserRow, 'id' | 'email'>): Promise<string> {
    return this.jwt.signAsync({ sub: row.id, email: row.email });
  }
}

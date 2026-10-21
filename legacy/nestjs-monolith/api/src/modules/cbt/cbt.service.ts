import { createHash } from 'node:crypto';
import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { and, desc, eq } from 'drizzle-orm';
import { attempts, bundles, type Db as DbClient, type BundleRow, type MembershipRow } from '@renance/db';
import type {
  AttemptResult,
  BundleFetch,
  BundleMeta,
  PublishBundleRequest,
  SubmitAttemptRequest,
} from '@renance/shared';
import { DB } from '../../db/db.module';
import { OrgsService } from '../../core/orgs.service';
import { canManageMembers } from '../../core/rbac';
import type { OrgRole } from '@renance/shared';
import { gradeAttempt } from './grading';

function toMeta(row: BundleRow): BundleMeta {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    version: row.version,
    questionCount: row.questionCount,
    totalMarks: row.totalMarks,
    durationMinutes: row.durationMinutes,
    sha256: row.sha256,
    status: row.status,
    createdAt: row.createdAt.toISOString(),
  };
}

@Injectable()
export class CbtService {
  constructor(
    @Inject(DB) private readonly database: DbClient,
    @Inject(OrgsService) private readonly orgs: OrgsService,
  ) {}

  /** Org admin publishes a bundle WITH its key (key stored, never returned). */
  async publish(orgId: string, meId: string, dto: PublishBundleRequest): Promise<BundleMeta> {
    await this.requireActiveManager(orgId, meId);
    const payload = dto.questions; // student-safe by contract (no answer fields exist on it)
    const sha256 = createHash('sha256').update(JSON.stringify(payload)).digest('hex');
    try {
      const rows = await this.database.db
        .insert(bundles)
        .values({
          organizationId: orgId,
          code: dto.code,
          version: dto.version,
          title: dto.title,
          sha256,
          questionCount: payload.length,
          totalMarks: payload.reduce((s, q) => s + q.marks, 0),
          durationMinutes: dto.durationMinutes,
          payload,
          answerKey: dto.answerKey,
          status: 'published',
          createdById: meId,
        })
        .returning();
      const row = rows.at(0);
      if (!row) throw new ConflictException('could not publish bundle');
      return toMeta(row);
    } catch (err) {
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException(`bundle ${dto.code} v${dto.version} already exists for this org`);
      }
      throw err;
    }
  }

  /** Manifest: published bundles of my org, metadata only. */
  async manifest(orgId: string, meId: string): Promise<BundleMeta[]> {
    await this.requireActiveMember(orgId, meId);
    const rows = await this.database.db
      .select()
      .from(bundles)
      .where(and(eq(bundles.organizationId, orgId), eq(bundles.status, 'published')))
      .orderBy(desc(bundles.createdAt));
    return rows.map(toMeta);
  }

  /** Full question bundle for an active member. The key is NEVER selected. */
  async fetch(orgId: string, meId: string, bundleId: string): Promise<BundleFetch> {
    await this.requireActiveMember(orgId, meId);
    const row = await this.findById(bundleId);
    if (!row || row.organizationId !== orgId) throw new NotFoundException('bundle not found');
    return { meta: toMeta(row), questions: row.payload as BundleFetch['questions'] };
  }

  /** Grade + record. One attempt per (bundle, user) in MVP. */
  async submitAttempt(
    orgId: string,
    meId: string,
    bundleId: string,
    dto: SubmitAttemptRequest,
  ): Promise<AttemptResult> {
    await this.requireActiveMember(orgId, meId);
    const row = await this.findById(bundleId);
    if (!row || row.organizationId !== orgId || row.status !== 'published') {
      throw new NotFoundException('bundle not found');
    }

    const dup = await this.database.db
      .select({ id: attempts.id })
      .from(attempts)
      .where(and(eq(attempts.bundleId, bundleId), eq(attempts.userId, meId)))
      .limit(1);
    if (dup.length > 0) throw new ConflictException('you have already taken this exam');

    const outcome = gradeAttempt(
      row.payload as BundleFetch['questions'],
      row.answerKey as Record<string, never>,
      dto.answers,
    );
    const inserted = await this.database.db
      .insert(attempts)
      .values({
        bundleId,
        userId: meId,
        organizationId: orgId,
        status: 'graded',
        answers: dto.answers,
        score: outcome.score,
        totalMarks: outcome.totalMarks,
      })
      .returning();
    const attempt = inserted.at(0);
    if (!attempt) throw new ConflictException('could not record attempt');

    return {
      id: attempt.id,
      bundleId,
      status: 'graded',
      score: outcome.score,
      totalMarks: outcome.totalMarks,
      breakdown: outcome.breakdown,
      submittedAt: attempt.createdAt.toISOString(),
    };
  }

  /** My result for a bundle (404 before attempting). */
  async myAttempt(orgId: string, meId: string, bundleId: string): Promise<AttemptResult> {
    await this.requireActiveMember(orgId, meId);
    const rows = await this.database.db
      .select()
      .from(attempts)
      .where(and(eq(attempts.bundleId, bundleId), eq(attempts.userId, meId)))
      .limit(1);
    const attempt = rows.at(0);
    if (!attempt) throw new NotFoundException('no attempt recorded for this bundle');
    // rebuild breakdown from stored data so reveal material stays consistent
    const row = await this.findById(bundleId);
    const outcome = gradeAttempt(
      (row?.payload ?? []) as BundleFetch['questions'],
      (row?.answerKey ?? {}) as Record<string, never>,
      attempt.answers as Record<string, string>,
    );
    return {
      id: attempt.id,
      bundleId: attempt.bundleId,
      status: attempt.status,
      score: attempt.score,
      totalMarks: attempt.totalMarks,
      breakdown: outcome.breakdown,
      submittedAt: attempt.createdAt.toISOString(),
    };
  }

  /** Via CoreModule facade — CBT never reads core tables directly. */
  private async requireActiveManager(orgId: string, userId: string): Promise<MembershipRow> {
    const m: MembershipRow = await this.orgs.assertActiveMembership(orgId, userId);
    if (!canManageMembers(m.role as OrgRole)) {
      throw new ForbiddenException('owner or admin role required');
    }
    return m;
  }

  private async requireActiveMember(orgId: string, userId: string): Promise<MembershipRow> {
    return this.orgs.assertActiveMembership(orgId, userId);
  }

  private async findById(bundleId: string): Promise<BundleRow | undefined> {
    const rows = await this.database.db.select().from(bundles).where(eq(bundles.id, bundleId)).limit(1);
    return rows.at(0);
  }
}

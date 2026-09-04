import { BADGES } from '@/lib/progress';
import BadgeDetailClient from './badge-client';

/**
 * Server wrapper for the Stitch badge_detail_light screen.
 *
 * Static export pins one URL per catalog badge, mirroring the codes in
 * apps/study-api/internal/store/gamification.go.
 */

export function generateStaticParams() {
  return BADGES.map((b) => ({ code: b.code }));
}

export default async function BadgeRoute({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;
  return <BadgeDetailClient code={code} />;
}

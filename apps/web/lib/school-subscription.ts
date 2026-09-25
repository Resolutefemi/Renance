/**
 * School subscription state client. The school plan lives on the school
 * row in Neon (plan, plan_expires_at, trial_ends_at) so the owner can
 * grant or extend straight from the console; this reads the friendly
 * summary of it.
 */

import { api } from './api';
import { getActiveSchool } from './school';

export interface SchoolPlanState {
  plan: string;
  planSource?: string;
  expiresAt?: string | null;
  trialEndsAt?: string | null;
  daysLeft?: number | null;
  trialDaysLeft?: number | null;
}

export function fetchSchoolPlan(): Promise<SchoolPlanState> {
  const schoolId = getActiveSchool()?.schoolId ?? '';
  return api<SchoolPlanState>(
    `/school/plan?schoolId=${encodeURIComponent(schoolId)}`,
    { noRedirect: true },
  );
}

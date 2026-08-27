import { SetMetadata } from '@nestjs/common';
import type { OrgRole } from '@renance/shared';

export const ORG_ROLE_KEY = 'renance:orgRole';

/**
 * Guard clause for routes under an org scope: the caller's ACTIVE membership
 * of the :orgId route param must rank ≥ `role` (owner > admin > member).
 * Always pair with OrgRolesGuard — the decorator only supplies the metadata.
 *
 *   @UseGuards(OrgRolesGuard)
 *   @RequireOrgRole('admin')
 */
export const RequireOrgRole = (role: OrgRole) => SetMetadata(ORG_ROLE_KEY, role);

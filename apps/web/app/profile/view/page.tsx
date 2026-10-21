import ProfileViewClient from './profile-view-client';

/**
 * Static-export wrapper for the public profile view. The client reads
 * ?u= via useSearchParams, which needs a Suspense boundary under
 * `output: export` (same pattern as the leaderboard's ?tab= wrapper).
 * The live Vercel rewrite maps /u/{username} onto this page.
 */
export default function ProfileViewRoute() {
  return <ProfileViewClient />;
}

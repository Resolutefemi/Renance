/**
 * Phase 5 — Store Links & Growth Telemetry Configuration
 *
 * Single source of truth for the Google Play Store app listing URL,
 * UTM campaign tracking, and fallback web practice links.
 *
 * Once your app is live on Google Play Console:
 *   1. Paste the live package ID or custom URL into PLAY_STORE_URL.
 *   2. All 1,962 exam practice pages and curriculum hubs will automatically
 *      direct students to your approved Play Store listing!
 */

export const STORE_CONFIG = {
  // Package ID registered with Google Play Console
  packageId: 'app.renance.study',

  // Live Play Store base URL (automatically falls back to search/listing)
  get playStoreUrl(): string {
    return `https://play.google.com/store/apps/details?id=${this.packageId}`;
  },

  /**
   * Generates a fully tagged UTM link for tracking organic acquisition in Google Analytics
   * and Google Play Console acquisition reports.
   *
   * @param source e.g. 'seo_quiz_complete', 'seo_paper_hero', 'seo_pillar'
   * @param examBody e.g. 'jamb', 'waec', 'neco'
   * @param subject e.g. 'physics', 'mathematics'
   * @param year e.g. 2023
   */
  getTrackedPlayStoreUrl(
    source: string,
    examBody?: string,
    subject?: string,
    year?: number | string,
  ): string {
    const params = new URLSearchParams({
      id: this.packageId,
      utm_source: source,
      utm_medium: 'organic_search',
      utm_campaign: examBody ? `${examBody}_past_questions` : 'organic_seo',
    });

    if (subject) params.set('utm_content', String(subject));
    if (year) params.set('utm_term', String(year));

    return `https://play.google.com/store/apps/details?${params.toString()}`;
  },
};

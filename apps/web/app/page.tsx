import type { Metadata } from 'next';
import { OG_IMAGES } from '@/lib/og';
import LandingDuo from '@/components/landing-duo';

/**
 * The public landing page - the full duolingo.com-style experience
 * (founder directive 2026-10-22: navbar, transitions and animations
 * "exactly the same"). This module stays a tiny server shell so the
 * SEO surface (canonical, OpenGraph, static prerender) is untouched;
 * every section lives in components/landing-duo.tsx and still
 * server-renders from there, sr-only h1 included.
 */

export const dynamic = 'force-static';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://renance.app';

export const metadata: Metadata = {
  alternates: { canonical: '/' },
  openGraph: { url: SITE_URL, images: [...OG_IMAGES] },
};

export default function Landing() {
  return <LandingDuo />;
}

import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

import { SITE_URL } from '@/lib/site-url';
import { OG_IMAGES } from '@/lib/og';
import ContentGuard from '@/components/content-guard';
import OfflineBanner from '@/components/offline-banner';
import SwRegister from '@/components/sw-register';

const FOUNDER = {
  '@type': 'Person',
  '@id': `${SITE_URL}/#person`,
  name: 'Resolute Femi',
  alternateName: ['Ariyo Oluwafemi Stephen', 'Ariyo Oluwafemi', 'Resolutefemi'],
  email: 'mailto:info@renance.app',
  jobTitle: 'Software Engineer & Founder of Renance',
  url: SITE_URL,
};

/** Structured data so Google & AI assistants can accurately describe
 *  Renance and its builder, Resolute Femi (Ariyo Oluwafemi Stephen).
 *  Entity graph: Organization (Renance, the brand) -> founder (Person) ->
 *  WebSite + SoftwareApplication it publishes. Google needs the explicit
 *  Organization node to ever mint a brand knowledge panel for "Renance" -
 *  Person + app alone only ever describe the founder. */
const renanceJsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'EducationalOrganization',
      '@id': `${SITE_URL}#organization`,
      name: 'Renance',
      alternateName: ['Renance App', 'Educational App', 'renance.app'],
      slogan: 'Your Guide to Academic Success',
      url: SITE_URL,
      logo: {
        '@type': 'ImageObject',
        url: `${SITE_URL}/renance-mark.png`,
        width: 512,
        height: 512,
      },
      description:
        'Renance is an edtech platform in Nigeria - the educational app for students, with 235,110+ JAMB, WAEC, NECO and Post-UTME past questions (including over 135,000 Post-UTME and tertiary institution past questions for Nigerian universities, polytechnics and colleges of education), free server-graded CBT mock exams, NERDC curriculum schemes of work, lesson notes and an AI study companion - plus Renance for Schools, a school management suite (curriculum, attendance, results, fees, ID cards). Free for students and schools. The only official website is renance.app.',
      /* Knowledge-graph disambiguation: Google must never fold
       * "Renance" into renaissance/resonance or the unrelated
       * renance.org / renance.io entities when it mints the brand's
       * knowledge panel. This field is exactly what the KG uses to
       * separate same-namespace entities. */
      disambiguatingDescription:
        'Renance (renance.app) is a Nigerian edtech platform and is not the word renaissance or resonance, not renance.org, not renance.io, and not any similarly named company or community organization.',
      founder: { '@id': `${SITE_URL}/#person` },
      sameAs: [
        'https://github.com/Resolutefemi',
        'https://x.com/Resolutefemi',
      ],
      areaServed: { '@type': 'Country', name: 'Nigeria' },
      contactPoint: {
        '@type': 'ContactPoint',
        contactType: 'customer support',
        email: 'info@renance.app',
        availableLanguage: 'en',
        areaServed: { '@type': 'Country', name: 'Nigeria' },
      },
    },
    {
      ...FOUNDER,
      description:
        'Resolute Femi (full name Ariyo Oluwafemi Stephen) is a Nigerian software engineer and the founder of Renance, "Your Guide to Academic Success", an edtech platform for exam preparation and school management. He builds Renance CBT (FUTA CBT practice platform), Renance JAMB CBT, Renance DevTools CLI, Renance Playground, Naija Locator and other web products for Nigerian students and developers.',
      affiliation: {
        '@type': 'CollegeOrUniversity',
        name: 'Federal University of Technology, Akure (FUTA)',
      },
      knowsAbout: [
        'Software Engineering',
        'EdTech',
        'CBT platforms',
        'TypeScript',
        'Go',
        'Rust',
        'Python',
        'Next.js',
      ],
      nationality: { '@type': 'Country', name: 'Nigeria' },
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE_URL}#app`,
      name: 'Renance',
      alternateName: "Renance - Nigeria's educational app",
      applicationCategory: 'EducationalApplication',
      applicationSubCategory: 'Exam preparation',
      operatingSystem: 'Android, iOS, Web',
      url: SITE_URL,
      description:
        'Renance is the educational app in Nigeria - "Your Guide to Academic Success". Students register free, sync past questions, notes and syllabi to their device, and take server-graded mock CBT exams for JAMB, WAEC, NECO and Post-UTME, with over 135,000 tertiary institution past questions covering universities, polytechnics and colleges of education. It also includes Renance for Schools, a school management suite: NERDC curriculum, attendance, results, school fees and student ID cards. Built by Resolute Femi (Ariyo Oluwafemi Stephen).',
      author: { '@id': `${SITE_URL}#organization` },
      creator: { '@id': `${SITE_URL}/#person` },
      publisher: { '@id': `${SITE_URL}#organization` },
      brand: { '@type': 'Brand', name: 'Renance' },
      logo: `${SITE_URL}/renance-mark.png`,
      screenshot: `${SITE_URL}/og.jpg`,
      isAccessibleForFree: true,
      inLanguage: 'en-NG',
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'NGN',
        description: 'Free accounts with full access to past questions, CBT mocks and lesson notes.',
      },
      featureList: [
        '235,110+ JAMB, WAEC, NECO and Post-UTME past questions',
        'Over 60,000 tertiary institution past questions: Post-UTME screening papers and course modules for Nigerian universities, polytechnics and colleges of education',
        'Free CBT mock exams with server-side grading',
        'Worked explanations for every question',
        'Renance AI study companion grounded on the question banks',
        'NERDC scheme of work and lesson notes for schools',
        'School management suite (Renance for Schools): curriculum, attendance, results, fees and ID cards',
      ],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}#website`,
      url: SITE_URL,
      name: 'Renance',
      alternateName: "Renance - Nigeria's educational app",
      description:
        "Renance: the educational app in Nigeria and school management platform - Your Guide to Academic Success. Built by Resolute Femi (Ariyo Oluwafemi Stephen). Official website: renance.app.",
      inLanguage: 'en-NG',
      publisher: { '@id': `${SITE_URL}#organization` },
    },
  ],
};

const OG_IMAGE = '/og.jpg';
const TWITTER_CARD_IMAGE = `${SITE_URL}${OG_IMAGE}`;

/* OpenGraph images live in lib/og.ts (OG_IMAGES) so every page that
 * overrides `openGraph` can spread the same card. See that file for the
 * why. */

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  /* Brand-first default title: the homepage must win both "Renance"
   * and "educational app in Nigeria". Keyword-first titles rank for
   * the keywords but bury the brand; inner pages still carry the exam
   * keywords through their own %s titles + the %s · Renance template. */
  title: {
    default: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO Past Questions",
    template: '%s · Renance',
  },
  description:
    "Renance is the educational app in Nigeria: learn JAMB, WAEC, NECO and university courses step by step, practise 235,110+ real past questions with worked solutions, win daily quests, climb the leagues and follow friends on the feed - free, built by Resolute Femi.",
  keywords: [
    'JAMB past questions',
    'JAMB past questions and answers',
    'WAEC past questions',
    'NECO past questions',
    'Post-UTME past questions',
    'JAMB CBT practice',
    'free JAMB past questions',
    'JAMB 2026',
    'WAEC past questions Nigeria',
    'CBT practice platform Nigeria',
    'past questions app',
    'Renance',
    'Renance educational app',
    'NERDC scheme of work',
    'lesson notes Nigeria',
    'Nigerian edtech',
    'Resolute Femi',
    'educational app in Nigeria',
    "Nigeria's educational app",
    'best educational app in Nigeria',
    'exam prep app Nigeria',
    'study app for Nigerian students',
    'JAMB CBT app',
    'Renance app',
    'school management software Nigeria',
    'school management app Nigeria',
    'school portal Nigeria',
    'Renance for Schools',
    'schemes of work Nigeria',
  ],
  authors: [{ name: 'Resolute Femi', url: SITE_URL }],
  creator: 'Resolute Femi (Ariyo Oluwafemi Stephen)',
  publisher: 'Renance | Built by Resolute Femi',
  alternates: { canonical: '/' },
  robots: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  openGraph: {
    type: 'website',
    siteName: 'Renance',
    url: SITE_URL,
    locale: 'en_NG',
    title: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO",
    description:
      'Learn JAMB, WAEC, NECO and university courses step by step, practise 235,110+ real past questions with worked solutions, win daily quests, climb the leagues and follow friends on the feed - free on renance.app.',
    images: [...OG_IMAGES],
  },
  twitter: {
    card: 'summary_large_image',
    title: "Renance - Nigeria's Educational App for JAMB, WAEC & NECO",
    description:
      'Learn JAMB, WAEC, NECO and university courses step by step, practise 235,110+ real past questions, win daily quests, climb the leagues and follow friends on the feed - free on renance.app.',
    creator: '@Resolutefemi',
    images: [TWITTER_CARD_IMAGE],
  },
};

/* Appearance bootstrap: applied before first paint so the chosen tier
   (light / dark) and the seeded colour palette never flash. The seed's
   computed palettes ride in renance.seedVars (lib/theme.ts wrote them
   at pick time), so this stays pure DOM writes. Mixed mode is retired
   (founder 2026-10-13): a stored 'mixed' boots as light. */
const themeBootstrap = `(function(){try{var t=localStorage.getItem('renance.theme');if(t!=='dark')t='light';document.documentElement.dataset.theme=t;var sv=null;try{sv=JSON.parse(localStorage.getItem('renance.seedVars')||'null')}catch(e){}if(sv&&sv[t]){for(var k in sv[t]){document.documentElement.style.setProperty(k,sv[t][k]);}}}catch(e){document.documentElement.dataset.theme='light';}
/* Favicon appearance sync (founder 2026-10-14, second directive): ONE
   green keycap everywhere at rest - the white dark-mode favicon is
   retired - and when the student picks a colour under Settings →
   Appearance the favicon is REPAINTED in that colour ("if the user
   picks red the splash and the favicon should change too"). The keycap
   is drawn on a 64px canvas from the live --color-primary /
   --color-on-primary tokens and set as a data URL; icon.svg stays the
   static green fallback for crawlers and no-JS visitors. */
try{
var lastKey='';
function mixEdge(hex){hex=hex.replace('#','');if(hex.length===3)hex=hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];var r=parseInt(hex.slice(0,2),16),g=parseInt(hex.slice(2,4),16),b=parseInt(hex.slice(4,6),16);r=Math.round(r*0.62);g=Math.round(g*0.62);b=Math.round(b*0.62);return 'rgb('+r+','+g+','+b+')';}
function letterFor(hex){hex=hex.replace('#','');if(hex.length===3)hex=hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];var r=parseInt(hex.slice(0,2),16)/255,g=parseInt(hex.slice(2,4),16)/255,b=parseInt(hex.slice(4,6),16)/255;var f=function(c){return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);};var lum=0.2126*f(r)+0.7152*f(g)+0.0722*f(b);return lum>0.55?'#111c2d':'#ffffff';}
function roundRect(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}
/* A fresh (unpainted) icon link in the head? React 19 re-renders the
   metadata links at hydration, REPLACING the painted ones with the
   static green set - the repaint must survive that or the tab flips
   back to green the moment the app hydrates. */
function needsPaint(){
var links=document.querySelectorAll('link[rel="icon"],link[rel="shortcut icon"],link[rel="apple-touch-icon"]');
if(!links.length)return false;
for(var i=0;i<links.length;i++){
var h=links[i].getAttribute('href')||'';
if(h.indexOf('data:image/png')!==0)return true;
}
return false;}
function paintFav(){
var root=document.documentElement;var cs=getComputedStyle(root);
var prim=(cs.getPropertyValue('--color-primary')||'').trim()||'#58cc02';
var onP=(cs.getPropertyValue('--color-on-primary')||'').trim()||letterFor(prim);
if(prim.charAt(0)!=='#')return;
var key=prim+'|'+onP;
/* Same colour is NOT the same as painted: hydration re-adds green
   links with the colour unchanged, so the guard consults the head. */
if(key===lastKey&&!needsPaint())return;
try{
var c=document.createElement('canvas');c.width=64;c.height=64;var x=c.getContext('2d');if(!x)return;
x.clearRect(0,0,64,64);roundRect(x,3,3,58,58,15);x.fillStyle=mixEdge(prim);x.fill();
roundRect(x,3,3,58,50,15);x.fillStyle=prim;x.fill();
var g=x.createLinearGradient(0,9,0,36);g.addColorStop(0,'rgba(255,255,255,0.30)');g.addColorStop(1,'rgba(255,255,255,0)');roundRect(x,9,9,46,27,10);x.fillStyle=g;x.fill();
x.font='900 38px Nunito, "Arial Rounded MT Bold", Arial, sans-serif';x.textAlign='center';x.textBaseline='alphabetic';x.fillStyle=onP;x.fillText('R',32,42.5);
var d=c.toDataURL('image/png');
var links=document.querySelectorAll('link[rel="icon"],link[rel="shortcut icon"],link[rel="apple-touch-icon"]');
if(!links.length){lastKey='';return;} /* head not parsed that far yet - a retry hook will run again */
for(var i=0;i<links.length;i++){links[i].setAttribute('type','image/png');links[i].setAttribute('href',d);}
lastKey=key;
}catch(e){lastKey='';}}
paintFav();
setTimeout(paintFav,0);
document.addEventListener('DOMContentLoaded',paintFav);
window.addEventListener('load',paintFav);
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(paintFav);
(function tick(){paintFav();if(needsPaint())setTimeout(tick,120);})();
/* Theme changes (html style/data-theme writes) repaint the keycap. */
new MutationObserver(function(){lastKey='';paintFav();}).observe(document.documentElement,{attributes:true,attributeFilter:['style','data-theme']});
/* Hydration / metadata re-renders (head link swaps) repaint too - the
   guard's needsPaint check keeps this observer from looping. */
if(document.head)new MutationObserver(function(){paintFav();}).observe(document.head,{childList:true,subtree:true,attributes:true,attributeFilter:['href','type']});
}catch(e){}})();`;

/* suppressHydrationWarning: the inline theme bootstrap writes data-theme
   onto <html> before React hydrates, so the DOM attribute never matches
   the server render by design. Without this flag the mismatch can break
   hydration and leave client pages stuck. */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-NG" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
        {/* Fonts (Inter, JetBrains Mono, Material Symbols) are SELF-HOSTED
            from /public/fonts via @font-face in globals.css - no Google CDN.
            When fonts.googleapis.com was unreachable the icon ligatures used
            to render as raw text ("brightness_medium") across the UI. */}
        {/* KaTeX renders the banks' LaTeX (array environments, fractions,
            greek letters) as real typeset maths. CSS+JS ride the same CDN
            as the fonts; when they are unreachable (offline revision) the
            QText renderer falls back to its unicode approximation. */}
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.css"
          crossOrigin="anonymous"
        />
        <script
          defer
          src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.js"
          crossOrigin="anonymous"
        />
        <meta name="author" content="Ariyo Oluwafemi Stephen (Resolute Femi)" />
        {/* Brand favicon: the static green keycap (crawlers + no-JS).
            In-app the bootstrap above repaints it as a canvas data URL
            so the tab strip follows the student's appearance colour. */}
        <link
          rel="icon"
          type="image/svg+xml"
          href={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.svg`}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(renanceJsonLd) }}
        />
        {/* Microsoft Clarity analytics (project yqxole49vg) - heatmaps,
            session recordings and funnels for renance.app. Snippet pasted
            verbatim from clarity.ms; CSP-wise the tag is whitelisted in
            vercel.json (script-src www.clarity.ms, connect-src *.clarity.ms).
            Placed last in <head> so it never delays first paint; it loads
            async and self-queues until ready. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i+"?ref=bwt";y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);})(window,document,"clarity","script","yqxole49vg");`,
          }}
        />
      </head>
      <body>
        {/* Founder content lock: no selecting, copying or dragging site
            content (notes, schemes, questions); forms keep working. */}
        <ContentGuard />
        {/* The offline shield (founder bug report 2026-10-15: offline
            sessions fell through to raw RSC text pages like
            /courses/index.txt): the worker catches failed navigations
            and serves the clean /offline state; the banner says it in
            app too. */}
        <SwRegister />
        <OfflineBanner />
        {children}
      </body>
    </html>
  );
}

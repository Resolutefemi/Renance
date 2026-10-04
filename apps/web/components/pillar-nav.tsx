import Link from "next/link";

/**
 * Shared fixed navbar for the pillar/marketing pages (about, for-schools,
 * educational-app-in-nigeria). Renance brand: black and white. The bar is
 * position:fixed so it stays at the top while the page scrolls under it,
 * and the translucent white + backdrop blur gives the glassmorphism effect.
 * The Renance mark sits at the left of the "Renance" wordmark.
 *
 * Pages that render this component must add ~64px of top padding to their
 * root element so the hero does not hide under the bar.
 */
export default function PillarNav() {
  return (
    <>
      <style
        dangerouslySetInnerHTML={{
          __html: `
.pn-bar{position:fixed;top:0;left:0;right:0;z-index:90;background:rgba(255,255,255,.74);-webkit-backdrop-filter:blur(18px) saturate(170%);backdrop-filter:blur(18px) saturate(170%);border-bottom:1px solid rgba(10,10,10,.09);font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.pn-inner{max-width:1120px;margin:0 auto;padding:0 22px;height:64px;display:flex;align-items:center;justify-content:space-between;gap:18px}
.pn-brand{display:flex;align-items:center;gap:10px;text-decoration:none;color:#0a0a0a}
.pn-brand img{width:30px;height:30px;border-radius:9px;display:block;border:1px solid rgba(10,10,10,.12);background:#fff}
.pn-word{font-weight:800;font-size:18.5px;letter-spacing:-.02em}
.pn-links{display:flex;align-items:center;gap:26px}
.pn-links a{color:#4a4a4a;text-decoration:none;font-size:14.5px;font-weight:500}
.pn-links a:hover{color:#0a0a0a}
.pn-cta{background:var(--color-primary,#0a0a0a);color:var(--color-on-primary,#fff);text-decoration:none;font-size:14px;font-weight:600;border-radius:999px;padding:9px 18px;white-space:nowrap}
.pn-cta:hover{background:color-mix(in srgb, var(--color-primary,#0a0a0a) 78%, #000)}
@media(max-width:880px){.pn-links{display:none}}
`,
        }}
      />
      <header className="pn-bar">
        <div className="pn-inner">
          <Link href="/" className="pn-brand" aria-label="Renance home">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ""}/renance-mark.png`}
              alt="Renance logo"
              width={30}
              height={30}
            />
            <span className="pn-word">Renance</span>
          </Link>
          <nav className="pn-links" aria-label="Renance sections">
            <Link href="/practice/">Past questions</Link>
            <Link href="/curriculum/">Curriculum</Link>
            <Link href="/for-schools/">For Schools</Link>
            <Link href="/about/">About</Link>
          </nav>
          <Link href="/register/" className="pn-cta">
            Start free
          </Link>
        </div>
      </header>
    </>
  );
}

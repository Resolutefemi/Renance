'use client';

import type { CSSProperties, ReactNode } from 'react';
import { API_BASE } from './api';

/* ------------------------------------------------------------------ */
/* Question text rendering                                             */
/*                                                                     */
/* Past questions arrive in three shapes:                              */
/*   1. plain text (the founder's banks),                              */
/*   2. LaTeX inline math \( … \) (calculation subjects: fractions,    */
/*      superscripts, greek letters),                                  */
/*   3. small HTML fragments from the myschool archive (<sub>, <sup>,  */
/*      <br>, <table>, entities).                                      */
/*                                                                     */
/* The player used to print all three verbatim — the "raw markup in    */
/* maths questions" bug. This renderer converts the safe subset into   */
/* React nodes. It is NOT dangerouslySetInnerHTML: unknown tags are    */
/* unwrapped (text kept), attributes beyond a whitelisted set are      */
/* dropped, <script>/<style>/<iframe> content is discarded entirely,   */
/* and every text run goes through entity decoding + LaTeX conversion. */
/* ------------------------------------------------------------------ */

/** Resolve an origin-less media path (/qimages/…) against the API. */
export function apiImg(src: string): string {
  if (/^https?:\/\//i.test(src)) return src;
  return `${API_BASE}${src.startsWith('/') ? src : `/${src}`}`;
}

const ENTITIES: Record<string, string> = {
  nbsp: '\u00a0', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'",
  ldquo: '\u201c', rdquo: '\u201d', lsquo: '\u2018', rsquo: '\u2019',
  ndash: '\u2013', mdash: '\u2014', hellip: '\u2026', bull: '\u2022',
  middot: '\u00b7', deg: '\u00b0', plusmn: '\u00b1', times: '\u00d7',
  divide: '\u00f7', frac12: '\u00bd', frac14: '\u00bc', frac34: '\u00be',
  minus: '\u2212', equiv: '\u2261', le: '\u2264', ge: '\u2265',
  ne: '\u2260', asymp: '\u2248', infin: '\u221e', prime: '\u2032',
  Prime: '\u2033', darr: '\u2193', rarr: '\u2192', uarr: '\u2191',
  larr: '\u2190', harr: '\u2194', Alpha: '\u0391', Beta: '\u0392',
  Gamma: '\u0393', Delta: '\u0394', Theta: '\u0398', Lambda: '\u039b',
  Pi: '\u03a0', Sigma: '\u03a3', Phi: '\u03a6', Omega: '\u03a9',
  alpha: '\u03b1', beta: '\u03b2', gamma: '\u03b3', delta: '\u03b4',
  theta: '\u03b8', lambda: '\u03bb', mu: '\u03bc', pi: '\u03c0',
  rho: '\u03c1', sigma: '\u03c3', phi: '\u03c6', omega: '\u03c9',
  euro: '\u20a6', trade: '\u2122', sup2: '\u00b2',
  sup3: '\u00b3', frac13: '\u2153', permil: '\u2030',
};

export function decodeEntities(text: string): string {
  // legacy named references without a trailing semicolon (&nbsp often
  // appears that way in the archive)
  return text
    .replace(/&nbsp(?![a-zA-Z0-9;])/g, '\u00a0')
    .replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/g, (whole, body: string) => {
    if (body.startsWith('#x') || body.startsWith('#X')) {
      const code = parseInt(body.slice(2), 16);
      return Number.isFinite(code) ? String.fromCodePoint(code) : whole;
    }
    if (body.startsWith('#')) {
      const code = parseInt(body.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : whole;
    }
    return ENTITIES[body] ?? whole;
  });
}

const GREEK: Record<string, string> = {
  alpha: '\u03b1', beta: '\u03b2', gamma: '\u03b3', delta: '\u03b4',
  epsilon: '\u03b5', varepsilon: '\u03b5', zeta: '\u03b6', eta: '\u03b7',
  theta: '\u03b8', vartheta: '\u03d1', iota: '\u03b9', kappa: '\u03ba',
  lambda: '\u03bb', mu: '\u03bc', nu: '\u03bd', xi: '\u03be',
  pi: '\u03c0', rho: '\u03c1', sigma: '\u03c3', tau: '\u03c4',
  upsilon: '\u03c5', phi: '\u03c6', varphi: '\u03c6', chi: '\u03c7',
  psi: '\u03c8', omega: '\u03c9', Gamma: '\u0393', Delta: '\u0394',
  Theta: '\u0398', Lambda: '\u039b', Xi: '\u039e', Pi: '\u03a0',
  Sigma: '\u03a3', Phi: '\u03a6', Psi: '\u03a8', Omega: '\u03a9',
};

const SYMBOLS: Record<string, string> = {
  times: '\u00d7', div: '\u00f7', cdot: '\u00b7', pm: '\u00b1', mp: '\u2213',
  leq: '\u2264', le: '\u2264', geq: '\u2265', ge: '\u2265', neq: '\u2260',
  ne: '\u2260', approx: '\u2248', equiv: '\u2261', infty: '\u221e',
  propto: '\u221d', degree: '\u00b0', circ: '\u00b0', sum: '\u2211',
  prod: '\u220f', int: '\u222b', partial: '\u2202', nabla: '\u2207',
  sqrt: '\u221a', perp: '\u22a5', parallel: '\u2225', angle: '\u2220',
  triangle: '\u25b3', therefore: '\u2234', because: '\u2235',
  in: '\u2208', notin: '\u2209', subset: '\u2282', supset: '\u2283',
  cup: '\u222a', cap: '\u2229', emptyset: '\u2205', forall: '\u2200',
  exists: '\u2203', rightarrow: '\u2192', to: '\u2192', leftarrow: '\u2190',
  Rightarrow: '\u21d2', Leftarrow: '\u21d0', leftrightarrow: '\u2194',
  Leftrightarrow: '\u21d4', uparrow: '\u2191', downarrow: '\u2193',
  ldots: '\u2026', cdots: '\u22ef', dots: '\u2026', quad: '\u2003',
  qquad: '\u2003\u2003', langle: '\u27e8', rangle: '\u27e9',
  inftyy: '\u221e', ell: '\u2113', Re: '\u211c', Im: '\u2111',
  aleph: '\u2135', hbar: '\u210f', elll: '\u2113',
};

/** Group a LaTeX body into a balanced {…} group starting at index i (which
 *  must point at '{'). Returns [content, nextIndex] or [literal, i]. */
function latexGroup(src: string, i: number): [string, number] {
  if (src[i] !== '{') {
    // single-character group (\^2, _i)
    if (i < src.length) return [src[i], i + 1];
    return ['', i];
  }
  let depth = 0;
  for (let j = i; j < src.length; j++) {
    if (src[j] === '{') depth++;
    else if (src[j] === '}') {
      depth--;
      if (depth === 0) return [src.slice(i + 1, j), j + 1];
    }
  }
  return [src.slice(i + 1), src.length];
}

/** Convert the LaTeX inline-math body (between \( and \)) into a plain
 *  string with unicode super/subscripts — enough for MCQ options, no
 *  full TeX engine involved. */
export function latexToText(src: string): string {
  let out = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '\\') {
      const m = /^\\([a-zA-Z]+|.)`?/.exec(src.slice(i));
      if (!m) { i++; continue; }
      const cmd = m[1];
      i += m[0].length;
      if (cmd === 'frac' || cmd === 'dfrac' || cmd === 'tfrac') {
        let [num, i1] = latexGroup(src, i);
        let [den, i2] = latexGroup(src, i1);
        num = latexToText(num);
        den = latexToText(den);
        out += num.length === 1 && den.length === 1 ? `${num}\u2044${den}` : `(${num})\u2044(${den})`;
        i = i2;
        continue;
      }
      if (cmd === 'sqrt') {
        let j = i;
        while (src[j] === ' ') j++;
        if (src[j] === '[') { // optional root degree — skip to ]
          const close = src.indexOf(']', j);
          i = close >= 0 ? close + 1 : j;
          let [body2, i3] = latexGroup(src, i);
          out += `${latexToText(body2)}\u221a`;
          i = i3;
          continue;
        }
        const [body, i1] = latexGroup(src, j);
        out += `\u221a(${latexToText(body)})`;
        i = i1;
        continue;
      }
      if (cmd === 'text' || cmd === 'mathrm' || cmd === 'mbox' || cmd === 'operatorname') {
        const [body, i1] = latexGroup(src, i);
        out += body;
        i = i1;
        continue;
      }
      if (cmd === 'left' || cmd === 'right') continue; // auto-size delimiters
      if (cmd === ' ' || cmd === 'quad' || cmd === 'qquad') { out += ' '; continue; }
      if (GREEK[cmd]) { out += GREEK[cmd]; continue; }
      if (SYMBOLS[cmd]) { out += SYMBOLS[cmd]; continue; }
      out += cmd; // unknown macro: keep the word
      continue;
    }
    if (c === '^' || c === '_') {
      const [body, i1] = latexGroup(src, i + 1);
      const content = latexToText(body);
      const ch = c === '^' ? '\u005e' : '\u203e';
      void ch;
      const sub = c === '_';
      const map: Record<string, string> = sub
        ? { '0': '\u2080', '1': '\u2081', '2': '\u2082', '3': '\u2083', '4': '\u2084', '5': '\u2085', '6': '\u2086', '7': '\u2087', '8': '\u2088', '9': '\u2089', '+': '\u208a', '-': '\u208b', '=': '\u208c', '(': '\u208d', ')': '\u208e', 'n': '\u2099', 'm': '\u2098', 'x': '\u2093', 'e': '\u2091', 'o': '\u2092', 'a': '\u2090', 'i': '\u1d62', 'r': '\u1d63', 'u': '\u1d64', 'v': '\u1d65' }
        : { '0': '\u2070', '1': '\u00b9', '2': '\u00b2', '3': '\u00b3', '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077', '8': '\u2078', '9': '\u2079', '+': '\u207a', '-': '\u207b', '=': '\u207c', '(': '\u207d', ')': '\u207e', 'n': '\u207f', 'i': '\u2071' };
      if ([...content].every((ch) => map[ch] !== undefined) && content.length > 0) {
        out += [...content].map((ch) => map[ch]).join('');
      } else if (content.length === 1) {
        out += content; // single non-mappable char: keep inline
      } else {
        out += sub ? `_[${content}]` : `^[${content}]`;
      }
      i = i1;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

/** Convert \( … \) and $$ … $$ spans in a text run into LaTeX-converted text. */
function convertMath(text: string): string {
  return text
    .replace(/\\\(([^]*?)\\\)/g, (_, body: string) => latexToText(body))
    .replace(/\$\$?([^]*?)\$\$?/g, (_, body: string) => latexToText(body))
    .replace(/\\\[((?:.|\n)+?)\\\]/g, (_, body: string) => latexToText(body));
}

/* ------------------------------------------------------------------ */
/* safe HTML                                                           */
/* ------------------------------------------------------------------ */

interface Tok {
  kind: 'text' | 'open' | 'close';
  tag: string;
  attrs?: Record<string, string>;
}

function tokenize(html: string): Tok[] {
  const toks: Tok[] = [];
  const re = /<\/?([a-zA-Z][a-zA-Z0-9]*)((?:\s+[a-zA-Z-]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*\/?>|([^<]+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) {
    if (m[3] !== undefined) {
      toks.push({ kind: 'text', tag: '', attrs: undefined });
      (toks[toks.length - 1] as unknown as { text: string }).text = m[3];
      continue;
    }
    const tag = m[1].toLowerCase();
    const closing = m[0][1] === '/';
    const attrs: Record<string, string> = {};
    if (m[2]) {
      const are = /([a-zA-Z-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
      let am: RegExpExecArray | null;
      while ((am = are.exec(m[2])) !== null) {
        attrs[am[1].toLowerCase()] = am[2] ?? am[3] ?? am[4] ?? '';
      }
    }
    toks.push({ kind: closing ? 'close' : 'open', tag, attrs });
  }
  return toks;
}

const VOID_TAGS = new Set(['br', 'img', 'hr', 'input', 'meta', 'link']);
const DROP_TAGS = new Set(['script', 'style', 'iframe', 'object', 'embed', 'form', 'head', 'title', 'svg', 'video', 'audio', 'source']);
const KEEP_TAGS = new Set([
  'p', 'br', 'b', 'strong', 'i', 'em', 'u', 'ins', 's', 'del', 'sub', 'sup',
  'span', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th',
  'ul', 'ol', 'li', 'blockquote', 'pre', 'code', 'figure', 'figcaption', 'a', 'img', 'hr', 'font', 'center',
]);

interface Ctx {
  nodes: ReactNode[];
  key: number;
}

function pushText(ctx: Ctx, raw: string) {
  const text = convertMath(decodeEntities(raw));
  if (!text) return;
  ctx.nodes.push(text);
}

function styleFor(tag: string): CSSProperties | undefined {
  switch (tag) {
    case 'h1': return { fontSize: '1.25em', fontWeight: 700, margin: '0.4em 0' };
    case 'h2': return { fontSize: '1.15em', fontWeight: 700, margin: '0.4em 0' };
    case 'h3': case 'h4': case 'h5': case 'h6':
      return { fontSize: '1.05em', fontWeight: 600, margin: '0.35em 0' };
    case 'p': case 'div': case 'center': case 'figure': case 'figcaption':
      return { margin: '0.35em 0', textAlign: tag === 'center' ? 'center' : undefined };
    case 'blockquote':
      return { borderLeft: '3px solid currentColor', opacity: 0.85, paddingLeft: '0.7em', margin: '0.4em 0' };
    case 'pre':
      return { fontFamily: 'ui-monospace, monospace', whiteSpace: 'pre-wrap', background: 'rgba(0,0,0,0.04)', borderRadius: 6, padding: '0.5em 0.7em', margin: '0.4em 0' };
    case 'table':
      return { borderCollapse: 'collapse', margin: '0.5em 0', width: 'auto', maxWidth: '100%', display: 'block', overflowX: 'auto' };
    case 'td': case 'th':
      return { border: '1px solid rgba(127,127,127,0.45)', padding: '2px 8px', minWidth: '1.5em' };
    case 'th':
      return { fontWeight: 700, textAlign: 'center' };
    case 'li':
      return { marginLeft: '1.2em', display: 'list-item' };
    case 'ul': return { listStyle: 'disc', paddingLeft: '0.5em', margin: '0.35em 0' };
    case 'ol': return { listStyle: 'decimal', paddingLeft: '0.5em', margin: '0.35em 0' };
    case 'ins': return { textDecoration: 'underline' };
    default: return undefined;
  }
}

function renderAttrs(tag: string, attrs: Record<string, string> | undefined, key: number): { extra: Record<string, unknown> | null; img?: { src: string; alt: string } } {
  if (tag === 'img' && attrs) {
    let src = attrs.src ?? '';
    // allow only embedded question images or the myschool archive origin
    if (/^\/qimages\//.test(src)) src = apiImg(src);
    else if (/^https:\/\/myschool\.ng\//i.test(src)) src = src;
    else src = '';
    return { extra: null, img: { src, alt: attrs.alt ? decodeEntities(attrs.alt) : 'question diagram' } };
  }
  if (tag === 'a' && attrs) {
    const href = attrs.href ?? '';
    if (/^https?:\/\//i.test(href)) {
      return { extra: { href, target: '_blank', rel: 'noreferrer noopener' }, img: undefined };
    }
  }
  return { extra: null, img: undefined };
}

function renderNode(tok: Tok, rest: Tok[], ctx: Ctx): number {
  const tag = tok.tag;
  const key = ctx.key++;
  const { extra, img } = renderAttrs(tag, tok.attrs, key);

  if (tag === 'br') { ctx.nodes.push(<br key={key} />); return 0; }
  if (tag === 'hr') { ctx.nodes.push(<hr key={key} className="my-2 border-outline-variant/60" />); return 0; }
  if (tag === 'img') {
    if (img && img.src) {
      ctx.nodes.push(
        <span key={key} className="my-2 block text-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={img.src} alt={img.alt} loading="lazy" className="mx-auto max-h-72 max-w-full rounded-lg border border-outline-variant/40 bg-card object-contain" />
        </span>,
      );
    }
    return 0;
  }

  // gather children until the matching close tag
  let i = 0;
  const childCtx: Ctx = { nodes: [], key: ctx.key };
  for (; i < rest.length; i++) {
    const t = rest[i];
    if (t.kind === 'close' && t.tag === tag) { i++; break; }
    if (t.kind === 'text') {
      pushText(childCtx, (t as unknown as { text: string }).text);
      continue;
    }
    if (t.kind === 'open') {
      if (VOID_TAGS.has(t.tag)) {
        const consumed = renderNode(t, [], childCtx);
        void consumed;
        continue;
      }
      if (DROP_TAGS.has(t.tag)) {
        // skip the element and its content entirely
        let depth = 1;
        i++;
        for (; i < rest.length && depth > 0; i++) {
          const d = rest[i];
          if (d.kind === 'open' && d.tag === t.tag) depth++;
          else if (d.kind === 'close' && d.tag === t.tag) depth--;
        }
        i--;
        continue;
      }
      if (!KEEP_TAGS.has(t.tag)) {
        // unknown tag: unwrap (render children only)
        i += renderNode({ ...t, tag: 'span-unwrap' }, rest.slice(i + 1), childCtx) + 1;
        continue;
      }
      i += renderNode(t, rest.slice(i + 1), childCtx) + 1;
      continue;
    }
  }
  ctx.key = childCtx.key;

  const children = childCtx.nodes;
  if (tag === 'span-unwrap') {
    ctx.nodes.push(...children);
    return i - 1 < 0 ? 0 : i - 1;
  }
  const style = styleFor(tag);
  const common = { style, ...extra } as Record<string, unknown>;
  delete common.key;
  switch (tag) {
    case 'b': case 'strong': ctx.nodes.push(<strong key={key} {...common} className="font-semibold">{children}</strong>); break;
    case 'i': case 'em': ctx.nodes.push(<em key={key} {...common}>{children}</em>); break;
    case 'u': case 'ins': ctx.nodes.push(<u key={key} {...common}>{children}</u>); break;
    case 's': case 'del': ctx.nodes.push(<s key={key} {...common}>{children}</s>); break;
    case 'sub': ctx.nodes.push(<sub key={key} {...common}>{children}</sub>); break;
    case 'sup': ctx.nodes.push(<sup key={key} {...common}>{children}</sup>); break;
    case 'code': ctx.nodes.push(<code key={key} {...common} className="rounded bg-surface-container-low px-1 py-0.5 font-mono text-[0.9em]">{children}</code>); break;
    case 'td': ctx.nodes.push(<td key={key} {...common} colSpan={tok.attrs?.colSpan ? Number(tok.attrs.colSpan) : tok.attrs?.colspan ? Number(tok.attrs.colspan) : undefined}>{children}</td>); break;
    case 'th': ctx.nodes.push(<th key={key} {...common} colSpan={tok.attrs?.colSpan ? Number(tok.attrs.colSpan) : tok.attrs?.colspan ? Number(tok.attrs.colspan) : undefined}>{children}</th>); break;
    case 'tr': ctx.nodes.push(<tr key={key} {...common}>{children}</tr>); break;
    case 'table': ctx.nodes.push(<table key={key} {...common}><tbody>{children}</tbody></table>); break;
    case 'thead': case 'tbody': case 'tfoot': ctx.nodes.push(<tbody key={key} {...common}>{children}</tbody>); break;
    case 'ul': ctx.nodes.push(<ul key={key} {...common}>{children}</ul>); break;
    case 'ol': ctx.nodes.push(<ol key={key} {...common}>{children}</ol>); break;
    case 'li': ctx.nodes.push(<li key={key} {...common}>{children}</li>); break;
    case 'a': ctx.nodes.push(<a key={key} {...common} className="text-primary underline underline-offset-2">{children}</a>); break;
    case 'font': case 'span': ctx.nodes.push(<span key={key} {...common}>{children}</span>); break;
    default: ctx.nodes.push(<div key={key} {...common}>{children}</div>);
  }
  return i - 1 < 0 ? 0 : i - 1;
}

/** Render a question stem / option / explanation into React nodes. */
export function renderQText(html: string): ReactNode[] {
  if (!html) return [];
  const ctx: Ctx = { nodes: [], key: 0 };
  // HTML5 tokenizer rule: a '<' that is not followed by a letter, '/'
  // or '!' is literal text (keep maths inequalities like "2x < 5").
  const toks = tokenize(html.replace(/<(?![a-zA-Z/!])/g, '&lt;'));
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (t.kind === 'text') {
      pushText(ctx, (t as unknown as { text: string }).text);
      continue;
    }
    if (t.kind === 'open') {
      if (VOID_TAGS.has(t.tag) || t.tag === 'img') {
        renderNode(t, [], ctx);
        continue;
      }
      if (DROP_TAGS.has(t.tag)) {
        let depth = 1;
        i++;
        for (; i < toks.length && depth > 0; i++) {
          const d = toks[i];
          if (d.kind === 'open' && d.tag === t.tag) depth++;
          else if (d.kind === 'close' && d.tag === t.tag) depth--;
        }
        i--;
        continue;
      }
      if (!KEEP_TAGS.has(t.tag)) {
        i += renderNode({ ...t, tag: 'span-unwrap' }, toks.slice(i + 1), ctx) + 1;
        continue;
      }
      i += renderNode(t, toks.slice(i + 1), ctx) + 1;
      continue;
    }
  }
  return ctx.nodes;
}

/** Block renderer: question text (stem, options, explanations, passages).
 *  Plain-text content keeps its author line breaks (whitespace-pre-line);
 *  HTML content manages its own breaks through tags. */
export function QText({ html, className }: { html: string; className?: string }) {
  const wrap = /<[a-zA-Z/]/.test(html) ? '' : ' whitespace-pre-line';
  return <div className={`${className ?? ''}${wrap}`}>{renderQText(html)}</div>;
}

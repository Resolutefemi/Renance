'use client';

/**
 * The on-screen calculator every JAMB CBT hall puts next to the clock:
 * a basic arithmetic machine with one memory register — digits, the
 * four operations, percent, square root, sign flip, and the MRC / M+ /
 * M- row. Immediate-execution semantics (like the real device), never
 * eval: the chain is a tiny accumulator state machine.
 */

import { useCallback, useEffect, useRef, useState } from 'react';

type Op = '+' | '-' | '×' | '÷' | null;

/** Round away float dust (0.1+0.2 -> 0.3) without a dependency. */
function tidy(n: number): number {
  if (!Number.isFinite(n)) return n;
  return Number(n.toPrecision(12));
}

function format(n: number): string {
  if (!Number.isFinite(n)) return 'Error';
  if (n !== 0 && Math.abs(n) < 1e-9) return n.toExponential(4);
  if (Math.abs(n) >= 1e12) return n.toExponential(6);
  const s = tidy(n).toString();
  return s.length > 14 ? tidy(n).toPrecision(10) : s;
}

export default function CalculatorSheet({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const [display, setDisplay] = useState('0');
  const [mem, setMem] = useState(0);
  const accRef = useRef<number | null>(null); // accumulator (lhs)
  const opRef = useRef<Op>(null); // pending operation
  const freshRef = useRef(true); // next digit starts a new entry
  const lastOpRef = useRef<Op>(null); // for repeated "="
  const lastArgRef = useRef<number | null>(null);

  const current = useCallback((): number => {
    const n = Number(display.replace(/,/g, ''));
    return Number.isFinite(n) ? n : 0;
  }, [display]);

  const show = useCallback((n: number) => {
    setDisplay(format(n));
    freshRef.current = false;
  }, []);

  const digit = useCallback(
    (d: string) => {
      if (freshRef.current || display === '0') {
        if (display === '0' && d === '.' && !freshRef.current) return;
        setDisplay(d === '.' ? '0.' : d);
        freshRef.current = false;
        return;
      }
      if (d === '.' && display.includes('.')) return;
      if (display.replace(/[-.]/g, '').length >= 12) return;
      setDisplay(display + d);
    },
    [display],
  );

  const apply = useCallback((a: number, b: number, op: Op): number => {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b === 0 ? NaN : a / b;
      default: return b;
    }
  }, []);

  const setOp = useCallback(
    (op: Op) => {
      const v = current();
      if (accRef.current != null && opRef.current && !freshRef.current) {
        const r = apply(accRef.current, v, opRef.current);
        accRef.current = r;
        show(r);
      } else {
        accRef.current = v;
      }
      opRef.current = op;
      freshRef.current = true;
    },
    [apply, current, show],
  );

  const equals = useCallback(() => {
    const v = current();
    let op = opRef.current;
    if (op) {
      const r = apply(accRef.current ?? 0, v, op);
      lastOpRef.current = op;
      lastArgRef.current = v;
      accRef.current = null;
      opRef.current = null;
      freshRef.current = true;
      show(r);
      return;
    }
    if (lastOpRef.current && lastArgRef.current != null) {
      // repeated = keeps applying the last operation (device behavior)
      const r = apply(v, lastArgRef.current, lastOpRef.current);
      freshRef.current = true;
      show(r);
      return;
    }
    freshRef.current = true;
  }, [apply, current, show]);

  const clearAll = useCallback(() => {
    accRef.current = null;
    opRef.current = null;
    lastOpRef.current = null;
    lastArgRef.current = null;
    freshRef.current = true;
    setDisplay('0');
  }, []);

  const press = useCallback(
    (key: string) => {
      switch (key) {
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9': case '.':
          digit(key); break;
        case '+': case '-': case '×': case '÷':
          setOp(key as Op); break;
        case '=': equals(); break;
        case 'AC': clearAll(); break;
        case 'back':
          if (!freshRef.current) {
            const next = display.length <= 1 || (display.length === 2 && display.startsWith('-'))
              ? '0'
              : display.slice(0, -1);
            setDisplay(next);
          }
          break;
        case '±': show(-current()); break;
        case '%': show(current() / 100); break;
        case '√': {
          const v = current();
          show(v < 0 ? NaN : Math.sqrt(v));
          break;
        }
        case 'M+': setMem((m) => m + current()); freshRef.current = true; break;
        case 'M-': setMem((m) => m - current()); freshRef.current = true; break;
        case 'MRC': show(mem); break;
      }
    },
    [clearAll, current, digit, display, equals, mem, setOp, show],
  );

  // Keyboard support while the sheet is open — the PC candidate keeps
  // typing numbers the way the real hall allows.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      const k = e.key;
      if (/^[0-9.]$/.test(k)) press(k);
      else if (k === '+') press('+');
      else if (k === '-') press('-');
      else if (k === '*') press('×');
      else if (k === '/') { e.preventDefault(); press('÷'); }
      else if (k === 'Enter' || k === '=') press('=');
      else if (k === 'Backspace') press('back');
      else if (k === 'Escape') { press('AC'); onClose(); }
      else if (k === '%') press('%');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, press, onClose]);

  if (!open) return null;

  const KEY_ROWS: Array<Array<{ k: string; cls?: string }>> = [
    [{ k: 'MRC' }, { k: 'M+' }, { k: 'M-' }, { k: 'AC', cls: 'text-error' }],
    [{ k: '√' }, { k: '%' }, { k: '±' }, { k: '÷', cls: 'bg-primary/10 font-semibold' }],
    [{ k: '7' }, { k: '8' }, { k: '9' }, { k: '×', cls: 'bg-primary/10 font-semibold' }],
    [{ k: '4' }, { k: '5' }, { k: '6' }, { k: '-', cls: 'bg-primary/10 font-semibold' }],
    [{ k: '1' }, { k: '2' }, { k: '3' }, { k: '+', cls: 'bg-primary/10 font-semibold' }],
    [{ k: 'back', cls: 'material' }, { k: '0' }, { k: '.' }, { k: '=', cls: 'bg-primary text-on-primary font-semibold' }],
  ];

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center sm:items-center" role="presentation">
      <button
        aria-label="Close calculator"
        onClick={onClose}
        className="absolute inset-0 bg-accent-ink/40 backdrop-blur-[2px]"
      />
      <div
        role="dialog"
        aria-label="Calculator"
        className="renance-rise relative w-full max-w-[320px] rounded-t-3xl bg-surface-container-lowest p-4 shadow-2xl sm:rounded-3xl"
      >
        <div className="mx-auto mb-3 h-1.5 w-12 rounded-full bg-outline-variant sm:hidden" />
        <div className="flex items-center justify-between">
          <span className="flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-wider text-on-surface-variant">
            <span className="material-symbols-outlined text-[14px]">calculate</span>
            Calculator
            {mem !== 0 && <span className="ml-1 rounded bg-accent-amber/20 px-1 text-[10px] text-on-surface">M</span>}
          </span>
          <button
            onClick={onClose}
            aria-label="Close"
            className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-container text-on-surface"
          >
            <span className="material-symbols-outlined text-[18px]">close</span>
          </button>
        </div>

        {/* display */}
        <div className="mt-3 overflow-x-auto rounded-xl bg-accent-ink px-4 py-3 text-right shadow-inner">
          <p className="font-mono text-[26px] font-semibold leading-8 text-white">{display}</p>
          {opRef.current && <p className="font-mono text-[11px] text-white/50">pending {opRef.current}</p>}
        </div>

        {/* keypad */}
        <div className="mt-3 grid grid-cols-4 gap-2 pb-2">
          {KEY_ROWS.flat().map(({ k, cls }) => (
            <button
              key={k}
              type="button"
              onClick={() => press(k)}
              className={`flex h-12 items-center justify-center rounded-xl text-[17px] transition active:scale-95 ${
                cls && cls.includes('material')
                  ? 'bg-surface-container text-on-surface-variant'
                  : cls ?? 'bg-card text-on-surface shadow-[0_1px_2px_0_rgba(20,28,45,0.10)]'
              }`}
            >
              {cls && cls.includes('material') ? (
                <span className="material-symbols-outlined text-[18px]">backspace</span>
              ) : (
                k
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

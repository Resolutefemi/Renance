'use client';

/**
 * Flashcards (ROADMAP #7): the Stitch voice_flashcards_light on the web.
 * Deck list → the player: white card stage, front in display type, answer
 * in emerald on reveal, the violet play pill with waveform bars, and
 * Reveal → Again / Hard / Good. The browser's speech synthesis reads the
 * visible side; progress rides the same Leitner state as the app.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import {
  cardIntervalDays,
  fetchCardProgress,
  fetchDeck,
  fetchDecks,
  nextCardBox,
  postCardGrades,
  type CardProgress,
  type FlashcardCard,
  type FlashcardDeck,
  type FlashcardDeckMeta,
  type FlashcardGrade,
} from '@/lib/flashcards';
import { speak, speechSupported, stopSpeaking } from '@/lib/speech';
import { LogoActivityIndicator } from '@/components/renance-logo';

type Phase = 'loading' | 'ready' | 'error';

export default function FlashcardsPage() {
  const [phase, setPhase] = useState<Phase>('loading');
  const [error, setError] = useState<string | null>(null);
  const [decks, setDecks] = useState<FlashcardDeckMeta[]>([]);
  const [deck, setDeck] = useState<FlashcardDeck | null>(null);

  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [voiceOn, setVoiceOn] = useState(true);
  const [progress, setProgress] = useState<Record<string, CardProgress>>({});
  const voiceRef = useRef(true);

  const card: FlashcardCard | undefined = deck?.cards[index];
  const done = deck !== null && index >= deck.cards.length;

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const list = await fetchDecks();
        if (!alive) return;
        setDecks(list);
        setPhase('ready');
      } catch (err) {
        if (!alive) return;
        setError(err instanceof Error ? err.message : 'Could not load decks');
        setPhase('error');
      }
      try {
        const rows = await fetchCardProgress();
        if (!alive) return;
        setProgress(Object.fromEntries(rows.map((r) => [r.cardId, r])));
      } catch {
        // progress is decorative here, the deck still works
      }
    })();
    return () => {
      alive = false;
      stopSpeaking();
    };
  }, []);

  const openDeck = useCallback(async (code: string) => {
    setPhase('loading');
    setError(null);
    try {
      const d = await fetchDeck(code);
      setDeck(d);
      setIndex(0);
      setRevealed(false);
      setPhase('ready');
      if (voiceRef.current) speak(d.cards[0]?.front ?? '');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not open deck');
      setPhase('error');
    }
  }, []);

  const flip = useCallback(() => {
    setRevealed((r) => {
      const next = !r;
      if (next && voiceRef.current) speak(card?.back ?? '');
      return next;
    });
  }, [card]);

  const readVisibleSide = useCallback(() => {
    if (!voiceRef.current) return;
    speak(revealed ? (card?.back ?? '') : (card?.front ?? ''));
  }, [revealed, card]);

  const advance = useCallback(() => {
    const nextIdx = deck && index < deck.cards.length ? index + 1 : index;
    setIndex(nextIdx);
    setRevealed(false);
    if (voiceRef.current) speak(deck?.cards[nextIdx]?.front ?? '');
  }, [deck, index]);

  const grade = useCallback(
    async (g: FlashcardGrade['grade']) => {
      if (!card || !deck) return;
      const cardId = card.id;
      const deckCode = deck.code;
      const prev = progress[cardId];
      const newBox = nextCardBox(prev?.box ?? 1, g);
      const due = new Date();
      due.setUTCDate(due.getUTCDate() + cardIntervalDays(newBox));
      const dueOn = due.toISOString().slice(0, 10);
      setProgress((p) => ({
        ...p,
        [cardId]: {
          cardId,
          deckCode,
          box: newBox,
          correct: (prev?.correct ?? 0) + (g === 'again' ? 0 : 1),
          wrong: (prev?.wrong ?? 0) + (g === 'again' ? 1 : 0),
          dueOn,
          lastGrade: g,
        },
      }));
      advance();
      try {
        const rows = await postCardGrades([{ cardId, deckCode, grade: g }]);
        setProgress((p) => {
          const next = { ...p };
          for (const r of rows) next[r.cardId] = r;
          return next;
        });
      } catch {
        // Offline or rejected, the optimistic state stands; a reload
        // re-syncs from the server like every other surface.
      }
    },
    [card, deck, progress, advance],
  );

  const toggleVoice = useCallback(() => {
    setVoiceOn((v) => {
      voiceRef.current = !v;
      if (v) stopSpeaking();
      return !v;
    });
  }, []);

  /* ----------------------------------------------------------- deck list */

  if (!deck) {
    return (
      <main className="mx-auto w-full max-w-2xl px-4 pb-16 pt-8 sm:px-6 lg:max-w-5xl">
        <header className="flex items-center justify-between">
          <h1 className="text-xl font-semibold tracking-tight text-on-surface">Flashcards</h1>
          {speechSupported() && (
            <span className="flex items-center gap-1.5 rounded-full bg-surface-container-low px-3 py-1 text-xs text-on-surface-variant">
              <span className="material-symbols-outlined text-[16px] text-accent-violet">headphones</span>
              voice ready
            </span>
          )}
        </header>

        {phase === 'loading' && (
          <div className="mt-16 flex justify-center">
            <LogoActivityIndicator state="busy" label="Shuffling decks…" />
          </div>
        )}
        {phase === 'error' && (
          <p className="mt-10 rounded-xl bg-error-container px-6 py-5 text-center text-sm text-on-error-container">
            {error}
          </p>
        )}
        {phase === 'ready' && decks.length === 0 && (
          <p className="mt-10 rounded-xl bg-card p-6 text-center text-sm text-on-surface-variant shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            No decks yet, they ship with your packs.
          </p>
        )}
        {phase === 'ready' && decks.length > 0 && (
          <div className="mt-6 grid grid-cols-1 gap-2.5 sm:grid-cols-2 lg:grid-cols-3">
            {decks.map((d) => (
              <button
                key={d.code}
                onClick={() => void openDeck(d.code)}
                className="flex w-full items-center gap-4 rounded-xl bg-card p-4 text-left shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition hover:shadow-md"
              >
                <span className="flex h-11 w-11 items-center justify-center rounded-[10px] bg-surface-container-low">
                  <span className="material-symbols-outlined text-[22px] text-accent-violet">headphones</span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[15px] font-semibold text-on-surface">{d.title}</span>
                  <span className="block text-xs text-on-surface-variant">
                    {d.cardCount} cards{d.subject ? ` · ${d.subject}` : ''}
                  </span>
                </span>
                <span className="material-symbols-outlined text-outline-light">chevron_right</span>
              </button>
            ))}
          </div>
        )}
        <Link
          href="/dashboard"
          className="mt-6 block text-center text-sm text-on-surface-variant hover:text-on-surface"
        >
          ← back to dashboard
        </Link>
      </main>
    );
  }

  /* -------------------------------------------------------------- player */

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl flex-col px-4 pb-8 sm:px-6">
      <header className="flex items-center justify-between py-4">
        <button
          onClick={() => {
            stopSpeaking();
            setDeck(null);
            setRevealed(false);
          }}
          className="flex items-center gap-2 text-sm text-on-surface-variant transition hover:text-on-surface"
        >
          <span className="material-symbols-outlined text-[20px]">headphones</span>
          <span className="max-w-[180px] truncate">{deck.title}</span>
        </button>
        <div className="flex items-center gap-2">
          <button
            onClick={toggleVoice}
            aria-label={voiceOn ? 'Mute voice' : 'Unmute voice'}
            className="flex h-9 w-9 items-center justify-center rounded-full hover:bg-surface-container"
          >
            <span
              className={`material-symbols-outlined text-[22px] ${voiceOn ? 'text-accent-violet' : 'text-outline-dark'}`}
            >
              {voiceOn ? 'volume_up' : 'volume_off'}
            </span>
          </button>
          <span className="font-mono text-lg font-bold tracking-tight text-on-surface">
            {Math.min(index + 1, deck.cardCount)}
            <span className="text-sm text-on-surface-variant">/{deck.cardCount}</span>
          </span>
        </div>
      </header>

      <div className="h-1 overflow-hidden rounded-full bg-surface-container">
        <div
          className="h-full rounded-full bg-accent-violet transition-all"
          style={{ width: `${(index / Math.max(deck.cardCount, 1)) * 100}%` }}
        />
      </div>

      {done || !card ? (
        <div className="flex flex-1 flex-col items-center justify-center py-16 text-center">
          <span className="material-symbols-outlined text-[48px] text-accent-emerald">task_alt</span>
          <h2 className="mt-4 text-2xl font-bold tracking-tight text-on-surface">Deck complete</h2>
          <p className="mt-2 text-sm text-on-surface-variant">
            You ran {deck.cardCount} cards ·{' '}
            {
              Object.values(progress).filter((p) => p.deckCode === deck.code && p.box >= 3)
                .length
            }{' '}
            known (box 3+). They will resurface on their Leitner schedule.
          </p>
          <div className="mt-6 flex w-full max-w-[220px] flex-col gap-2">
            <button
              onClick={() => {
                setIndex(0);
                setRevealed(false);
                if (voiceRef.current) speak(deck.cards[0]?.front ?? '');
              }}
              className="h-[52px] rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition-all active:scale-[0.98]"
            >
              Run it again
            </button>
            <Link
              href="/dashboard"
              className="py-2 text-center text-sm text-on-surface-variant hover:text-on-surface"
            >
              Back to dashboard
            </Link>
          </div>
        </div>
      ) : (
        <>
          <button
            onClick={flip}
            className="mt-4 flex flex-1 flex-col items-center justify-center rounded-xl bg-card p-6 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)] transition active:scale-[0.995]"
          >
            {revealed ? (
              <div className="flex flex-col items-center gap-4">
                <p className="text-[26px] font-bold leading-snug tracking-tight text-accent-emerald">
                  {card.back}
                </p>
                {progress[card.id] && (
                  <span className="font-mono text-xs text-on-surface-variant">
                    Box {progress[card.id].box}
                  </span>
                )}
              </div>
            ) : (
              <p className="text-[26px] font-bold leading-snug tracking-tight text-on-surface">
                {card.front}
              </p>
            )}
            <span
              onClick={(e) => {
                e.stopPropagation();
                readVisibleSide();
              }}
              className="mt-6 flex items-center gap-3 rounded-full bg-surface-container-low py-1.5 pl-1.5 pr-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.05)]"
              role="button"
              aria-label="Read aloud"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-accent-violet text-white shadow-[0_1px_3px_0_rgba(20,28,45,0.12)]">
                <span className="material-symbols-outlined fill-current text-[22px]">play_arrow</span>
              </span>
              <span className="flex h-6 items-end gap-[3px]">
                {[24, 18, 12, 24, 16].map((h, i) => (
                  <span
                    key={i}
                    className="w-1.5 origin-bottom animate-[renance-wave_1s_ease-in-out_infinite] rounded-full bg-selection-blue"
                    style={{ height: h, animationDelay: `${i * 0.12}s` }}
                  />
                ))}
              </span>
            </span>
          </button>

          <div className="mt-4 flex gap-2">
            {revealed ? (
              <>
                <button
                  onClick={() => void grade('again')}
                  className="h-[52px] flex-1 rounded-[10px] bg-error-container text-sm font-semibold text-on-error-container transition active:scale-[0.98]"
                >
                  Again
                </button>
                <button
                  onClick={() => void grade('hard')}
                  className="h-[52px] flex-1 rounded-[10px] bg-secondary-container text-sm font-semibold text-on-surface transition active:scale-[0.98]"
                >
                  Hard
                </button>
                <button
                  onClick={() => void grade('good')}
                  className="h-[52px] flex-1 rounded-[10px] bg-surface-container-high text-sm font-semibold text-on-surface transition active:scale-[0.98]"
                >
                  Good
                </button>
              </>
            ) : (
              <button
                onClick={flip}
                className="h-[52px] w-full rounded-[10px] bg-primary text-sm font-semibold text-on-primary transition active:scale-[0.98]"
              >
                Reveal
              </button>
            )}
          </div>
        </>
      )}
    </main>
  );
}

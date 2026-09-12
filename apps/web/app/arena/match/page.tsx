'use client';

/**
 * Arena live match — now wired to the REAL multiplayer hub
 * (apps/study-api/internal/arena) over one authenticated WebSocket:
 * queue with the student's exam body → matched (or the hub's bot after
 * the wait window) → server-pushed questions with answer deadlines →
 * result/over frames with the live score. QViews carry no answer key —
 * the correct letter only ever arrives in the result frame.
 *
 * The Stitch look stays: dark LIVE card, ink chips for you, gray for
 * the opponent, "answered in" caption, answer-locks-in bottom rail.
 */

import { useEffect, useMemo, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { RenanceMark } from '@/components/renance-logo';
import { QText } from '@/lib/qtext';
import { api } from '@/lib/api';
import { ArenaSocket, type ArenaInbound } from '@/lib/arena';

type Phase = 'connecting' | 'queued' | 'dueling' | 'over' | 'down';

interface MeResponse {
  profile: { exams: string[] } | null;
}

function focusBody(exams?: string[]): string {
  const exam = exams?.[0] ?? 'JAMB';
  if (/waec/i.test(exam)) return 'WAEC';
  if (/neco/i.test(exam)) return 'NECO';
  if (/university/i.test(exam)) return 'University Modules';
  return 'JAMB';
}

const mmss = (s: number) => `0:${String(Math.max(0, s)).padStart(2, '0')}`;

export default function ArenaMatchPage() {
  const router = useRouter();
  const [phase, setPhase] = useState<Phase>('connecting');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [body, setBody] = useState('JAMB');

  const [opponent, setOpponent] = useState('Renance Bot');
  const [packCode, setPackCode] = useState('');
  const [questionCount, setQuestionCount] = useState(5);
  const [secondsPerQuestion, setSecondsPerQuestion] = useState(15);

  const [q, setQ] = useState<ArenaInbound & { type: 'question' } | null>(null);
  const [picked, setPicked] = useState<string | null>(null);
  const [answeredIn, setAnsweredIn] = useState<number | null>(null);
  const [lastCorrect, setLastCorrect] = useState<string | null>(null);
  const [you, setYou] = useState(0);
  const [rival, setRival] = useState(0);
  const [winner, setWinner] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  const sockRef = useRef<ArenaSocket | null>(null);
  const askedAt = useRef<number>(0);
  const myIdRef = useRef<string>('');

  // 1s heartbeat for the round clock.
  useEffect(() => {
    if (phase !== 'dueling') return;
    const t = setInterval(() => setTick((n) => n + 1), 1000);
    return () => clearInterval(t);
  }, [phase]);
  // tick drives the countdown re-render; referenced to keep the linter honest.
  void tick;

  useEffect(() => {
    let alive = true;
    let sock: ArenaSocket | null = null;

    (async () => {
      // The arena buckets matchmaking by exam body; the student's focus
      // picks the shelf so a JAMBite never meets a GST 111 bank. /me
      // resolves FIRST so the single queue frame carries the right body
      // and the student's id (for result-frame score attribution).
      let body = 'JAMB';
      try {
        const me = await api<MeResponse & { user: { id: string } }>('/me');
        if (!alive) return;
        body = focusBody(me.profile?.exams);
        myIdRef.current = me.user?.id ?? '';
      } catch {
        /* api() redirects on 401; the default shelf still queues */
      }
      if (!alive) return;
      setBody(body);

      sock = new ArenaSocket({
        onOpen: () => {
          if (!alive) return;
          setPhase((p) => (p === 'connecting' ? 'queued' : p));
          sock!.send({ type: 'queue', body });
        },
        onFrame: (frame) => {
          if (alive) handleFrame(frame);
        },
        onDown: () => {
          if (!alive) return;
          setPhase((p) => (p === 'over' ? p : 'down'));
        },
      });
      sockRef.current = sock;
    })();

    return () => {
      alive = false;
      sock?.send({ type: 'cancel' });
      sock?.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function handleFrame(frame: ArenaInbound) {
    switch (frame.type) {
      case 'queued':
        setPhase('queued');
        break;
      case 'matched':
        setOpponent(frame.opponent || 'Renance Bot');
        setPackCode(frame.code || '');
        setQuestionCount(frame.questionCount ?? 5);
        setSecondsPerQuestion(frame.secondsPerQuestion ?? 15);
        setYou(0);
        setRival(0);
        setWinner(null);
        setPhase('dueling');
        break;
      case 'question':
        askedAt.current = Date.now();
        setPicked(null);
        setAnsweredIn(null);
        setLastCorrect(null);
        setQ(frame);
        setPhase('dueling');
        break;
      case 'result': {
        setLastCorrect(frame.correctLetter);
        // Live scoreline: the hub attributes solves by userID.
        const solved = frame.solved ?? {};
        const meId = myIdRef.current;
        if (meId && solved[meId]) setYou((n) => n + 1);
        else if (Object.entries(solved).some(([id, ok]) => ok && id !== meId)) {
          setRival((n) => n + 1);
        }
        break;
      }
      case 'over': {
        // The over frame carries the authoritative final scores keyed by
        // userID; adopt them wholesale (covers late/aborted questions too).
        const scores = frame.scores ?? {};
        const meId = myIdRef.current;
        const other = Object.entries(scores).find(([id]) => id !== meId);
        if (meId && scores[meId] != null) setYou(scores[meId]);
        if (other) setRival(other[1]);
        setWinner(frame.winner);
        setPhase('over');
        break;
      }
      case 'error':
        // already_queued etc. are benign during re-queue; surface the rest.
        if (frame.errorCode === 'no_pack_available') {
          setErrorMsg('No live pack for your exam body yet — try another focus.');
          setPhase('down');
        } else if (frame.errorCode !== 'already_queued' && frame.errorCode !== 'in_match') {
          setErrorMsg(frame.message || 'The arena refused that move.');
        }
        break;
      default:
        break;
    }
  }

  function pick(letter: string) {
    if (!q || picked) return;
    const idx = q.index ?? 0;
    setPicked(letter);
    setAnsweredIn(Math.max(1, Math.round((Date.now() - askedAt.current) / 1000)));
    sockRef.current?.send({ type: 'answer', index: idx, letter });
  }

  function rematch() {
    setErrorMsg(null);
    setQ(null);
    setPicked(null);
    setLastCorrect(null);
    setWinner(null);
    setPhase('queued');
    sockRef.current?.send({ type: 'queue', body });
  }

  const secondsLeft = useMemo(() => {
    if (!q?.deadline) return secondsPerQuestion;
    void tick; // re-computed each second
    return Math.max(0, q.deadline - Math.floor(Date.now() / 1000));
  }, [q, tick, secondsPerQuestion]);

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-60">
      <div className="mx-auto w-full max-w-2xl px-4 pt-4 sm:px-6">
        <button
          type="button"
          onClick={() => {
            sockRef.current?.send({ type: 'cancel' });
            router.push('/arena');
          }}
          className="flex items-center gap-1 text-[14px] text-on-surface-variant transition hover:text-on-surface"
        >
          <span className="material-symbols-outlined text-[20px]">arrow_back</span>
          Arena
        </button>
      </div>

      {phase === 'connecting' && (
        <div className="flex flex-col items-center gap-3 py-24">
          <RenanceMark size={44} state="busy" />
          <p className="text-[15px] text-on-surface-variant">Connecting to the arena…</p>
        </div>
      )}

      {phase === 'down' && (
        <div className="mx-auto mt-10 w-full max-w-md px-4">
          <div className="rounded-2xl bg-card p-6 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <span className="material-symbols-outlined text-[34px] text-error">wifi_off</span>
            <h2 className="mt-2 text-lg font-semibold text-on-surface">Arena unreachable</h2>
            <p className="mt-1 text-[14px] text-on-surface-variant">
              {errorMsg ?? 'The live arena socket dropped — check your connection.'}
            </p>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="mt-5 h-12 w-full rounded-xl bg-primary text-[15px] font-semibold text-on-primary active:scale-[0.98]"
            >
              Try again
            </button>
            <button
              type="button"
              onClick={() => router.push('/arena')}
              className="mt-2 h-11 w-full rounded-xl text-[14px] font-medium text-on-surface-variant hover:bg-surface-container"
            >
              Back to lobby
            </button>
          </div>
        </div>
      )}

      {phase === 'queued' && (
        <div className="flex flex-col items-center gap-4 py-24">
          <RenanceMark size={44} state="busy" />
          <p className="text-[15px] font-semibold text-on-surface">Finding a {body} opponent…</p>
          <p className="max-w-xs text-center text-[13px] text-on-surface-variant">
            You will be matched with a live student on your exam shelf — or the Renance Bot keeps
            the queue moving.
          </p>
          <button
            type="button"
            onClick={() => {
              sockRef.current?.send({ type: 'cancel' });
              router.push('/arena');
            }}
            className="mt-2 rounded-lg px-4 py-2 text-[14px] font-medium text-on-surface-variant hover:bg-surface-container"
          >
            Cancel
          </button>
        </div>
      )}

      {(phase === 'dueling' || phase === 'over') && q && (
        <div className="mx-auto w-full max-w-2xl px-4 pt-2 sm:px-6">
          {/* LIVE strip */}
          <div className="flex items-center justify-between rounded-2xl bg-gradient-to-tl from-[#0E2230] to-[#131B2E] px-5 py-4">
            <span className="flex items-center gap-2 text-[12px] font-bold uppercase tracking-[0.2em] text-dark-text-primary">
              <span className="h-2 w-2 animate-pulse rounded-full bg-error" />
              {phase === 'over' ? 'Match over' : 'LIVE · first to answer'}
            </span>
            <span className="font-mono text-[12px] text-dark-text-primary/70">
              {packCode}
            </span>
          </div>

          {/* scoreline */}
          <div className="mt-4 flex items-center justify-between rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex items-center gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-selection-blue text-sm font-bold text-on-surface">
                YOU
              </span>
              <div>
                <p className="text-[15px] font-semibold text-on-surface">{you}</p>
                <p className="text-[11px] text-on-surface-variant">your score</p>
              </div>
            </div>
            <div className="text-center">
              <p className="font-mono text-[22px] font-bold text-on-surface">
                {mmss(q.deadline ? secondsLeft : secondsPerQuestion)}
              </p>
              <p className="text-[11px] text-on-surface-variant">
                Q{(q.index ?? 0) + 1} of {questionCount}
              </p>
            </div>
            <div className="flex items-center gap-3 text-right">
              <div>
                <p className="text-[15px] font-semibold text-on-surface">{rival}</p>
                <p className="text-[11px] text-on-surface-variant">{opponent}</p>
              </div>
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant">
                <span className="material-symbols-outlined text-[20px]">smart_toy</span>
              </span>
            </div>
          </div>

          {/* question card */}
          <div className="mt-4 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <p className="text-[11px] font-semibold uppercase tracking-wider text-on-surface-variant">
              {q.question.marks > 1 ? `${q.question.marks} marks` : 'quick fire'}
            </p>
            <div className="mt-2 text-[16px] font-medium leading-relaxed text-on-surface">
              <QText html={q.question.stem} />
            </div>
            <div className="mt-4 space-y-2.5">
              {Object.entries(q.question.options ?? {}).map(([letter, text]) => {
                const isPick = picked === letter;
                const isTrue = lastCorrect === letter;
                return (
                  <button
                    key={letter}
                    type="button"
                    disabled={phase === 'over' || picked != null}
                    onClick={() => pick(letter)}
                    className={`flex w-full items-center gap-3 rounded-xl px-4 py-3.5 text-left text-[15px] transition active:scale-[0.99] ${
                      isTrue
                        ? 'bg-accent-emerald/15 font-semibold text-on-surface ring-1 ring-accent-emerald'
                        : isPick
                          ? 'bg-selection-blue font-semibold text-on-surface ring-1 ring-primary'
                          : 'bg-surface-container-low text-on-surface hover:bg-surface-container'
                    } ${picked && !isPick && !isTrue ? 'opacity-60' : ''}`}
                  >
                    <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-card font-mono text-[12px] text-on-surface-variant">
                      {letter}
                    </span>
                    <span className="min-w-0 flex-1">
                      <QText html={text} />
                    </span>
                    {isPick && answeredIn != null && (
                      <span className="shrink-0 font-mono text-[11px] text-on-surface-variant">
                        answered in {answeredIn}s
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* answer locks in rail */}
          <div className="sticky bottom-20 mt-4 md:bottom-4">
            <div className="rounded-xl bg-surface-container-high px-4 py-3 text-center text-[13px] font-medium text-on-surface-variant">
              {phase === 'over'
                ? winner == null
                  ? 'Draw — well played on both sides.'
                  : 'Match decided — see the scoreline.'
                : picked
                  ? `Answer locked in (${answeredIn}s). Next question is loading…`
                  : 'Answer locks in when the clock hits zero.'}
            </div>
          </div>

          {phase === 'over' && (
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={rematch}
                className="flex h-[52px] flex-1 items-center justify-center gap-2 rounded-xl bg-primary text-[15px] font-semibold text-on-primary active:scale-[0.98]"
              >
                <span className="material-symbols-outlined text-[20px]">replay</span>
                Rematch
              </button>
              <button
                type="button"
                onClick={() => router.push('/arena')}
                className="flex h-[52px] flex-1 items-center justify-center rounded-xl bg-surface-container-low text-[15px] font-semibold text-on-surface hover:bg-surface-container"
              >
                Back to lobby
              </button>
            </div>
          )}
        </div>
      )}

      {(phase === 'dueling' || phase === 'over') && !q && (
        <div className="flex flex-col items-center gap-3 py-24">
          <RenanceMark size={44} state="busy" />
          <p className="text-[15px] text-on-surface-variant">Loading the first question…</p>
        </div>
      )}

      <SideNav />
      <BottomNav />
    </main>
  );
}

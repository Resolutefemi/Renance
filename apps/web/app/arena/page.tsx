'use client';

/**
 * THE ARENA - one surface, one socket, everything live.
 *
 * Three ways into a duel (the founder's cut):
 *   · Quick Match        - the per-focus bucket queue (bot keeps it moving)
 *   · Invite / Join code - host a room, share the code or the link
 *   · Active Now         - live presence list; tap Battle to challenge
 *
 * Every focus is its own arena: a JAMBite never meets a tertiary
 * student, and each focus ranks on its own ladder. A duel is 15
 * questions at a 20-second window each - five minutes - and every win
 * is worth 1 Ren Point. The whole flow (queue, invite, duel, result)
 * runs on one authenticated WebSocket so the connection never drops
 * mid-match; the old /arena/match page redirects here.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense } from 'react';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import SideNav from '@/components/side-nav';
import { RenanceMark } from '@/components/renance-logo';
import { QText } from '@/lib/qtext';
import { api } from '@/lib/api';
import { ArenaSocket, type ArenaInbound } from '@/lib/arena';

type Phase = 'idle' | 'queued' | 'hosted' | 'challengeSent' | 'dueling' | 'over';

const FOCI = ['JAMB', 'WAEC', 'NECO', 'POST-UTME', 'University Modules'] as const;
type Focus = (typeof FOCI)[number];

interface BoardEntry {
  rank: number;
  username: string;
  wins: number;
  matches: number;
}
interface ArenaBoard {
  entries: BoardEntry[];
  me: { rank: number; username: string; wins: number } | null;
}
interface PlayerRow {
  userId: string;
  username: string;
  renPoints: number;
}
interface MeResponse {
  user: { id: string };
  profile: { exams: string[] } | null;
}

const mmss = (total: number) => {
  const m = Math.floor(Math.max(0, total) / 60);
  const s = Math.max(0, total) % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
};

function focusLabel(f: string) {
  return f === 'University Modules' ? 'Tertiary' : f;
}

export default function ArenaPage() {
  return (
    <Suspense fallback={null}>
      <ArenaInner />
    </Suspense>
  );
}

function ArenaInner() {
  const router = useRouter();
  const params = useSearchParams();

  const [meId, setMeId] = useState('');
  const [focus, setFocus] = useState<Focus>('JAMB');
  const [phase, setPhase] = useState<Phase>('idle');
  const [sockDown, setSockDown] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // lobby data
  const [board, setBoard] = useState<ArenaBoard | null>(null);
  const [boardErr, setBoardErr] = useState(false);
  const [period, setPeriod] = useState<'week' | 'all'>('week');
  const [players, setPlayers] = useState<PlayerRow[] | null>(null);

  // lobby states
  const [roomCode, setRoomCode] = useState('');
  const [joinCode, setJoinCode] = useState('');
  const [joinOpen, setJoinOpen] = useState(false);
  const [invite, setInvite] = useState<{ opponent: string; code: string } | null>(null);
  const [challenged, setChallenged] = useState<{ opponent: string; code: string } | null>(null);

  // duel state
  const [opponent, setOpponent] = useState('');
  const [packCode, setPackCode] = useState('');
  const [questionCount, setQuestionCount] = useState(15);
  const [secondsPerQuestion, setSecondsPerQuestion] = useState(20);
  const [q, setQ] = useState<Extract<ArenaInbound, { type: 'question' }> | null>(null);
  const [picked, setPicked] = useState<string | null>(null);
  const [lastCorrect, setLastCorrect] = useState<string | null>(null);
  const [you, setYou] = useState(0);
  const [rival, setRival] = useState(0);
  const [winner, setWinner] = useState<string | null>(null);
  const [, setTick] = useState(0);

  const sockRef = useRef<ArenaSocket | null>(null);
  const askedAt = useRef(0);
  const focusRef = useRef<Focus>('JAMB');
  focusRef.current = focus;

  // 1s heartbeat drives the round clock + countdowns.
  useEffect(() => {
    const t = setInterval(() => setTick((n) => n + 1), 1000);
    return () => clearInterval(t);
  }, []);

  const refreshLobby = useCallback((f: Focus) => {
    api<ArenaBoard>(`/leaderboard/arena?period=${period}&body=${encodeURIComponent(f)}`)
      .then((b) => {
        setBoard(b);
        setBoardErr(false);
      })
      .catch(() => setBoardErr(true));
    api<{ players: PlayerRow[] }>('/arena/players')
      .then((r) => setPlayers(r.players))
      .catch(() => setPlayers(null));
  }, [period]);

  useEffect(() => {
    if (phase !== 'idle') return;
    refreshLobby(focus);
    const t = setInterval(() => refreshLobby(focus), 15000);
    return () => clearInterval(t);
  }, [phase, focus, refreshLobby]);

  const backToLobby = useCallback(() => {
    setPhase('idle');
    setQ(null);
    setPicked(null);
    setLastCorrect(null);
    setWinner(null);
    setOpponent('');
    setRoomCode('');
    setErrorMsg(null);
  }, []);

  const handleFrame = useCallback(
    (frame: ArenaInbound) => {
      switch (frame.type) {
        case 'queued':
          setPhase('queued');
          break;
        case 'hosted':
          setRoomCode(frame.code);
          setPhase('hosted');
          break;
        case 'challenge_sent':
          setRoomCode(frame.code);
          setPhase('challengeSent');
          break;
        case 'challenge':
          // A live invite only matters while idle; the hub refuses
          // invites to busy students anyway.
          setChallenged({ opponent: frame.opponent, code: frame.code });
          break;
        case 'matched':
          setOpponent(frame.opponent || 'Renance Bot');
          setPackCode(frame.code || '');
          setQuestionCount(frame.questionCount ?? 15);
          setSecondsPerQuestion(frame.secondsPerQuestion ?? 20);
          setYou(0);
          setRival(0);
          setWinner(null);
          setQ(null);
          setPicked(null);
          setRoomCode('');
          setInvite(null);
          setChallenged(null);
          setPhase('dueling');
          break;
        case 'question':
          askedAt.current = Date.now();
          setPicked(null);
          setLastCorrect(null);
          setQ(frame);
          setPhase('dueling');
          break;
        case 'result': {
          setLastCorrect(frame.correctLetter);
          const solved = frame.solved ?? {};
          if (meId && solved[meId]) setYou((n) => n + 1);
          else if (Object.entries(solved).some(([id, ok]) => ok && id !== meId)) setRival((n) => n + 1);
          break;
        }
        case 'over': {
          const scores = frame.scores ?? {};
          const other = Object.entries(scores).find(([id]) => id !== meId);
          if (meId && scores[meId] != null) setYou(scores[meId]);
          if (other) setRival(other[1]);
          setWinner(frame.winner);
          setPhase('over');
          break;
        }
        case 'error':
          if (frame.errorCode === 'no_pack_available') {
            setErrorMsg(`No live pack for ${focusRef.current} yet, try another focus.`);
            setPhase('idle');
          } else if (frame.errorCode !== 'already_queued' && frame.errorCode !== 'in_match') {
            setErrorMsg(frame.message || 'The arena refused that move.');
            if (phase !== 'dueling' && phase !== 'over') setPhase('idle');
          }
          break;
        default:
          break;
      }
    },
    [meId, phase],
  );

  // One socket for the whole session.
  useEffect(() => {
    let alive = true;
    (async () => {
      let id = '';
      let body: string = 'JAMB';
      try {
        const me = await api<MeResponse>('/me');
        if (!alive) return;
        id = me.user?.id ?? '';
        const exam = me.profile?.exams?.[0] ?? 'JAMB';
        if (/^waec$/i.test(exam)) body = 'WAEC';
        else if (/^neco$/i.test(exam)) body = 'NECO';
        else if (/post/i.test(exam)) body = 'POST-UTME';
        else if (/university/i.test(exam)) body = 'University Modules';
      } catch {
        /* api() redirects on 401 */
      }
      if (!alive) return;
      setMeId(id);
      setFocus(body as Focus);
      setJoinOpen(!!params.get('join'));

      sockRef.current = new ArenaSocket({
        onFrame: (frame) => {
          if (alive) handleFrame(frame);
        },
        onDown: () => {
          if (alive) setSockDown(true);
        },
      });
    })();
    return () => {
      alive = false;
      sockRef.current?.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const send = useCallback((frame: Parameters<ArenaSocket['send']>[0]) => {
    setErrorMsg(null);
    sockRef.current?.send(frame);
  }, []);

  const inLobby = phase === 'idle';
  const secondsLeft = q?.deadline ? Math.max(0, q.deadline - Math.floor(Date.now() / 1000)) : secondsPerQuestion;

  const joinLink = useMemo(() => {
    if (!roomCode) return '';
    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    return `${origin}/arena?join=${roomCode}`;
  }, [roomCode]);

  /* ------------------------------------------------------------ lobby */

  return (
    <main className="min-h-dvh bg-surface pb-28 md:pb-16 md:pl-[var(--rail-w)]">
      <div className="mx-auto w-full max-w-2xl px-4 pt-4 sm:px-6 lg:max-w-4xl">
        <PageBar title="Arena" />
      </div>

      {/* focus tabs - each focus is its own arena */}
      {inLobby && (
        <div className="mx-auto mt-3 w-full max-w-2xl px-4 sm:px-6 lg:max-w-4xl">
          <div className="no-scrollbar flex items-center gap-2 overflow-x-auto pb-1">
            {FOCI.map((f) => (
              <button
                key={f}
                onClick={() => setFocus(f)}
                className={`shrink-0 rounded-full px-4 py-2 text-[12.5px] font-bold uppercase tracking-wide transition ${
                  focus === f
                    ? 'bg-accent-ink text-white shadow-sm'
                    : 'bg-card text-on-surface-variant hover:text-on-surface'
                }`}
              >
                {focusLabel(f)}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* ------------------------------------------------- duel view */}
      {(phase === 'dueling' || phase === 'over') && (
        <div className="mx-auto w-full max-w-2xl px-4 pt-3 sm:px-6">
          {/* live strip */}
          <div className="relative overflow-hidden rounded-2xl bg-gradient-to-tl from-[#0E2230] to-[#131B2E] px-5 py-4">
            <span className="absolute -right-10 -top-10 h-32 w-32 rounded-full bg-white/5" />
            <div className="relative flex items-center justify-between">
              <span className="flex items-center gap-2 text-[11px] font-bold uppercase tracking-[0.25em] text-dark-text-primary">
                <span className={`h-2 w-2 rounded-full ${phase === 'over' ? 'bg-dark-text-primary/40' : 'animate-pulse bg-error'}`} />
                {phase === 'over' ? 'Full time' : 'Live duel'}
              </span>
              <span className="font-mono text-[11px] uppercase tracking-widest text-dark-text-primary/60">
                {focus} · {packCode}
              </span>
            </div>
          </div>

          {/* VS scoreline */}
          <div className="mt-3 grid grid-cols-[1fr_auto_1fr] items-center gap-2 rounded-2xl bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <div className="flex flex-col items-center">
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-selection-blue text-[13px] font-bold text-on-surface">
                YOU
              </span>
              <p className="mt-1.5 text-[22px] font-extrabold leading-none text-on-surface">{you}</p>
            </div>
            <div className="text-center">
              <p className="text-[13px] font-black uppercase tracking-[0.2em] text-outline">VS</p>
              <p className="font-mono text-[24px] font-bold leading-tight text-on-surface">
                {q ? mmss(secondsLeft) : mmss(secondsPerQuestion)}
              </p>
              <p className="font-mono text-[11px] text-on-surface-variant">
                Q{(q?.index ?? 0) + 1} / {questionCount}
              </p>
            </div>
            <div className="flex flex-col items-center">
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-high text-on-surface-variant">
                <span className="material-symbols-outlined text-[22px]">{opponent === 'Renance Bot' ? 'smart_toy' : 'person'}</span>
              </span>
              <p className="mt-1.5 text-[22px] font-extrabold leading-none text-on-surface">{rival}</p>
            </div>
          </div>
          <p className="mt-1.5 text-center text-[12px] text-on-surface-variant">
            {opponent === 'Renance Bot' ? 'The house bot' : opponent} across the floor
          </p>

          {/* round pips */}
          <div className="no-scrollbar mt-3 flex items-center justify-center gap-1.5 overflow-x-auto px-2">
            {Array.from({ length: questionCount }, (_, i) => {
              const done = q ? i < (q.index ?? 0) : phase === 'over';
              const now = q && i === (q.index ?? 0);
              return (
                <span
                  key={i}
                  className={`h-1.5 w-4 shrink-0 rounded-full ${
                    now ? 'bg-primary' : done ? 'bg-accent-ink/60' : 'bg-surface-container-high'
                  }`}
                />
              );
            })}
          </div>

          {/* question card */}
          {q && (
            <div className="mt-4 rounded-2xl bg-card p-5 shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
              <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-on-surface-variant">
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
                      onClick={() => {
                        setPicked(letter);
                        send({ type: 'answer', index: q.index ?? 0, letter });
                      }}
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
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* rail */}
          <div className="mt-4">
            <div className="rounded-xl bg-surface-container-high px-4 py-3 text-center text-[13px] font-medium text-on-surface-variant">
              {phase === 'over'
                ? winner == null
                  ? 'A draw - the point stays in the house.'
                  : winner === meId
                    ? 'You took the duel - +1 Ren Point on the board.'
                    : `${opponent} took this one. Run it back.`
                : picked
                  ? 'Answer locked in. Next question is loading…'
                  : 'Answer locks in when the clock hits zero.'}
            </div>
          </div>

          {phase === 'over' && (
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={() => {
                  setPhase('queued');
                  send({ type: 'queue', body: focus });
                }}
                className="flex h-[52px] flex-1 items-center justify-center gap-2 rounded-xl bg-primary text-[15px] font-semibold text-on-primary active:scale-[0.98]"
              >
                <span className="material-symbols-outlined text-[20px]">replay</span>
                Rematch
              </button>
              <button
                type="button"
                onClick={backToLobby}
                className="flex h-[52px] flex-1 items-center justify-center rounded-xl bg-surface-container-low text-[15px] font-semibold text-on-surface hover:bg-surface-container"
              >
                Back to the floor
              </button>
            </div>
          )}
        </div>
      )}

      {/* -------------------------------------------- waiting states */}
      {(phase === 'queued' || phase === 'hosted' || phase === 'challengeSent') && (
        <div className="mx-auto w-full max-w-md px-4 pt-6 sm:px-6">
          <div className="rounded-2xl bg-card p-6 text-center shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            <RenanceMark size={40} state="busy" />
            {phase === 'queued' && (
              <>
                <h2 className="mt-3 text-lg font-bold text-on-surface">Finding a {focusLabel(focus)} rival…</h2>
                <p className="mt-1 text-[13.5px] text-on-surface-variant">
                  A live student on your shelf, or the house bot keeps the floor moving.
                </p>
              </>
            )}
            {(phase === 'hosted' || phase === 'challengeSent') && (
              <>
                <h2 className="mt-3 text-lg font-bold text-on-surface">
                  {phase === 'hosted' ? 'Your room is open' : `Challenge sent to ${opponent || 'your rival'}`}
                </h2>
                <p className="mt-1 text-[13.5px] text-on-surface-variant">Share the code - the duel starts the moment they walk in.</p>
                <p className="mt-4 font-mono text-[34px] font-bold tracking-[0.3em] text-on-surface">{roomCode}</p>
                {joinLink && (
                  <button
                    type="button"
                    onClick={() => void navigator.clipboard?.writeText(joinLink)}
                    className="mt-3 rounded-full bg-surface-container-low px-4 py-2 text-[12.5px] font-medium text-on-surface-variant hover:text-on-surface"
                  >
                    <span className="material-symbols-outlined mr-1 align-[-3px] text-[15px]">link</span>
                    Copy invite link
                  </button>
                )}
              </>
            )}
            <button
              type="button"
              onClick={() => {
                send({ type: 'cancel' });
                backToLobby();
              }}
              className="mt-5 rounded-lg px-4 py-2 text-[14px] font-medium text-on-surface-variant hover:bg-surface-container"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* --------------------------------------------------- lobby */}
      {inLobby && (
        <div className="mx-auto w-full max-w-2xl px-4 sm:px-6 lg:max-w-4xl">
          {/* dark hero */}
          <section className="renance-rise relative mt-4 overflow-hidden rounded-2xl bg-gradient-to-tl from-[#0E2230] to-[#131B2E] p-6">
            <span className="absolute -right-12 -top-12 h-40 w-40 rounded-full bg-white/5" />
            <span className="absolute -bottom-14 -left-10 h-36 w-36 rounded-full bg-white/5" />
            <p className="relative font-mono text-[10px] uppercase tracking-[0.3em] text-dark-text-primary/60">
              {focusLabel(focus)} floor
            </p>
            <h2 className="relative mt-1 text-2xl font-black uppercase tracking-tight text-dark-text-primary">
              Enter the arena
            </h2>
            <div className="relative mt-3 flex flex-wrap gap-2">
              {['15 questions', '5:00 minutes', 'Win = +1 Ren Point'].map((r) => (
                <span key={r} className="rounded-full bg-white/10 px-3 py-1 font-mono text-[11px] font-semibold text-dark-text-primary">
                  {r}
                </span>
              ))}
            </div>
            {sockDown ? (
              <div className="relative mt-5 rounded-xl bg-white/10 px-4 py-3 text-center text-[13.5px] text-dark-text-primary">
                The arena socket dropped.
                <button type="button" onClick={() => window.location.reload()} className="ml-1 font-bold underline">
                  Reconnect
                </button>
              </div>
            ) : (
              <div className="relative mt-5 grid gap-2 sm:grid-cols-3">
                <button
                  onClick={() => send({ type: 'queue', body: focus })}
                  className="col-span-1 flex h-[52px] items-center justify-center gap-2 rounded-xl bg-card text-[14.5px] font-bold text-on-surface transition-all hover:shadow-md active:scale-[0.98] sm:col-span-3"
                >
                  <span className="material-symbols-outlined text-[20px]">swords</span>
                  Quick Match
                </button>
                <button
                  onClick={() => send({ type: 'host', body: focus })}
                  className="flex h-11 items-center justify-center gap-1.5 rounded-xl bg-white/10 text-[13px] font-semibold text-dark-text-primary transition hover:bg-white/15"
                >
                  <span className="material-symbols-outlined text-[17px]">meeting_room</span>
                  Host a room
                </button>
                <button
                  onClick={() => {
                    setJoinCode('');
                    setJoinOpen(true);
                  }}
                  className="flex h-11 items-center justify-center gap-1.5 rounded-xl bg-white/10 text-[13px] font-semibold text-dark-text-primary transition hover:bg-white/15"
                >
                  <span className="material-symbols-outlined text-[17px]">group_add</span>
                  Join with code
                </button>
                <button
                  onClick={() => players?.[0] && send({ type: 'challenge', target: players[0].userId, body: focus })}
                  className="hidden"
                />
              </div>
            )}
            {errorMsg && <p className="relative mt-3 rounded-lg bg-error/20 px-3 py-2 text-[12.5px] text-dark-text-primary">{errorMsg}</p>}
          </section>

          {/* Active now */}
          <div className="mt-6 flex items-center justify-between">
            <h2 className="flex items-center gap-2 text-lg font-bold tracking-tight text-on-surface">
              Active now
              <span className="h-2 w-2 animate-pulse rounded-full bg-accent-emerald" />
            </h2>
            <span className="font-mono text-[11px] text-on-surface-variant">{players?.length ?? 0} on the floor</span>
          </div>
          <div className="mt-3 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            {players && players.length === 0 && (
              <p className="px-4 py-5 text-center text-[13.5px] text-on-surface-variant">
                Nobody else is in the {focusLabel(focus)} arena right now - quick match, or bring a friend with a room code.
              </p>
            )}
            {!players && (
              <p className="px-4 py-5 text-center text-[13.5px] text-on-surface-variant">Checking who is on the floor…</p>
            )}
            {players?.map((p) => (
              <div key={p.userId} className="flex items-center gap-3 px-4 py-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-container-low">
                  <span className="material-symbols-outlined text-[20px] text-on-surface-variant">person</span>
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[14.5px] font-semibold text-on-surface">{p.username}</span>
                  <span className="block font-mono text-[11px] text-on-surface-variant">{p.renPoints} Ren Points</span>
                </span>
                <button
                  onClick={() => send({ type: 'challenge', target: p.userId, body: focus })}
                  className="flex h-9 shrink-0 items-center gap-1 rounded-full bg-accent-ink px-4 text-[12.5px] font-bold text-white transition hover:opacity-90 active:scale-[0.97]"
                >
                  <span className="material-symbols-outlined text-[15px]">swords</span>
                  Battle
                </button>
              </div>
            ))}
          </div>

          {/* Focus Rank - the live per-focus board */}
          <div className="mt-7 flex items-center justify-between">
            <h2 className="text-lg font-bold tracking-tight text-on-surface">{focusLabel(focus)} Rank</h2>
            <div className="flex items-center gap-2">
              {(['week', 'all'] as const).map((p) => (
                <button
                  key={p}
                  onClick={() => setPeriod(p)}
                  className={`rounded-full px-3 py-1 text-[11.5px] font-semibold transition ${
                    period === p ? 'bg-accent-ink text-white' : 'bg-surface-container-low text-on-surface-variant'
                  }`}
                >
                  {p === 'week' ? 'This week' : 'All time'}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-3 divide-y divide-outline-light overflow-hidden rounded-2xl bg-card shadow-[0_1px_3px_0_rgba(20,28,45,0.20)]">
            {boardErr && (
              <p className="px-4 py-5 text-center text-[14px] text-on-surface-variant">Could not load the board, check your connection.</p>
            )}
            {board && board.entries.length === 0 && (
              <p className="px-4 py-5 text-center text-[14px] text-on-surface-variant">
                No {focusLabel(focus)} duels scored yet - be the first name on the ladder.
              </p>
            )}
            {board?.entries.slice(0, 10).map((e) => (
              <div key={`${e.rank}-${e.username}`} className="flex items-center gap-3 py-3">
                <span className={`w-10 shrink-0 text-center font-mono text-[14px] ${e.rank <= 3 ? 'font-bold text-accent-amber' : 'text-on-surface-variant'}`}>
                  {e.rank === 1 ? '①' : e.rank === 2 ? '②' : e.rank === 3 ? '③' : e.rank}
                </span>
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-container-low">
                  <span className="material-symbols-outlined text-[20px] text-on-surface-variant">person</span>
                </span>
                <span className="min-w-0 flex-1 truncate text-[14.5px] font-semibold text-on-surface">{e.username}</span>
                <span className="flex items-center gap-1 pr-4 font-mono text-[13px] font-bold text-on-surface">
                  <span className="material-symbols-outlined text-[15px] text-accent-amber">military_tech</span>
                  {e.wins}
                </span>
              </div>
            ))}
            {board?.me && !board.entries.slice(0, 10).some((e) => e.username === board.me?.username) && (
              <div className="flex items-center gap-3 bg-surface-container-low py-3">
                <span className="w-10 shrink-0 text-center font-mono text-[14px] text-on-surface-variant">{board.me.rank}</span>
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-card">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/renance-mark.png`} alt="You" className="h-6 w-6" />
                </span>
                <span className="min-w-0 flex-1 truncate text-[14.5px] font-semibold text-on-surface">{board.me.username}</span>
                <span className="pr-4 font-mono text-[13px] font-bold text-on-surface">{board.me.wins}</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ------------------------------------------- join-code sheet */}
      {joinOpen && (
        <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center">
          <button aria-label="Close" onClick={() => setJoinOpen(false)} className="absolute inset-0 bg-accent-ink/40" />
          <div className="relative w-full max-w-sm rounded-t-3xl bg-surface-container-lowest p-6 shadow-2xl sm:rounded-3xl">
            <h3 className="text-lg font-bold text-on-surface">Join a duel</h3>
            <p className="mt-1 text-[13.5px] text-on-surface-variant">Paste the room code a friend shared with you.</p>
            <input
              value={joinCode}
              onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
              placeholder="ABC123"
              maxLength={6}
              className="mt-4 h-14 w-full rounded-xl border border-outline-variant bg-card text-center font-mono text-[24px] font-bold tracking-[0.3em] text-on-surface outline-none focus:border-primary"
            />
            <button
              onClick={() => {
                if (joinCode.trim().length < 4) return;
                send({ type: 'join', code: joinCode.trim() });
                setJoinOpen(false);
              }}
              disabled={joinCode.trim().length < 4}
              className="mt-4 h-[52px] w-full rounded-xl bg-primary text-[15px] font-bold text-on-primary transition active:scale-[0.98] disabled:opacity-50"
            >
              Walk in
            </button>
          </div>
        </div>
      )}

      {/* --------------------------------------- incoming challenge */}
      {challenged && (
        <div className="fixed inset-0 z-[55] flex items-center justify-center px-5">
          <div className="absolute inset-0 bg-accent-ink/50" />
          <div className="relative w-full max-w-sm rounded-[18px] bg-surface-container-lowest p-6 text-center shadow-2xl">
            <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-accent-ink text-white">
              <span className="material-symbols-outlined text-[26px]">swords</span>
            </span>
            <h3 className="mt-3 text-lg font-bold text-on-surface">{challenged.opponent} challenges you</h3>
            <p className="mt-1 text-[13.5px] text-on-surface-variant">15 questions · 5 minutes · 1 Ren Point to the winner.</p>
            <div className="mt-5 flex gap-2">
              <button
                onClick={() => setChallenged(null)}
                className="h-11 flex-1 rounded-xl border border-outline-variant bg-card text-[14px] font-semibold text-on-surface-variant"
              >
                Decline
              </button>
              <button
                onClick={() => {
                  send({ type: 'join', code: challenged.code });
                  setChallenged(null);
                }}
                className="h-11 flex-1 rounded-xl bg-primary text-[14px] font-bold text-on-primary"
              >
                Accept duel
              </button>
            </div>
          </div>
        </div>
      )}

      <SideNav />
      <BottomNav />
    </main>
  );
}

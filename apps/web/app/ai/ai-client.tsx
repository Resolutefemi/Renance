'use client';

/**
 * Renance AI Studio - the companion rebuilt as a full studio (founder
 * directive, 2026-09-30). Three zones:
 *
 *   - The rail (left): chat folders, history, memories and the
 *     generated documents shelf, all persisted server-side so nothing
 *     is lost when the app closes.
 *   - The chat (center): the grounded conversation with visible
 *     thinking phases (Thinking, Analysing, Researching past
 *     questions, Composing) and the past-question bridge badge.
 *   - The canvas (right): generated documents come alive Gemini-Canvas
 *     style - quizzes are playable, notes render with the house
 *     template, everything exports to PDF and quizzes share via
 *     public name-bearing links.
 *
 * Strictly black and white, matching the app's design system.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import PageBar from '@/components/page-bar';
import BottomNav from '@/components/bottom-nav';
import AiSparkle from '@/components/ai-sparkle';
import { getToken } from '@/lib/session';
import { ApiError } from '@/lib/api';
import {
  addMemory,
  bridgeStats,
  createChat,
  deleteChat,
  deleteMemory,
  getChat,
  listArtifacts,
  listChats,
  listFolders,
  listMemories,
  saveNoteFromText,
  sendMessage,
  updateChat,
  type ArtifactKind,
  type BridgeStats,
  type GenerateResult,
  type StudioArtifact,
  type StudioChat,
  type StudioFolder,
  type StudioMemory,
  type StudioMessage,
} from '@/lib/ai-studio';
import { ArtifactCanvas } from './ai-canvas';
import { GeneratorForm, PhaseTicker, type GenMode } from './ai-forms';

type ModeTab = 'chat' | GenMode;

const TABS: { id: ModeTab; label: string; icon: string }[] = [
  { id: 'chat', label: 'Chat', icon: 'auto_awesome' },
  { id: 'quiz', label: 'Quiz', icon: 'quiz' },
  { id: 'note', label: 'Note', icon: 'description' },
  { id: 'notebook', label: 'Notebook', icon: 'menu_book' },
  { id: 'lesson_note', label: 'Lesson note', icon: 'co_present' },
];

const SUGGESTIONS = [
  'Explain photosynthesis like I am in JSS 2, with a village example',
  'Show me real JAMB past questions on simple interest and solve them',
  'Teach me surds step by step with three worked examples',
  'Remember that I am in SSS 2 and my target is UNILAG for Medicine',
];

const CHAT_PHASES = ['Thinking', 'Analysing the topic', 'Researching past questions', 'Composing'];

export default function AiClient() {
  const signedIn = typeof window !== 'undefined' ? getToken() : true;

  // studio state -----------------------------------------------------------
  const [tab, setTab] = useState<ModeTab>('chat');
  const [railOpen, setRailOpen] = useState(false);
  const [stats, setStats] = useState<BridgeStats | null>(null);

  // chats + folders + memories
  const [chats, setChats] = useState<StudioChat[]>([]);
  const [folders, setFolders] = useState<StudioFolder[]>([]);
  const [activeFolder, setActiveFolder] = useState('');
  const [activeChat, setActiveChat] = useState<StudioChat | null>(null);
  const [messages, setMessages] = useState<StudioMessage[]>([]);
  const [memories, setMemories] = useState<StudioMemory[]>([]);
  const [memoryDraft, setMemoryDraft] = useState('');
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  // generators + canvas
  const [genBusy, setGenBusy] = useState(false);
  const [genError, setGenError] = useState<string | null>(null);
  const [artifact, setArtifact] = useState<StudioArtifact | null>(null);
  const [artifacts, setArtifacts] = useState<StudioArtifact[]>([]);
  const [canvasOpen, setCanvasOpen] = useState(false);

  const endRef = useRef<HTMLDivElement>(null);

  const showToast = useCallback((t: string) => {
    setToast(t);
    window.setTimeout(() => setToast(null), 2200);
  }, []);

  const refreshLedge = useCallback(async () => {
    try {
      const [c, f] = await Promise.all([listChats(activeFolder || undefined), listFolders()]);
      setChats(c);
      setFolders(f);
    } catch {
      /* signed out or offline: rail just stays as-is */
    }
  }, [activeFolder]);

  useEffect(() => {
    document.title = 'Renance AI Studio';
    if (!getToken()) return;
    void refreshLedge();
    void listMemories().then(setMemories).catch(() => {});
    void listArtifacts().then(setArtifacts).catch(() => {});
    void bridgeStats().then(setStats).catch(() => {});
  }, [refreshLedge]);

  useEffect(() => {
    if (!getToken()) return;
    void refreshLedge();
  }, [activeFolder, refreshLedge]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [messages, busy]);

  // chat --------------------------------------------------------------------
  const send = useCallback(
    async (text: string) => {
      const clean = text.trim();
      if (!clean || busy) return;
      if (!getToken()) {
        setMessages((m) => [
          ...m,
          { id: Date.now(), role: 'user', content: clean, createdAt: new Date().toISOString() },
          {
            id: Date.now() + 1,
            role: 'assistant',
            content: 'Sign in to use Renance AI Studio. Your chats, memories and documents live on your account.',
            createdAt: new Date().toISOString(),
          },
        ]);
        return;
      }
      setDraft('');
      setBusy(true);
      // Optimistic user bubble.
      const optimistic: StudioMessage = { id: -Date.now(), role: 'user', content: clean, createdAt: new Date().toISOString() };
      setMessages((m) => [...m, optimistic]);
      try {
        let chat = activeChat;
        if (!chat) {
          chat = await createChat();
          setActiveChat(chat);
        }
        const res = await sendMessage(chat.id, clean);
        // Replace optimistic bubble with the server pair.
        setMessages((m) => [...m.filter((x) => x.id !== optimistic.id), res.userMessage, res.assistantMessage]);
        if (res.memorySaved) showToast('Memory saved');
        void refreshLedge();
      } catch (e) {
        // Founder directive 2026-10-12 ("remove the fallback feature
        // completely - the AI answers directly"): the server never saves
        // a canned non-answer anymore; a double provider failure arrives
        // as ai_unavailable and surfaces as a normal retryable error
        // bubble, exactly like every real AI chat app.
        const code = e instanceof ApiError ? e.code : '';
        const text =
          code === 'rate_limited'
            ? 'Renance AI is cooling down for a few seconds; try again shortly.'
            : code === 'ai_unavailable'
              ? 'Renance AI could not answer just now. Send the message again.'
              : 'Renance AI could not reach the server. Check the connection and try again.';
        setMessages((m) => [
          ...m,
          {
            id: -Date.now() - 1,
            role: 'assistant',
            content: text,
            createdAt: new Date().toISOString(),
          },
        ]);
      } finally {
        setBusy(false);
      }
    },
    [activeChat, busy, refreshLedge, showToast],
  );

  async function openChat(c: StudioChat) {
    setActiveChat(c);
    setTab('chat');
    setRailOpen(false);
    try {
      const res = await getChat(c.id);
      setMessages(res.messages);
    } catch {
      setMessages([]);
    }
  }

  async function newChat(folder?: string) {
    try {
      const c = await createChat(folder ? { folder } : undefined);
      setActiveChat(c);
      setMessages([]);
      setTab('chat');
      setRailOpen(false);
      void refreshLedge();
    } catch {
      showToast('Could not open a new chat');
    }
  }

  async function renameChat(c: StudioChat) {
    const t = window.prompt('Rename chat', c.title);
    if (!t || !t.trim() || t.trim() === c.title) return;
    try {
      await updateChat(c.id, { title: t.trim().slice(0, 90) });
      void refreshLedge();
      if (activeChat?.id === c.id) setActiveChat({ ...c, title: t.trim() });
    } catch {
      showToast('Could not rename');
    }
  }

  async function moveChat(c: StudioChat) {
    const names = folders.map((f) => f.name);
    const extra = 'General';
    const all = Array.from(new Set([extra, ...names]));
    const target = window.prompt(`Move to folder (${all.join(', ')})`, c.folder);
    if (!target || !target.trim() || target.trim() === c.folder) return;
    try {
      await updateChat(c.id, { folder: target.trim().slice(0, 60) });
      void refreshLedge();
    } catch {
      showToast('Could not move the chat');
    }
  }

  async function removeChat(c: StudioChat) {
    if (!window.confirm(`Delete "${c.title}"?`)) return;
    try {
      await deleteChat(c.id);
      if (activeChat?.id === c.id) {
        setActiveChat(null);
        setMessages([]);
      }
      void refreshLedge();
    } catch {
      showToast('Could not delete');
    }
  }

  // memories ------------------------------------------------------------------
  async function saveMemory() {
    const clean = memoryDraft.trim();
    if (!clean) return;
    try {
      const m = await addMemory(clean);
      setMemories((ms) => [...ms, m]);
      setMemoryDraft('');
      showToast('Renance AI will remember that');
    } catch {
      showToast('Could not save the memory');
    }
  }

  async function forgetMemory(id: number) {
    try {
      await deleteMemory(id);
      setMemories((ms) => ms.filter((m) => m.id !== id));
    } catch {
      showToast('Could not remove');
    }
  }

  // chat message actions --------------------------------------------------------
  async function saveMessageAsNote(m: StudioMessage) {
    const title = window.prompt('Note title', m.content.split('\n')[0].slice(0, 80) || 'Saved from Renance AI');
    if (!title || !title.trim()) return;
    try {
      await saveNoteFromText({ title: title.trim(), content: m.content });
      showToast('Saved to your Notes');
      void listArtifacts().then(setArtifacts).catch(() => {});
    } catch {
      showToast('Could not save the note');
    }
  }

  // canvas ------------------------------------------------------------------------
  function onGenerated(res: GenerateResult) {
    setArtifact(res.artifact);
    setCanvasOpen(true);
    void listArtifacts().then(setArtifacts).catch(() => {});
    if (res.bridged && res.bridged > 0) {
      showToast(`Grounded on ${res.bridged} real past questions`);
    }
  }

  function openArtifactDoc(a: StudioArtifact) {
    setArtifact(a);
    setCanvasOpen(true);
    setRailOpen(false);
  }

  // render -------------------------------------------------------------------------
  if (!signedIn) {
    return (
      <div className="flex min-h-dvh flex-col bg-surface-container-lowest">
        <PageBar title="Renance AI" backHref="/dashboard" />
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-4 px-6 pb-28">
          {/* 2026-10-13 founder pass: the flat green slab becomes the
              Supreme gradient hero (primary -> treefrog-dark, hard
              extruded ledge) and the small copy runs SOLID white -
              white/75-on-green was the exact "small text not visible on
              big cards" complaint. */}
          <div className="rounded-2xl bg-gradient-to-br from-primary to-treefrog-dark px-5 py-6 text-white shadow-[0_4px_0_0_color-mix(in_srgb,var(--color-primary)_62%,#000)]">
            <span className="material-symbols-outlined text-[26px]">smart_toy</span>
            <h1 className="mt-2 text-xl font-extrabold tracking-tight">Renance AI Studio</h1>
            <p className="mt-2 text-[13px] font-semibold leading-relaxed text-white/95">
              Chats, folders and memories, quizzes, notes, notebooks and lesson notes - grounded
              on {stats ? stats.questions.toLocaleString() : '290,000+'} real past questions.
            </p>
          </div>
          <Link
            href="/login"
            className="rounded-xl bg-macaw py-3.5 text-center text-[14px] font-extrabold text-white"
          >
            Sign in to start
          </Link>
        </main>
        <BottomNav />
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh flex-col bg-surface-container-lowest">
      <PageBar
        title="Renance AI Studio"
        backHref="/dashboard"
        right={
          <button
            type="button"
            onClick={() => setRailOpen((v) => !v)}
            aria-label={railOpen ? 'Close menu' : 'Open chats, folders and memories'}
            aria-expanded={railOpen}
            className="flex h-9 w-9 items-center justify-center rounded-full text-on-surface transition hover:bg-surface-container md:hidden"
          >
            <span className="material-symbols-outlined text-[20px]">{railOpen ? 'close' : 'menu'}</span>
          </button>
        }
      />

      {/* Mobile scrim behind the rail: tap anywhere to dismiss (the old
          drawer floated with no backdrop, so nothing looked clickable and
          nothing closed it but the hamburger itself). */}
      {railOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/35 backdrop-blur-[1px] md:hidden"
          onClick={() => setRailOpen(false)}
          aria-hidden="true"
        />
      )}

      <div className="mx-auto flex w-full max-w-[1500px] flex-1 gap-0 px-0 pb-24 pt-0 md:px-4 md:pb-6 md:pt-4">
        {/* ------------------------- The rail ------------------------- */}
        <aside
          className={`${
            railOpen ? 'fixed inset-y-0 left-0 z-40 w-[86vw] max-w-sm overflow-y-auto' : 'hidden'
          } flex-col gap-4 border-r border-outline-variant/50 bg-surface-container-lowest p-3 md:sticky md:top-16 md:z-0 md:flex md:h-[calc(100dvh-8rem)] md:w-64 md:shrink-0 md:border-b-0`}
        >
          {/* Rail head: the house sparkle + a close affordance on phones */}
          <div className="flex items-center gap-2.5 px-1 pb-1 pt-0.5 md:pt-1">
            <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary text-on-primary">
              <AiSparkle className="h-[17px] w-[17px]" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[14px] font-bold tracking-tight text-on-surface">Renance AI</p>
              <p className="truncate font-mono text-[9px] uppercase tracking-[0.18em] text-on-surface-variant">Studio</p>
            </div>
            <button
              type="button"
              onClick={() => setRailOpen(false)}
              aria-label="Close menu"
              className="flex h-8 w-8 items-center justify-center rounded-full text-on-surface-variant transition hover:bg-surface-container md:hidden"
            >
              <span className="material-symbols-outlined text-[19px]">close</span>
            </button>
          </div>

          {/* New chat: the box-with-pencil affordance the flagship chat
              products use - an icon-first bordered button, not a fat +
              pill. */}
          <button
            type="button"
            onClick={() => newChat()}
            className="flex items-center justify-center gap-2 rounded-xl border-2 border-outline-variant bg-card px-3 py-2.5 text-[13px] font-extrabold text-on-surface shadow-[0_3px_0_0_var(--color-outline-variant)] transition hover:border-primary/50 hover:bg-surface-container-low active:translate-y-[2px] active:shadow-[0_1px_0_0_var(--color-outline-variant)]"
          >
            <span className="material-symbols-outlined text-[18px] text-on-surface">edit_square</span>
            New chat
          </button>

          {/* Folders */}
          <div>
            <div className="mb-1.5 flex items-center justify-between">
              <p className="font-mono text-[9.5px] uppercase tracking-[0.2em] text-on-surface-variant">Folders</p>
              <button
                type="button"
                onClick={() => {
                  const name = window.prompt('New folder name');
                  if (name && name.trim()) void newChat(name.trim().slice(0, 60));
                }}
                aria-label="New folder"
                className="flex h-6 w-6 items-center justify-center rounded-full text-on-surface-variant hover:bg-surface-container"
              >
                <span className="material-symbols-outlined text-[16px]">create_new_folder</span>
              </button>
            </div>
            <button
              type="button"
              onClick={() => setActiveFolder('')}
              className={`flex w-full items-center justify-between rounded-lg px-2.5 py-2 text-left text-[12.5px] transition ${
                activeFolder === '' ? 'bg-surface-container font-semibold text-on-surface' : 'text-on-surface-variant hover:bg-surface-container/60'
              }`}
            >
              <span className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[17px]">folder</span>
                All chats
              </span>
            </button>
            {folders.map((f) => (
              <button
                key={f.name}
                type="button"
                onClick={() => setActiveFolder(f.name)}
                className={`flex w-full items-center justify-between rounded-lg px-2.5 py-2 text-left text-[12.5px] transition ${
                  activeFolder === f.name ? 'bg-surface-container font-semibold text-on-surface' : 'text-on-surface-variant hover:bg-surface-container/60'
                }`}
              >
                <span className="flex min-w-0 items-center gap-2">
                  <span className="material-symbols-outlined text-[17px]">folder</span>
                  <span className="truncate">{f.name}</span>
                </span>
                <span className="font-mono text-[10.5px] text-on-surface-variant">{f.count}</span>
              </button>
            ))}
          </div>

          {/* History */}
          <div className="min-h-0">
            <p className="mb-1.5 font-mono text-[9.5px] uppercase tracking-[0.2em] text-on-surface-variant">History</p>
            <div className="flex max-h-56 flex-col gap-0.5 overflow-y-auto md:max-h-44">
              {chats.length === 0 && (
                <p className="px-2.5 py-2 text-[12px] leading-relaxed text-on-surface-variant">
                  No chats yet. Ask anything, or generate a quiz.
                </p>
              )}
              {chats.map((c) => (
                <div
                  key={c.id}
                  className={`group flex items-center gap-1 rounded-lg pl-1 pr-0.5 transition ${
                    activeChat?.id === c.id ? 'bg-surface-container' : 'hover:bg-surface-container/60'
                  }`}
                >
                  <button type="button" onClick={() => openChat(c)} className="min-w-0 flex-1 px-1.5 py-2 text-left">
                    <p className="truncate text-[12.5px] font-medium text-on-surface">{c.title}</p>
                    <p className="truncate font-mono text-[9.5px] uppercase tracking-wider text-on-surface-variant">{c.folder}</p>
                  </button>
                  <button type="button" onClick={() => renameChat(c)} aria-label="Rename" className="hidden h-7 w-7 items-center justify-center rounded-full text-on-surface-variant hover:bg-surface-container-high group-hover:flex">
                    <span className="material-symbols-outlined text-[15px]">edit</span>
                  </button>
                  <button type="button" onClick={() => moveChat(c)} aria-label="Move" className="hidden h-7 w-7 items-center justify-center rounded-full text-on-surface-variant hover:bg-surface-container-high group-hover:flex">
                    <span className="material-symbols-outlined text-[15px]">drive_file_move</span>
                  </button>
                  <button type="button" onClick={() => removeChat(c)} aria-label="Delete" className="hidden h-7 w-7 items-center justify-center rounded-full text-on-surface-variant hover:bg-error-container group-hover:flex">
                    <span className="material-symbols-outlined text-[15px]">delete</span>
                  </button>
                </div>
              ))}
            </div>
          </div>

          {/* Documents */}
          <div className="min-h-0">
            <p className="mb-1.5 font-mono text-[9.5px] uppercase tracking-[0.2em] text-on-surface-variant">Documents</p>
            <div className="flex max-h-44 flex-col gap-0.5 overflow-y-auto">
              {artifacts.length === 0 && (
                <p className="px-2.5 py-2 text-[12px] leading-relaxed text-on-surface-variant">
                  Quizzes, notes, notebooks and lesson notes you generate land here.
                </p>
              )}
              {artifacts.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  onClick={() => openArtifactDoc(a)}
                  className="flex items-center gap-2 rounded-lg px-2.5 py-2 text-left transition hover:bg-surface-container/60"
                >
                  <span className="material-symbols-outlined text-[16px] text-on-surface-variant">
                    {a.kind === 'quiz' ? 'quiz' : a.kind === 'notebook' ? 'menu_book' : a.kind === 'lesson_note' ? 'co_present' : 'description'}
                  </span>
                  <span className="truncate text-[12.5px] font-medium text-on-surface">{a.title}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Memories */}
          <div>
            <p className="mb-1.5 flex items-center gap-1.5 font-mono text-[9.5px] uppercase tracking-[0.2em] text-on-surface-variant">
              <span className="material-symbols-outlined text-[15px]">memory</span>
              Memories
            </p>
            <div className="flex flex-col gap-1">
              {memories.length === 0 && (
                <p className="px-0.5 py-1 text-[11.5px] leading-relaxed text-on-surface-variant">
                  Tell it "remember that..." and it carries the fact into every chat.
                </p>
              )}
              {memories.map((m) => (
                <div key={m.id} className="group flex items-start gap-1.5 rounded-lg bg-surface-container/70 px-2.5 py-2">
                  <p className="min-w-0 flex-1 break-words text-[12px] leading-relaxed text-on-surface">{m.content}</p>
                  <button type="button" onClick={() => forgetMemory(m.id)} aria-label="Forget" className="mt-0.5 hidden h-6 w-6 shrink-0 items-center justify-center rounded-full text-on-surface-variant hover:bg-error-container group-hover:flex">
                    <span className="material-symbols-outlined text-[14px]">close</span>
                  </button>
                </div>
              ))}
            </div>
            <div className="mt-2 flex gap-1.5">
              <input
                value={memoryDraft}
                onChange={(e) => setMemoryDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') void saveMemory();
                }}
                maxLength={400}
                placeholder="e.g. I write JAMB next April"
                className="min-w-0 flex-1 rounded-lg border border-outline-variant bg-card px-2.5 py-2 text-[12px] text-on-surface placeholder:text-on-surface-variant focus:outline-none focus:ring-2 focus:ring-primary/40"
              />
              <button
                type="button"
                onClick={() => void saveMemory()}
                aria-label="Save memory"
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary text-on-primary"
              >
                <span className="material-symbols-outlined text-[17px]">add</span>
              </button>
            </div>
          </div>
        </aside>

        {/* ------------------------- Main column ------------------------- */}
        <main className="relative flex min-w-0 flex-1 flex-col">
          {/* Tabs */}
          <div className="flex gap-1.5 overflow-x-auto border-b border-outline-variant/40 px-4 pb-2 pt-1 md:px-4">
            {TABS.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setTab(t.id)}
                className={`flex shrink-0 items-center gap-1.5 rounded-full px-3.5 py-2 text-[12.5px] font-semibold transition ${
                  tab === t.id ? 'bg-primary text-on-primary' : 'bg-card text-on-surface-variant hover:text-on-surface'
                }`}
              >
                <span className="material-symbols-outlined text-[16px]">{t.icon}</span>
                {t.label}
              </button>
            ))}
          </div>

          {tab === 'chat' ? (
            <>
              <div className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-3 px-4 py-4">
                {messages.length === 0 && !busy && (
                  <div className="renance-rise">
                    {/* Supreme gradient hero + solid white copy (see the
                        signed-out card note above). */}
                    <div className="rounded-2xl bg-gradient-to-br from-primary to-treefrog-dark px-5 py-5 text-white shadow-[0_4px_0_0_color-mix(in_srgb,var(--color-primary)_62%,#000)]">
                      <div className="flex items-center gap-2.5">
                        <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/15 shadow-[inset_0_1px_0_rgba(255,255,255,0.35)]">
                          <AiSparkle className="h-5 w-5" />
                        </span>
                        <h1 className="text-lg font-extrabold tracking-tight">Renance AI Studio</h1>
                      </div>
                      <p className="mt-2 text-[13px] font-semibold leading-relaxed text-white/95">
                        The study companion trained on Renance itself
                        {stats ? ` - ${stats.questions.toLocaleString()} real past questions across ${stats.exams} exam banks` : ' - 290,000+ real past questions'}
                        , the scheme of work and lesson notes. Ask it to teach, research past
                        questions, drill or mark you.
                      </p>
                    </div>
                    <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
                      {SUGGESTIONS.map((s) => (
                        <button
                          key={s}
                          type="button"
                          onClick={() => void send(s)}
                          className="rounded-xl border-2 border-outline-variant bg-card px-4 py-3 text-left text-[13px] font-semibold leading-snug text-on-surface shadow-[0_3px_0_0_var(--color-outline-variant)] transition hover:border-primary/60 hover:bg-surface-container-low active:translate-y-[2px] active:shadow-[0_1px_0_0_var(--color-outline-variant)]"
                        >
                          {s}
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {messages.map((m) => (
                  <ChatBubble key={m.id} m={m} onSaveNote={() => void saveMessageAsNote(m)} />
                ))}

                {busy && (
                  <div className="flex justify-start">
                    <div className="w-full max-w-md">
                      <PhaseTicker phases={CHAT_PHASES} />
                    </div>
                  </div>
                )}
                <div ref={endRef} />
              </div>

              {/* composer */}
              <div className="sticky bottom-16 border-t border-outline-variant/50 bg-surface-container-lowest/95 backdrop-blur md:bottom-0">
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    void send(draft);
                  }}
                  className="mx-auto flex w-full max-w-2xl items-center gap-2 px-4 py-3"
                >
                  <input
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    data-allow-select
                    placeholder="Ask, teach me, or show me past questions on..."
                    maxLength={4000}
                    className="h-11 min-w-0 flex-1 rounded-full border border-outline-variant bg-card px-4 text-[13.5px] text-on-surface placeholder:text-on-surface-variant focus:outline-none focus:ring-2 focus:ring-primary/40"
                  />
                  <button
                    type="submit"
                    disabled={busy || !draft.trim()}
                    aria-label="Send"
                    className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary text-on-primary transition active:scale-95 disabled:opacity-40"
                  >
                    <span className="material-symbols-outlined text-[20px]">arrow_upward</span>
                  </button>
                </form>
              </div>
            </>
          ) : (
            <div className="mx-auto w-full max-w-xl px-4 py-4">
              <div className="rounded-2xl border border-outline-variant/50 bg-card p-4 shadow-[0_1px_3px_0_rgba(20,28,45,0.06)]">
                <div className="mb-4 flex items-center gap-2">
                  <span className="material-symbols-outlined text-[20px] text-on-surface">
                    {TABS.find((t) => t.id === tab)?.icon}
                  </span>
                  <div>
                    <h2 className="text-[15px] font-semibold text-on-surface">{TABS.find((t) => t.id === tab)?.label} generator</h2>
                    <p className="text-[12px] text-on-surface-variant">Grounded on the real past-question corpus.</p>
                  </div>
                </div>
                <GeneratorForm
                  mode={tab}
                  busy={genBusy}
                  error={genError}
                  onBusy={setGenBusy}
                  onError={setGenError}
                  onResult={onGenerated}
                />
              </div>
              {artifact && (
                <button
                  type="button"
                  onClick={() => setCanvasOpen(true)}
                  className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl border-2 border-outline-variant bg-card py-3 text-[13px] font-extrabold text-on-surface shadow-[0_3px_0_0_var(--color-outline-variant)] transition hover:bg-surface-container-low active:translate-y-[2px] active:shadow-[0_1px_0_0_var(--color-outline-variant)] lg:hidden"
                >
                  <span className="material-symbols-outlined text-[17px]">right_panel_open</span>
                  Open {artifact.kind === 'quiz' ? 'quiz' : artifact.kind === 'notebook' ? 'notebook' : artifact.kind === 'lesson_note' ? 'lesson note' : 'note'} in canvas
                </button>
              )}
            </div>
          )}
        </main>

        {/* ------------------------- The canvas ------------------------- */}
        {artifact && canvasOpen && (
          <div className="fixed inset-0 z-40 flex flex-col bg-surface-container-lowest lg:static lg:z-0 lg:w-[460px] lg:shrink-0 lg:rounded-2xl lg:border lg:border-outline-variant/50 lg:bg-card lg:shadow-[0_1px_3px_0_rgba(20,28,45,0.08)]">
            <ArtifactCanvas
              artifact={artifact}
              onClose={() => setCanvasOpen(false)}
              onDeleted={() => {
                setArtifact(null);
                setCanvasOpen(false);
                void listArtifacts().then(setArtifacts).catch(() => {});
              }}
            />
          </div>
        )}
      </div>

      {/* toast */}
      {toast && (
        <div className="fixed bottom-24 left-1/2 z-50 -translate-x-1/2 rounded-full bg-primary px-4 py-2.5 text-[12.5px] font-semibold text-on-primary shadow-lg md:bottom-8">
          {toast}
        </div>
      )}

      <BottomNav />
    </div>
  );
}

function ChatBubble({ m, onSaveNote }: { m: StudioMessage; onSaveNote: () => void }) {
  const [copied, setCopied] = useState(false);
  if (m.role === 'user') {
    return (
      <div className="flex justify-end">
        <div className="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-br-md bg-primary px-4 py-2.5 text-[13.5px] leading-relaxed text-on-primary">
          {m.content}
        </div>
      </div>
    );
  }
  return (
    <div className="flex justify-start">
      <div className="max-w-[92%] rounded-2xl rounded-bl-md border border-outline-variant/60 bg-card px-4 py-3 text-[13.5px] leading-relaxed text-on-surface">
        {!!m.bridged && m.bridged > 0 && (
          <p className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-surface-container px-2.5 py-1 font-mono text-[9.5px] uppercase tracking-wider text-on-surface-variant">
            <span className="material-symbols-outlined text-[13px]">travel_explore</span>
            Grounded on {m.bridged} real past questions
          </p>
        )}
        {m.thinking && (
          <p className="mb-1.5 border-l-2 border-outline-variant/40 pl-2.5 text-[11.5px] italic leading-relaxed text-on-surface-variant">
            {m.thinking}
          </p>
        )}
        <div className="whitespace-pre-wrap">{m.content}</div>
        <div className="mt-2.5 flex gap-1">
          <button
            type="button"
            onClick={() => {
              void navigator.clipboard?.writeText(m.content);
              setCopied(true);
              window.setTimeout(() => setCopied(false), 1600);
            }}
            className="inline-flex items-center gap-1 rounded-full px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant transition hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-[13px]">{copied ? 'check' : 'content_copy'}</span>
            {copied ? 'Copied' : 'Copy'}
          </button>
          <button
            type="button"
            onClick={onSaveNote}
            className="inline-flex items-center gap-1 rounded-full px-2.5 py-1 font-mono text-[10px] uppercase tracking-wider text-on-surface-variant transition hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-[13px]">note_add</span>
            Save as note
          </button>
        </div>
      </div>
    </div>
  );
}

'use client';

/**
 * Arena WS client, the browser half of the multiplayer hub
 * (apps/study-api/internal/arena). One authenticated socket per match
 * session: queue → matched → question/result… → over. The access token
 * rides the ?token= query (browsers cannot set WS headers), the same
 * contract the server's ws.go documents.
 *
 * Frame shapes mirror internal/arena/message.go exactly.
 *
 * Founder bug report 2026-10-17: "the arena is completely broken" - the
 * hub itself was fine (the e2e probe played a full duel in prod), but the
 * socket died on Render's cold start and the page just showed a reload
 * banner. This client now heals itself: unexpected drops retry with a
 * capped backoff forever, the token is re-read fresh every attempt, and
 * the page learns about every state through onStatus.
 */

import { API_BASE } from './api';
import { getToken } from './session';

export interface ArenaQView {
  id: string;
  stem: string;
  options?: Record<string, string>;
  marks: number;
}

export type ArenaInbound =
  | { type: 'queued' }
  | { type: 'cancelled' }
  | {
      type: 'matched';
      matchId: string;
      opponent: string;
      code: string;
      body?: string;
      questionCount?: number;
      secondsPerQuestion?: number;
    }
  | { type: 'hosted'; code: string }
  | {
      type: 'challenge_sent';
      code: string;
      body?: string;
      opponent?: string;
    }
  | {
      type: 'challenge';
      code: string;
      body?: string;
      opponent: string; // the challenger's username
    }
  | {
      type: 'question';
      matchId?: string;
      // index 0 is the first question, tolerate older hubs that omit it
      index?: number;
      deadline: number;
      question: ArenaQView;
    }
  | {
      type: 'result';
      index?: number;
      correctLetter: string;
      solved: Record<string, boolean>;
    }
  | {
      type: 'over';
      matchId: string;
      winner: string;
      scores: Record<string, number>;
      opponent?: string;
    }
  | { type: 'error'; errorCode: string; message: string };

export type ArenaOutbound =
  | { type: 'queue'; body?: string }
  | { type: 'cancel' }
  | { type: 'answer'; index: number; letter: string }
  | { type: 'host'; body?: string }
  | { type: 'join'; code: string }
  | { type: 'challenge'; target: string; body?: string };

/** http(s):// → ws(s):// for the socket endpoint. */
export function arenaWsUrl(token: string): string {
  const url = API_BASE.replace(/^http/, 'ws');
  return `${url}/arena/ws?token=${encodeURIComponent(token)}`;
}

/** Where the session's socket is, reported to the page on every change. */
export type ArenaStatus = 'connecting' | 'open' | 'retrying';

export type ArenaHandlers = {
  onFrame: (frame: ArenaInbound) => void;
  /** Fires on EVERY successful open - first connect and every heal. */
  onOpen?: () => void;
  onStatus?: (status: ArenaStatus, attempt: number) => void;
  /** No token at all (signed out) - never retries. */
  onFatal?: () => void;
};

/** Backoff ladder for self-healing, seconds. Capped at the last rung. */
const RETRY_SECONDS = [1, 2, 4, 8, 12];

/**
 * One arena session that heals itself. send() is safe before the socket
 * opens (queued until onopen) and safe while retrying. close() on
 * unmount stops every retry.
 */
export class ArenaSocket {
  private ws: WebSocket | null = null;
  private outbox: ArenaOutbound[] = [];
  private closedByUs = false;
  private retryTimer: number | null = null;
  private attempt = 0;

  constructor(private handlers: ArenaHandlers) {
    if (!getToken()) {
      // api() would redirect on 401; the socket just reports fatal.
      handlers.onFatal?.();
      return;
    }
    this.connect();
  }

  private connect(): void {
    if (this.closedByUs) return;
    const token = getToken();
    if (!token) {
      this.handlers.onFatal?.();
      return;
    }
    this.handlers.onStatus?.(this.attempt === 0 ? 'connecting' : 'retrying', this.attempt);
    let ws: WebSocket;
    try {
      ws = new WebSocket(arenaWsUrl(token));
    } catch {
      this.scheduleRetry();
      return;
    }
    this.ws = ws;
    ws.onopen = () => {
      if (this.closedByUs) {
        ws.close();
        return;
      }
      this.attempt = 0;
      for (const frame of this.outbox) ws.send(JSON.stringify(frame));
      this.outbox = [];
      this.handlers.onStatus?.('open', 0);
      this.handlers.onOpen?.();
    };
    ws.onmessage = (ev) => {
      try {
        this.handlers.onFrame(JSON.parse(ev.data as string) as ArenaInbound);
      } catch {
        /* malformed frame: ignore, the hub never sends one */
      }
    };
    ws.onclose = () => {
      if (this.closedByUs) return;
      this.ws = null;
      // The hub detaches the session on drop; heal the transport so the
      // student never has to reload the page (Render cold starts, dorm
      // wifi, tunnel rides - the arena comes back on its own).
      this.scheduleRetry();
    };
    ws.onerror = () => {
      /* onclose follows */
    };
  }

  private scheduleRetry(): void {
    if (this.closedByUs || this.retryTimer !== null) return;
    const wait = RETRY_SECONDS[Math.min(this.attempt, RETRY_SECONDS.length - 1)];
    this.attempt += 1;
    this.handlers.onStatus?.('retrying', this.attempt);
    this.retryTimer = window.setTimeout(() => {
      this.retryTimer = null;
      this.connect();
    }, wait * 1000);
  }

  send(frame: ArenaOutbound): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(frame));
      return;
    }
    // Waiting intents queue while the socket heals. One live intent per
    // kind: tapping "Host a room" twice while offline replaces the first
    // frame instead of spawning two rooms on flush.
    if (frame.type === 'queue' || frame.type === 'host') {
      this.outbox = this.outbox.filter((f) => f.type !== frame.type);
    }
    this.outbox.push(frame);
  }

  close(): void {
    this.closedByUs = true;
    if (this.retryTimer !== null) {
      window.clearTimeout(this.retryTimer);
      this.retryTimer = null;
    }
    this.ws?.close();
    this.ws = null;
  }
}

'use client';

/**
 * Arena WS client — the browser half of the multiplayer hub
 * (apps/study-api/internal/arena). One authenticated socket per match
 * session: queue → matched → question/result… → over. The access token
 * rides the ?token= query (browsers cannot set WS headers), the same
 * contract the server's ws.go documents.
 *
 * Frame shapes mirror internal/arena/message.go exactly.
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
      type: 'question';
      matchId?: string;
      // index 0 is the first question — tolerate older hubs that omit it
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
  | { type: 'join'; code: string };

/** http(s):// → ws(s):// for the socket endpoint. */
export function arenaWsUrl(token: string): string {
  const url = API_BASE.replace(/^http/, 'ws');
  return `${url}/arena/ws?token=${encodeURIComponent(token)}`;
}

export type ArenaHandlers = {
  onFrame: (frame: ArenaInbound) => void;
  onOpen?: () => void;
  onDown?: () => void; // socket closed / failed
};

/**
 * One arena session. send() is safe before the socket opens (queued
 * until onopen). close() on unmount; the server sweeps abandoned rooms.
 */
export class ArenaSocket {
  private ws: WebSocket | null = null;
  private outbox: ArenaOutbound[] = [];
  private closedByUs = false;

  constructor(handlers: ArenaHandlers) {
    const token = getToken();
    if (!token) {
      // api() would redirect on 401; the socket just reports down.
      handlers.onDown?.();
      return;
    }
    let ws: WebSocket;
    try {
      ws = new WebSocket(arenaWsUrl(token));
    } catch {
      handlers.onDown?.();
      return;
    }
    this.ws = ws;
    ws.onopen = () => {
      for (const frame of this.outbox) ws.send(JSON.stringify(frame));
      this.outbox = [];
      handlers.onOpen?.();
    };
    ws.onmessage = (ev) => {
      try {
        handlers.onFrame(JSON.parse(ev.data as string) as ArenaInbound);
      } catch {
        /* malformed frame: ignore, the hub never sends one */
      }
    };
    ws.onclose = () => {
      if (!this.closedByUs) handlers.onDown?.();
    };
    ws.onerror = () => {
      /* onclose follows */
    };
  }

  send(frame: ArenaOutbound): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(frame));
    } else {
      this.outbox.push(frame);
    }
  }

  close(): void {
    this.closedByUs = true;
    this.ws?.close();
    this.ws = null;
  }
}

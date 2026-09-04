/**
 * Flashcards (ROADMAP #7) — types, fetchers and the pure Leitner rule,
 * mirrored from the Go store so the web shuffles on the same schedule
 * as the app.
 */
import { api } from './api';

export interface FlashcardCard {
  id: string;
  front: string;
  back: string;
  hint?: string;
}

export interface FlashcardDeckMeta {
  code: string;
  title: string;
  cardCount: number;
  subject?: string;
  body?: string;
}

export interface FlashcardDeck extends FlashcardDeckMeta {
  cards: FlashcardCard[];
}

export interface CardProgress {
  cardId: string;
  deckCode: string;
  box: number;
  correct: number;
  wrong: number;
  dueOn: string; // YYYY-MM-DD (UTC)
  lastGrade: string; // again | hard | good
}

export interface FlashcardGrade {
  cardId: string;
  deckCode: string;
  grade: 'again' | 'hard' | 'good';
}

/** Leitner box intervals (days) per box — mirror of store.CardBoxIntervals. */
export const CARD_BOX_INTERVALS = [0, 0, 1, 2, 4, 7]; // index 0 unused

/** Pure Leitner rule — mirror of store.NextCardBox. */
export function nextCardBox(box: number, grade: string): number {
  switch (grade) {
    case 'again':
      return 1;
    case 'good':
      return box >= 5 ? 5 : box + 1;
    default: // 'hard' and unknown grades hold position
      return box < 1 ? 1 : box;
  }
}

/** Pure interval lookup — mirror of store.CardIntervalDays. */
export function cardIntervalDays(box: number): number {
  const b = box < 1 ? 1 : box > 5 ? 5 : box;
  return CARD_BOX_INTERVALS[b];
}

export async function fetchDecks(): Promise<FlashcardDeckMeta[]> {
  const data = await api<{ decks: FlashcardDeckMeta[] }>('/flashcards');
  return data.decks ?? [];
}

export async function fetchDeck(code: string): Promise<FlashcardDeck> {
  return api<FlashcardDeck>(`/flashcards/${encodeURIComponent(code)}`);
}

export async function fetchCardProgress(): Promise<CardProgress[]> {
  const data = await api<{ progress: CardProgress[] }>('/me/cards/progress');
  return data.progress ?? [];
}

export async function postCardGrades(
  grades: FlashcardGrade[],
): Promise<CardProgress[]> {
  const data = await api<{ progress: CardProgress[] }>('/me/cards/progress', {
    method: 'POST',
    body: { grades },
  });
  return data.progress ?? [];
}

/**
 * Voice flashcards (ROADMAP #7) — browser speech synthesis. Like the
 * app's on-device TTS: recording-free, no microphone permission, and the
 * browser's local voices work offline. Voice is an enhancement — every
 * call is a safe no-op when the browser has no speech engine.
 */

export function speechSupported(): boolean {
  return typeof window !== 'undefined' && 'speechSynthesis' in window;
}

/** Speaks [text], replacing anything currently being spoken. */
export function speak(text: string): void {
  if (!speechSupported()) return;
  const t = text.trim();
  if (!t) return;
  try {
    window.speechSynthesis.cancel();
    const utter = new SpeechSynthesisUtterance(t);
    utter.lang = 'en-US';
    utter.rate = 1;
    utter.pitch = 1;
    window.speechSynthesis.speak(utter);
  } catch {
    // No voices available — the visual card still carries the study.
  }
}

export function stopSpeaking(): void {
  if (!speechSupported()) return;
  try {
    window.speechSynthesis.cancel();
  } catch {
    // ignore
  }
}

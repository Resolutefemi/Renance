'use client';

import { useEffect, useState } from 'react';
import { speak, speechSupported, stopSpeaking } from '@/lib/speech';

/**
 * Audio summaries (ROADMAP #11), web slice: narrates the lesson's spoken
 * summary with the browser's local speech synthesis — the same words the
 * app speaks (apps/mobile/lib/audio_summary.dart). Hidden entirely when
 * the browser has no speech engine; voice is an enhancement, the reader
 * page carries the study.
 */
export function ListenSummary({ script }: { script: string }) {
  const [supported, setSupported] = useState(false);
  const [playing, setPlaying] = useState(false);

  useEffect(() => {
    setSupported(speechSupported());
    return () => stopSpeaking();
  }, []);

  // A lesson change swaps the script: silence whatever is mid-flight so
  // the pill never claims to play lesson A's voice over lesson B.
  useEffect(() => {
    stopSpeaking();
    setPlaying(false);
  }, [script]);

  if (!supported) return null;

  const toggle = () => {
    if (playing) {
      stopSpeaking();
      setPlaying(false);
      return;
    }
    speak(script);
    setPlaying(true);
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={playing ? 'Stop the lesson summary' : 'Listen to the lesson summary'}
      className="inline-flex items-center gap-1.5 rounded-full bg-surface-container-low px-3.5 py-1.5 text-[12px] font-medium text-on-surface transition hover:bg-surface-container"
    >
      <span className="material-symbols-outlined text-[16px]" aria-hidden="true">
        {playing ? 'stop' : 'volume_up'}
      </span>
      {playing ? 'Stop summary' : 'Listen to summary'}
    </button>
  );
}

'use client';

/**
 * Bundle store — IndexedDB-backed cache for exam bundles (question banks
 * and composed papers), replacing the localStorage cache that blew past
 * the ~5MB origin quota ("Failed to execute 'setItem' … exceeded the
 * quota" on jamb-english-bank, a multi-megabyte JSON).
 *
 * IndexedDB exposes hundreds of megabytes on every modern browser, so
 * the full 37-subject archive fits. Every accessor is failure-tolerant:
 * private mode, disabled storage or a full disk degrade to "no cache",
 * never to a crash. Old localStorage keys (renance.bundle.*) are
 * migrated in and deleted the first time the store opens, healing
 * devices that already hit the quota.
 *
 * Sha-pinned entries keep the same self-healing property as before: a
 * re-published bank lands under its new sha and the stale copy becomes
 * unreachable dead weight (and gets swept by the same migration pass).
 */

const DB_NAME = 'renance-bundles';
const DB_VERSION = 1;
const STORE = 'bundles';
const LS_PREFIX = 'renance.bundle.';

let dbPromise: Promise<IDBDatabase | null> | null = null;

function openDB(): Promise<IDBDatabase | null> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve) => {
    try {
      if (typeof indexedDB === 'undefined') return resolve(null);
      const req = indexedDB.open(DB_NAME, DB_VERSION);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE);
      };
      req.onsuccess = () => {
        const db = req.result;
        db.onversionchange = () => db.close(); // another tab upgraded
        resolve(db);
      };
      req.onerror = () => resolve(null);
      req.onblocked = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
  return dbPromise;
}

/** Read one bundle JSON (by cache key) from IndexedDB. */
export async function idbGetBundle(key: string): Promise<unknown | null> {
  const db = await openDB();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE, 'readonly');
      const req = tx.objectStore(STORE).get(key);
      req.onsuccess = () => resolve(req.result ?? null);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

/** Write one bundle JSON. Best-effort: quota or privacy failures are silent. */
export async function idbSetBundle(key: string, value: unknown): Promise<void> {
  const db = await openDB();
  if (!db) return;
  await new Promise<void>((resolve) => {
    try {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(value, key);
      tx.oncomplete = () => resolve();
      tx.onabort = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

/** Drop every cached bundle (Settings "clear offline packs" also uses this). */
export async function idbClearBundles(): Promise<void> {
  const db = await openDB();
  if (!db) return;
  await new Promise<void>((resolve) => {
    try {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

/**
 * One-time migration: every bundle the old localStorage cache managed
 * to store moves into IndexedDB and the localStorage key is deleted.
 * This is what un-bricks devices already stuck over quota — the stuck
 * keys are exactly the ones blocking all other writes. Safe to call
 * repeatedly; cheap when there is nothing left to move.
 */
export async function migrateLocalStorageBundles(): Promise<void> {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return;
    const keys: string[] = [];
    for (let i = 0; i < window.localStorage.length; i++) {
      const k = window.localStorage.key(i);
      if (k && k.startsWith(LS_PREFIX)) keys.push(k);
    }
    if (!keys.length) return;
    for (const k of keys) {
      try {
        const raw = window.localStorage.getItem(k);
        if (raw) {
          try {
            await idbSetBundle(k, JSON.parse(raw));
          } catch {
            /* unparsable: dropping it is the right outcome */
          }
        }
        window.localStorage.removeItem(k);
      } catch {
        /* private mode: leave it, nothing else we can do here */
      }
    }
  } catch {
    /* never let migration break app boot */
  }
}

/** Storage estimate for the Settings page, when the browser exposes it. */
export async function storageEstimate(): Promise<{ usage: number; quota: number } | null> {
  try {
    if (typeof navigator !== 'undefined' && navigator.storage?.estimate) {
      const est = await navigator.storage.estimate();
      return { usage: est.usage ?? 0, quota: est.quota ?? 0 };
    }
  } catch {
    /* ignore */
  }
  return null;
}

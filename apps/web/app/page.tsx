import { MODULE_REGISTRY } from '@renance/shared';

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

export default function Home() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <h1 className="text-4xl font-semibold tracking-tight">Renance</h1>
      <p className="mt-3 text-neutral-400">
        Phase 0 scaffold is live. API health:{' '}
        <a
          className="text-orange-400 underline underline-offset-4"
          href={`${apiUrl}/api/v1/health`}
        >
          {apiUrl}/api/v1/health
        </a>
      </p>

      <section className="mt-10 grid grid-cols-1 gap-3 sm:grid-cols-2">
        {MODULE_REGISTRY.map((m) => (
          <div key={m.id} className="rounded-lg border border-neutral-800 bg-neutral-900 p-4">
            <div className="flex items-center justify-between">
              <span className="font-medium">{m.title}</span>
              <span className="rounded bg-orange-500/10 px-2 py-0.5 text-xs text-orange-300">
                Phase {m.phase}
              </span>
            </div>
            <p className="mt-1 text-xs text-neutral-500">dormant until its phase opens</p>
          </div>
        ))}
      </section>

      <footer className="mt-12 text-xs text-neutral-600">
        docs/architecture.md defines the boundary contract — read it once, save hours later.
      </footer>
    </main>
  );
}

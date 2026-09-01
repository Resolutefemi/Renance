import { readFileSync } from 'node:fs';
import postgres from 'postgres';
const { uris } = JSON.parse(readFileSync('/tmp/neon_env.json', 'utf8'));
const sqlp = postgres(Object.entries(uris).find(([, l]) => l === 'direct')[0], { prepare: false, max: 1 });
const rows = await sqlp`select id, email, display_name, status, created_at from core.users order by created_at`;
console.log('LIVE Neon core.users count:', rows.length);
rows.forEach(r => console.log(' ->', r.email, '|', r.display_name, '|', r.status));
await sqlp.end();

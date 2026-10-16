#!/usr/bin/env python3
"""Update the INSFORGE_DATABASE_URL Actions secret to InsForge #1
(the cache+mirror home after the 2026-10-16 move) and delete the three
empty content-shard repos the founder asked to remove."""
import base64
import json
import urllib.request

TOKEN = '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'
REPO = 'Resolutefemi/Renance'
IF1_DSN = 'postgresql://postgres:8261cb984054ff872330f6b73200eb99@dbeqj4dx.us-east.database.insforge.app:5432/insforge?sslmode=require'

def api(method, path, body=None, raw=False):
    req = urllib.request.Request(f'https://api.github.com{path}', method=method)
    req.add_header('Authorization', f'Bearer {TOKEN}')
    req.add_header('Accept', 'application/vnd.github+json')
    data = None
    if body is not None:
        data = json.dumps(body).encode() if not raw else body
        req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, data=data) as r:
            txt = r.read()
            return r.status, (txt.decode() if txt else '')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]

# 1. Secret update via libsodium sealed box
from nacl import encoding, public
pk_resp = api('GET', f'/repos/{REPO}/actions/secrets/public-key')
status, body = pk_resp
assert status == 200, f'public-key failed: {status} {body}'
key = json.loads(body)
pk = public.PublicKey(key['key'].encode(), encoding.Base64Encoder())
sealed = public.SealedBox(pk).encrypt(IF1_DSN.encode())
st, _ = api('PUT', f'/repos/{REPO}/actions/secrets/INSFORGE_DATABASE_URL',
            {'encrypted_value': base64.b64encode(sealed).decode(), 'key_id': key['key_id']})
print('INSFORGE_DATABASE_URL secret updated:', st)

# 2. Delete the empty shard repos
for name in ['renance-content-1', 'renance-content-2', 'renance-content-3']:
    st, body = api('DELETE', f'/repos/Resolutefemi/{name}')
    print(f'delete {name}:', st, '' if st == 204 else body[:120])

# 3. Verify they are gone
st, body = api('GET', '/users/Resolutefemi/repos?per_page=100&sort=created')
names = [r['name'] for r in json.loads(body)]
print('remaining repos:', names)
print('shards gone:', all(n not in names for n in ['renance-content-1', 'renance-content-2', 'renance-content-3']))

"""Package ONLY the compiled sample UI, guide, destination and generated media."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

build, destination = map(Path, sys.argv[1:3])
if destination.exists():
    raise SystemExit('Use a fresh output directory')
www = destination / 'www'
shutil.copytree(build, www/'app', ignore=shutil.ignore_patterns('*.map'))
(www/'media').mkdir()
subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc2=size=160x90:rate=15',
                '-t','8','-an','-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',
                str(www/'media/sample.mp4')],check=True)
(www/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Private TV2 sample review</title><style>body{font:18px system-ui;max-width:42rem;margin:2rem auto;padding:1rem;line-height:1.5}a{display:inline-block;padding:1rem;background:#182a35;color:white;border-radius:1rem}</style>
<h1>A business introduction from one List Number</h1><p>Let visitors discover a business, watch its introduction and open its website.</p>
<p><strong>Private review • sample data only.</strong> These two listings are synthetic, not real assignments. Browsing requires no account or payment.</p>
<p>Business: <strong>1*700001</strong> — Northstar (sample)</p><p>Personal: <strong>1*70002</strong> — Alex (sample)</p>
<p>Choose +1 and enter the number, or enter its full qualified form. ENTER opens the listing; selecting a suggestion only fills the number.</p>
<a href="/app/">Open List Number TV2</a><p>No signup, owner upload, contact sends, purchases or waitlist are available in this sample.</p></html>''')
(www/'sample-website.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Northstar sample website</title><style>body{font:18px system-ui;max-width:40rem;padding:1.5rem;line-height:1.5}</style>
<h1>Northstar Workshop</h1><p>Synthetic sample website. No real business, contacts or transactions.</p>
<p>Close this tab to return to the same listing in TV2.</p><a href="/">Private review guide</a></html>''')
(destination/'README.txt').write_text('''PRIVATE READ-ONLY TV2 SAMPLE PACKAGE
Serve www/ at the root of an approved OWNER-PRIVATE HTTPS origin. The phone opens that origin's / guide, then /app/.
No server API, credentials, sessions, upload handler, database or production resolver is included. Resolver responses come from two bundled synthetic records in the actual Flutter app.
This archive is NOT a published phone link. The host must enforce owner-only access for ALL assets including MP4; the archive itself contains no authentication. Do not publicly publish or grant access without separate approval.
The host needs GET/HEAD static files, correct MIME types (.wasm application/wasm, .js text/javascript, .mp4 video/mp4), MP4 single-byte Range 206/416, and no-store headers. Reject writes; do not add CORS exceptions. No external runtime assets should be fetched. Mount at origin root (not a subpath).
The app fails closed on HTTP, file://, localhost and numeric-IP origins. It accepts valid HTTPS DNS origins, derives video and website URLs from its own origin and makes no production API calls. This is portable across approved private hosts, not permission to publish anywhere.
Video is an eight-second locally generated test pattern, not a business endorsement. Phone/installed-PWA behavior remains physically unverified. Do not treat the read-only sample as business onboarding or production ownership/storage.
''')
# Restrict inventory to web build assets, with no source maps, keys or executables.
for p in www.rglob('*'):
    if p.is_symlink(): raise SystemExit('Symlink rejected')
    if p.is_file():
        if p.suffix in ('.dart','.py','.pem','.key','.env','.map','.zip'):
            raise SystemExit(f'Unexpected file: {p.name}')
        if p.suffix in ('.js','.json','.html','.txt'):
            data=p.read_bytes()
            for denied in (b'tv2-development.onrender.com',b'supabase.co',b'local_owner',b'X-Local-CSRF'):
                if denied in data: raise SystemExit(f'Forbidden runtime reference: {p.name}')
files=sorted(p for p in destination.rglob('*') if p.is_file())
manifest={str(p.relative_to(destination)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
(destination/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=destination.with_suffix('.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in sorted(destination.rglob('*')):
        if p.is_file(): z.write(p,p.relative_to(destination))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert set(z.namelist()) == set(manifest) | {'MANIFEST.json'}
print(json.dumps({'archive':str(archive),'files':len(manifest)+1,'bytes':archive.stat().st_size,
                  'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}))

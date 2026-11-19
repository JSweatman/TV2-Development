"""Package ONLY the compiled sample UI, guide, destination and generated media."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile
from northstar_content import make_intro, TRANSCRIPT

build, destination = map(Path, sys.argv[1:3])
if destination.exists():
    raise SystemExit('Use a fresh output directory')
www = destination / 'www'
shutil.copytree(build, www/'app', ignore=shutil.ignore_patterns('*.map'))
(www/'media').mkdir()
make_intro(www/'media/sample.mp4')
(www/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Private TV2 sample review</title><style>body{font:18px system-ui;max-width:42rem;margin:2rem auto;padding:1rem;line-height:1.5}a{display:inline-block;padding:1rem;background:#182a35;color:white;border-radius:1rem}</style>
<h1>Meet Northstar Workshop</h1><p>A first woodwork class: make a small shelf and find out what to bring.</p>
<p><strong>Private review • sample data only.</strong> Northstar and Alex are fictional. Browsing needs no TV2 account or payment.</p>
<p>Open List Number TV2. Choose +1, type <strong>700001</strong>, and press ENTER to see Northstar Workshop.</p>
<a href="/app/">Open List Number TV2</a>
<details><summary>Other ways to try the sample</summary><p>Full number: <strong>1*700001</strong>. Selecting a name fills the number; ENTER opens the page.</p><p>Personal / 10E sample: <strong>1*70002</strong> — Alex's bio, small projects and favorite things.</p></details>
<p>No booking, signup, contact sends, purchase or waitlist is offered.</p></html>''')
(www/'sample-website.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Northstar Workshop — class notes</title><style>body{font:18px system-ui;max-width:40rem;margin:auto;padding:1.5rem;line-height:1.6;background:#f8f6ed;color:#203d37}h1,h2{line-height:1.2}a{color:inherit}section{padding-top:1rem}</style>
<p>Fictional sample class • 1*700001</p><h1>Northstar Workshop</h1>
<p>Try your first woodwork class. Make a small shelf with a tutor who guides each step. No past skill is needed.</p>
<section aria-labelledby="bring"><h2 id="bring">What should I bring?</h2><p><strong>Bring closed-toe shoes and a water bottle.</strong></p><p>We supply the wood, tools and eye protection.</p></section>
<section aria-labelledby="transcript"><h2 id="transcript">Words from the video</h2><p>''' + TRANSCRIPT + '''</p></section>
<p>This is a fictional class for private review. There is no real class date, booking, payment or contact form.</p>
<p>Close this tab to return to the same listing in TV2.</p><a href="/">Private review guide</a></html>''')
(www/'alex.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Alex's sample notebook</title><style>body{font:18px system-ui;max-width:40rem;margin:auto;padding:1.5rem;line-height:1.6;background:#f8f6ed;color:#203d37}nav{display:flex;flex-wrap:wrap;gap:.75rem}nav a{padding:.75rem 1rem;background:#dfebe3;border-radius:1rem;color:inherit}section{padding-top:1rem}a:focus-visible{outline:3px solid #203d37;outline-offset:3px}</style>
<header><p>Fictional sample personal page • 1*70002</p><h1>Alex's notebook</h1>
<p>A small corner for a personal introduction, things to make and things to enjoy.</p></header>
<nav aria-label="Alex's bio links"><a href="#about">About Alex</a><a href="#projects">Small projects</a><a href="#favorites">Favorite things</a></nav>
<main><section id="about"><h2>About Alex</h2><p>Alex is an invented person for this TV2 review: a curious walker, sketchbook keeper and weekend maker. This page shows how a personal List Number can lead to a useful collection of links.</p></section>
<section id="projects"><h2>Small projects</h2><ul><li><strong>A five-minute sketch:</strong> choose an everyday object, draw its outline, then add one detail.</li><li><strong>A neighborhood notebook:</strong> make a page with three things noticed on a walk: a shape, a sound and a color.</li></ul></section>
<section id="favorites"><h2>Favorite things</h2><p>Sample favorites: pocket notebooks, quiet walking routes, homemade postcards and swapping book recommendations.</p></section></main>
<footer><p>These are fictional examples, not real personal details. No contact, signup or transaction is offered.</p><p>Close this tab to return to Alex's listing in TV2.</p><a href="/">Private review guide</a></footer></html>''')
(destination/'README.txt').write_text('''PRIVATE READ-ONLY TV2 SAMPLE PACKAGE
Serve www/ at the root of an approved OWNER-PRIVATE HTTPS origin. The phone opens that origin's / guide, then /app/.
No server API, credentials, sessions, upload handler, database or production resolver is included. Resolver responses come from two bundled synthetic records in the actual Flutter app.
This archive is NOT a published phone link. The host must enforce owner-only access for ALL assets including MP4; the archive itself contains no authentication. Do not publicly publish or grant access without separate approval.
The host needs GET/HEAD static files, correct MIME types (.wasm application/wasm, .js text/javascript, .mp4 video/mp4), MP4 single-byte Range 206/416, and no-store headers. Reject writes; do not add CORS exceptions. No external runtime assets should be fetched. Mount at origin root (not a subpath).
The app fails closed on HTTP, file://, localhost and numeric-IP origins. It accepts valid HTTPS DNS origins, derives video and website URLs from its own origin and makes no production API calls. This is portable across approved private hosts, not permission to publish anywhere.
Video is a 16-second locally generated silent, captioned introduction to a fictional class. Its accessible transcript is on the sample WEBSITE under Words from the video. Phone/installed-PWA behavior remains physically unverified. Do not treat the read-only sample as business onboarding or production ownership/storage.
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

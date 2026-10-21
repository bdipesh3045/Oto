#!/usr/bin/env python3
"""Bundle the current official yt-dlp zipapp after checking published SHA-256."""
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parents[1]
release = json.load(urllib.request.urlopen('https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest', timeout=30))
assets = {asset['name']: asset for asset in release['assets']}
asset = assets['yt-dlp']
content = urllib.request.urlopen(asset['browser_download_url'], timeout=60).read()
checksums = urllib.request.urlopen(assets['SHA2-256SUMS']['browser_download_url'], timeout=30).read().decode()
expected = next(line.split()[0] for line in checksums.splitlines() if line.split()[-1].lstrip('*') == 'yt-dlp')
assert hashlib.sha256(content).hexdigest() == expected, 'Engine checksum mismatch'
metadata = json.dumps({'version': release['tag_name'], 'url': asset['browser_download_url'], 'sha256': expected}, indent=2) + '\n'
(root / 'android/app/src/main/res/raw/ytdlp').write_bytes(content)
(root / 'android/app/src/main/assets/bundled-engine.json').write_text(metadata)
(root / 'tools/bundled-engine.json').write_text(metadata)
print('Bundled official yt-dlp', release['tag_name'])

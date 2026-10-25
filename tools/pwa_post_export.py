#!/usr/bin/env python3
"""Post-process a Godot Web export into a proper installable PWA.

Godot 4.3 writes a manifest and a service worker, but only *registers* the
worker when the build needs cross-origin isolation (i.e. when threads are
enabled). This build is single-threaded, so nothing would ever register the
worker and the app would never be installable or work offline.

This script:
  1. injects the service-worker registration,
  2. prunes the worker's precache list to files that actually exist
     (Godot lists index.worker.js even in thread-less builds, and one 404 makes
     cache.addAll() reject, which silently kills the whole install),
  3. adds the theme-colour / iOS meta tags.

Usage: python3 tools/pwa_post_export.py build/web
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

REGISTER_SCRIPT = """
		<script>
			// neon-velocity: register the service worker ourselves, because Godot only
			// auto-registers it when the build needs cross-origin isolation and this
			// build is single-threaded.
			window.addEventListener('load', function () {
				if (!('serviceWorker' in navigator) || typeof engine === 'undefined' || !engine.installServiceWorker) {
					return;
				}
				engine.installServiceWorker().catch(function (err) {
					console.warn('Service worker registration failed:', err);
				});
			});
		</script>
"""

FULLSCREEN_SCRIPT = """
		<script>
			// neon-velocity: on a touch device, the first tap goes fullscreen and
			// asks for landscape, which is the only comfortable way to play this
			// on a phone. Both calls are optional and fail quietly in browsers
			// that refuse them without a user gesture.
			(function () {
				var coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
				if (!coarse) { return; }
				function enter() {
					var el = document.documentElement;
					if (el.requestFullscreen) { el.requestFullscreen().catch(function () {}); }
					if (screen.orientation && screen.orientation.lock) {
						screen.orientation.lock('landscape').catch(function () {});
					}
					window.removeEventListener('pointerdown', enter);
				}
				window.addEventListener('pointerdown', enter);
			})();
		</script>
"""

META_TAGS = """		<meta name="theme-color" content="#29adff">
		<meta name="apple-mobile-web-app-capable" content="yes">
		<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
		<meta name="description" content="Neon Velocity - a procedurally generated retro side-scrolling shooter. All art and audio are generated at runtime.">
"""


def prune_precache(worker: pathlib.Path, web_dir: pathlib.Path) -> tuple[int, int]:
    """Drop precache entries that are not in the export."""
    text = worker.read_text(encoding="utf-8")
    match = re.search(r"const CACHED_FILES = \[(.*?)\];", text, re.S)
    if not match:
        return (0, 0)
    listed = re.findall(r'"([^"]+)"', match.group(1))
    present = [name for name in listed if (web_dir / name).is_file()]
    missing = [name for name in listed if name not in present]
    if missing:
        replacement = "const CACHED_FILES = [%s];" % ", ".join(json.dumps(n) for n in present)
        text = text[: match.start()] + replacement + text[match.end() :]
        worker.write_text(text, encoding="utf-8")
    return (len(present), len(missing))


def main() -> int:
    web_dir = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    index = web_dir / "index.html"
    worker = web_dir / "index.service.worker.js"
    manifest = web_dir / "index.manifest.json"

    for required in (index, worker, manifest):
        if not required.is_file():
            print(f"missing {required} - run the Web export first", file=sys.stderr)
            return 1

    html = index.read_text(encoding="utf-8")
    html = html.replace(
        'content="width=device-width, user-scalable=no, initial-scale=1.0"',
        'content="width=device-width, user-scalable=no, initial-scale=1.0, viewport-fit=cover"',
    )

    if "apple-mobile-web-app-capable" not in html:
        html = html.replace("\t</head>", META_TAGS + "\t</head>", 1)

    if "neon-velocity: on a touch device" not in html:
        html = html.replace("\t</body>", FULLSCREEN_SCRIPT + "\t</body>", 1)

    if "neon-velocity: register the service worker" not in html:
        html = html.replace("\t</body>", REGISTER_SCRIPT + "\t</body>", 1)

    index.write_text(html, encoding="utf-8")

    kept, dropped = prune_precache(worker, web_dir)
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data.setdefault("short_name", "Neon Velocity")
    data.setdefault("lang", "en")
    data["icons"] = [
        {"src": icon["src"], "sizes": icon["sizes"], "type": icon["type"], "purpose": "any"}
        for icon in data.get("icons", [])
    ]
    manifest.write_text(json.dumps(data, indent=2), encoding="utf-8")

    print(f"PWA patched: precache kept {kept} file(s), dropped {dropped} missing")
    print(f"  manifest: {manifest.name}  display={data.get('display')}  icons={len(data['icons'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# Pre-release audit

What has been verified, how, and what is still open. Every "verified" line below
was produced by running the project, not by reading it.

Engine: **Godot 4.3.stable.official.77dcf97d8**, headless, `gl_compatibility`.

## Verification performed

| # | Check | Method | Result |
|---|-------|--------|--------|
| 1 | Project imports | `godot --headless --path . --import` | clean, no script or resource errors |
| 2 | Every script parses | same command (Godot compiles all scripts on import) | clean |
| 3 | Shaders compile | same command (Godot compiles shaders even with the dummy renderer) | clean |
| 4 | Title screen boots | `--quit-after 180` | clean |
| 5 | Full gameplay loop | `TestRunner.tscn`, 27 assertions | PASS 27/27 |
| 6 | Procedural sprites generate | `dump_sprites` tool → 17 PNGs inspected | correct sizes, palette only |
| 7 | Procedural audio generates | SFX bank asserts in test (`shoot_plasma`, `boss_death`) | present, non-empty PCM |
| 8 | Enemies spawn and die | 7 s of synthetic input, `kills > 0` | PASS |
| 9 | Player fires and scores | `shots_fired > 0`, `score` increases | PASS |
| 10 | Boss spawns on chunk 4 | teleport player to chunk 4, search `enemies` group | PASS |
| 11 | Damage and death | `take_damage()` lowers HP; lethal hit emits `game_over` | PASS |
| 12 | Save round-trip | write then read `user://save_game.save` | PASS |
| 13 | Mod application | `spread_wide` adds a projectile (5 → 6) | PASS |
| 14 | Replay recording | `ReplaySystem.frame_count() > 0` after a run | PASS |
| 15 | 50-second soak (chunk 0 → 7, boss at 4) | `SoakTest.tscn`, 3 consecutive runs | no errors, score 450–540, ~20 kills, 217 peak live bullets |
| 16 | Pool growth under load | soak with 320 enemy + 220 player bullets preallocated | no "flushing queries" errors after the deferred-monitoring fix |
| 17 | Exported Linux build boots | `build/linux/NeonVelocity.x86_64 --headless --quit-after 150` | clean |
| 18 | Web export builds | `--export-release "Web"` + `tools/pwa_post_export.py` | 11 files, 35 MB wasm |
| 19 | Web build boots in a real browser | headless Chrome 153 (SwiftShader WebGL2), waiting for the loading overlay to clear | booted, canvas live, no console errors |
| 20 | Menu, gameplay, pause screens render | Puppeteer screenshots at 1280x720 | reviewed; contrast, parallax and HUD issues found and fixed |
| 21 | PWA assets | manifest (standalone, 3 icons), service worker precache pruned to real files | present and consistent |
| 22 | macOS export | `--export-release "macOS"` (unsigned, needs ETC2/ASTC enabled) | 51 MB .app.zip |

## Checklist

### Content
- [x] Six weapons, each with five levels and XP
- [x] 18 mods, all with working effects
- [x] Four bosses with phase changes and distinct patterns
- [x] Five pickup types
- [x] Endless chunk streaming, seeded per run
- [x] Four-layer adaptive music, intensity follows chunk depth
- [x] 24 sound effects, all procedural
- [x] Every sprite procedural (17 generators)
- [ ] Embedded pixel font — **cut**, the brief's base64 blob is truncated

### Systems
- [x] Event bus, no cross-system node references
- [x] Object pooling for bullets, drones, pickups, sparks, explosions
- [x] Deterministic chunk layout from a run seed
- [x] Difficulty multipliers on enemy HP, incoming damage and score
- [x] Combo multiplier on score, broken by taking damage
- [x] Local save of run + lifetime stats
- [x] Settings persisted in `user://settings.cfg`
- [x] Input recording to `user://replays/*.json`
- [ ] Replay playback — **recorded only**, no UI

### Interface
- [x] Title screen with difficulty select and best score
- [x] HUD: score, combo, currency, health, shield, weapon, level, XP, mods
- [x] Boss health bar
- [x] Pause menu (Esc) that actually pauses the tree
- [x] Settings: SFX, music, CRT, scanlines, screen shake, FPS, default difficulty
- [x] Run summary with accuracy, max combo, damage taken
- [x] Optional FPS counter
- [x] CRT overlay (curvature, aberration, scanlines, vignette, grain, flicker)

### Engineering
- [x] No external assets, no network calls, no plugins
- [x] Typed GDScript throughout
- [x] Headless smoke test wired to a non-zero exit code
- [x] Sprite preview tool
- [x] MIT licence
- [x] `.gitignore` covering `.godot/`, builds and generated previews
- [ ] Export presets — written but **not exercised** (no export templates here)
- [ ] CI workflow — written but **not executed** (no runner here)
- [ ] Visual/audio review by eye and ear — **not possible in this environment**
      (no display server; art was checked as rendered PNGs instead)

## What looking at it changed

The web build made it possible to see the game for the first time (headless
Chrome + screenshots). Four things were wrong and are now fixed:

- default-theme buttons were near-invisible dark-on-dark -> shared `Style` helper
- the mountain parallax layer painted a black wall over the playfield -> ridge
  only, moved to the bottom of the screen
- the HUD weapon/level labels were blank until the first weapon change, because
  the run starts before the HUD exists -> the HUD seeds itself from live state
- a straight horizontal shot missed anything above or below the ship, so a first
  run scored nothing -> gentle 10-degree aim assist

## Known gaps, ranked

1. **Audio has not been heard.** The mix, layer balance and the pad level were
   never listened to — the game was only ever run headless or through a browser
   with no sound output. Expect to nudge dB values after one listen.
2. **Replays are write-only.** Files are complete but nothing plays them.
3. **Export presets and CI are unverified.** Presets follow the documented
   format; the workflow downloads Godot and templates and runs the same headless
   test locally.
4. **Boss fights are tuned by arithmetic, not play.** HP values assume a player
   who keeps firing plasma at level 2–3; expect to retune.
5. **No pause-safe edge cases around scene changes mid-run.** Changing scene from
   the pause menu sets `GameManager.running = false` first, which is the only
   path that avoids a stale run.
6. **Music layer 2 (pad) is quiet** relative to the bass; worth a dB nudge after
   a listen.

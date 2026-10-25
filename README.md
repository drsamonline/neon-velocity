# Neon Velocity

A retro side-scrolling shooter for **Godot 4.3** where every sprite and every
sound is generated at runtime. The repository contains no binary assets at all:
no PNGs, no OGGs, no fonts — just GDScript, three shaders and two scene files.

```
godot --path .          # or open the folder in the Godot 4.3 editor and press F5
```

## Controls

| Action | Keys |
|--------|------|
| Move | `WASD` / arrow keys |
| Fire | `Z` or left mouse button |
| Dash (brief invulnerability) | `Space` / `Shift` |
| Switch weapon | `Q` / `E` |
| Pause | `Esc` |

## What is in the game

- **Six weapons** — plasma cannon, spread shot, laser lance, seeker missiles,
  railgun, nova burst. Each has five levels and gains XP from kills.
- **18 mods** — stat modifiers and named effects (chain lightning, ricochet,
  life siphon, MIRV split, EMP slow, multi-pulse nova). Picking up a mod card
  pauses the run and offers three choices.
- **Endless procedural levels** — the world is a strip of 2400-unit chunks,
  each generated from `run_seed + chunk_index`, so a seed always replays the
  same run.
- **Four bosses** on a five-chunk cycle, each with its own attack patterns and
  a phase change every quarter of its health.
- **Full loop** — title screen, difficulty select, HUD, pause menu, settings,
  run summary with accuracy and best score, local save file.
- **Adaptive music** — four synthesised layers (bass, lead, pad, drums) that
  fade in as you get deeper into a run, plus 24 procedural sound effects.

## How the "zero assets" trick works

| Thing | Where it comes from |
|-------|---------------------|
| Sprites | `scripts/core/Art.gd` rasterises every image with the `Image` API from a fixed 16-colour palette, then wraps it in an `ImageTexture` |
| Sound effects | `scripts/core/AudioManager.gd` synthesises PCM float buffers (FM, sweeps, noise, arpeggios) and packs them into `AudioStreamWAV` |
| Music | The same file builds four 6.857 s loops at 140 BPM and crossfades them |
| Level art | Starfield, nebula and mountain silhouettes are generated once and tiled by `ParallaxBackground` |

Audio generation takes roughly half a second at startup on a modest laptop, all
of it before the title screen appears.

## Project layout

```
scripts/
  core/        EventBus, SaveSystem, Art (sprites), AudioManager, ObjectPool
  systems/     WeaponSystem, LevelManager, GameManager, ReplaySystem
  entities/    Player, Bullet, Powerup
  enemies/     DroneEnemy, CoreBoss
  effects/     Spark, Explosion
  ui/          HUD, MainMenu, SettingsMenu, PauseMenu, ModSelect, GameOverScreen
  tools/       test_runner (headless smoke test), dump_sprites (art previews)
scenes/        Main, MainMenu, SettingsMenu, TestRunner, tools/DumpSprites
shaders/       crt_palette_combined, player_glow, palette_shift
docs/          SPEC.md (the original brief), REVIEW.md (audit of that brief)
```

## Testing

```bash
# headless smoke test: boots Main, plays 7 seconds of synthetic input, asserts 27 things
godot --headless --path . res://scenes/TestRunner.tscn

# dump every generated sprite to art_preview/ for inspection
godot --headless --path . res://scenes/tools/DumpSprites.tscn
```

The test runner exits non-zero on failure, so CI can gate on it.

## Builds

`export_presets.cfg` defines Windows, Linux and macOS presets. Locally:

```bash
godot --headless --path . --export-release "Linux/X11" build/NeonVelocity.x86_64
```

Export templates must be installed first (Editor → Manage Export Templates).
`.github/workflows/build.yml` does this on a `v*` tag and attaches the three
builds to a GitHub release.

## Saves and replays

Settings live in `user://settings.cfg`, the last run and lifetime stats in
`user://save_game.save` (JSON, XOR-obfuscated — not encrypted, and not meant to
be), and recorded inputs in `user://replays/`.

Replays are **recorded, not yet playable**: each run writes a JSON file with the
seed, difficulty and three bytes of input per frame, which is everything needed
to re-simulate it, but no playback UI is wired up yet.

## License

MIT — see `LICENSE`.

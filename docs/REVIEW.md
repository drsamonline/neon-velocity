# Review of the Neon Velocity brief

`docs/SPEC.md` is the brief this project was built from. It is a strong design
document — the architecture, the palette, the weapon and mod tables, and the
difficulty curve are all thought through — but it is **not** a buildable
specification. The code in it does not parse, and several of its central
techniques cannot work in Godot 4.3 at all.

This review lists what breaks, why, and what this repository does instead.
Everything below was checked against **Godot 4.3.stable** by actually running
the code, not by reading it.

---

## 1. The four things that cannot work as specified

### 1.1 `AudioStreamGenerator` cannot generate audio offline

The brief's entire audio plan — 24 SFX, four music layers, generated at edit
time and saved as `.ogg` — rests on this:

```gdscript
var gen = AudioStreamGenerator.new()
gen.push_frame(buf)
ResourceSaver.save(gen, "res://assets/audio/sfx/shoot_plasma.ogg")
```

`AudioStreamGenerator` is a *playback* buffer. `push_frame()` feeds samples to a
player that is currently running; the samples are consumed and discarded. Saving
the resource writes the stream's parameters, not the audio, and Godot has no Ogg
*encoder* at all — it only imports Ogg files. The pipeline would have produced
24 silent files.

**Done instead:** `scripts/core/AudioManager.gd` synthesises `PackedFloat32Array`
buffers and packs them into `AudioStreamWAV` with 16-bit PCM. Loops set
`loop_mode = LOOP_FORWARD`. No files, no export step, no silent audio.

### 1.2 There are no Promises in GDScript

```gdscript
SaveSystem.load_game().then(_on_load_complete)
```

GDScript has no `Future`/`then`. This is a parse error, in the autoload's
`_ready()`, so the game never starts.

**Done instead:** `SaveSystem` loads synchronously in `_ready()`; loading a save
is a sub-millisecond JSON parse.

### 1.3 `preload()` needs a constant, and the pool is built from variables

```gdscript
var scene = preload(cfg.scene_path)
```

`preload` is resolved at compile time and rejects anything that is not a string
literal. The pool also does `pool_configs.find({"name": pool_name}).scene_path`,
where `find()` returns an `int` index — `.scene_path` on an integer is a second
error, and the `powerup` pool the gameplay code acquires from is never defined.

**Done instead:** `ObjectPool.POOL_DEFS` is a `const` dictionary of
`preload(...)` calls, so every factory is compile-time checked, and
`acquire()`/`release()` are type-safe with a warning when a pool grows.

### 1.4 Dictionaries have no attribute access

The brief uses `mod.type`, `stats.color`, `pattern.type`, `data.boss.hp`,
`v.min_chunk`, `mod.stats` throughout. In GDScript a `Dictionary` only supports
`dict["key"]`; `dict.key` raises *"Cannot find member"* at runtime. This affects
`WeaponSystem`, `CoreBoss`, `Bullet`, `ProceduralLevel`, `LevelManager` and
`AudioManager` — the majority of the gameplay code.

**Done instead:** bracket access everywhere, and dictionaries are duplicated
before mutation so shared `const` tables can never be edited in place.

---

## 2. Blocker list (would stop the project from running)

| # | Where | Problem | Fix in this repo |
|---|-------|---------|------------------|
| 1 | `Player.gd` | `var velocity = Vector2.ZERO` re-declares `CharacterBody2D.velocity` → parse error | use the built-in property |
| 2 | `GameManager.gd`, `CoreBoss.gd` | `HUD.update_score(...)` — `HUD` is a `class_name`, not a node; calling an instance method on the class fails | HUD subscribes to `EventBus`; no system holds a HUD reference |
| 3 | `ObjectPool.gd` | `@tool` on an autoload instantiates 500+ nodes *inside the editor* | plain autoload, pools built at runtime |
| 4 | `ObjectPool.gd` | `for obj in pool: pool.erase(obj)` mutates while iterating | `pop_back()` / `append()` |
| 5 | `LevelManager.gd` | `chunk.add_child(enemy)` on a node already parented in the pool → *"node already has a parent"* | pooled nodes stay parented under `ObjectPool` (identity transform) and are positioned in world space |
| 6 | `ProceduralLevel.gd` | `extends Resource` declared as autoload #8 — autoloads must be `Node` | chunk generation folded into `LevelManager`; no phantom autoload |
| 7 | `ProceduralLevel.gd`, `LevelManager.gd` | `rng.pick_array(...)` — `RandomNumberGenerator` has no such method | `randi_range` + explicit arrays |
| 8 | `LevelManager.gd` | `chunk.set("palette_index", ...)` on a plain `Node2D` | dropped (nothing consumed it) |
| 9 | `Bullet.gd`, `Powerup.gd` | `_on_body_entered` is defined but **never connected** — bullets pass through everything | signals connected in `_ready()` |
| 10 | `Bullet.gd` | `despawn()` always releases into `bullet_player`, so enemy bullets pollute the player pool | pool name is stored per bullet |
| 11 | `Bullet.gd` | player damage multiplied by `enemy_dmg_mult` (enemy difficulty) | player damage is independent of the enemy-damage axis |
| 12 | `Bullet.gd` | homing raycast uses `1 << 4` (the *enemy bullet* layer) and only looks right | nearest-enemy search over the `enemies` group |
| 13 | `Player.gd` | `die()` emits `game_over` directly and `queue_free()`s the player — the camera is its child, so the screen dies with it | `GameManager.end_run()`; the player hides and stops processing |
| 14 | `GameManager.gd` | `take_damage()` body is literally `# ... health logic ...` | health lives in `Player`, stats in `GameManager` |
| 15 | `GameManager.gd` | `start_new_run()` calls `LevelManager.start_run()` before `Main/World` exists | `Main` creates the world first, then starts the level |
| 16 | `SaveSystem.gd` | `get_setting("sfx_volume", 0.8)` — the signature splits on `"/"` and indexes `parts[1]` → out of bounds | `get_setting(section, key, fallback)` |
| 17 | `SaveSystem.gd` | `_sort_replays_desc` calls `.get_modified_time()` on a `String` | plain filename sort |
| 18 | `AudioManager.gd` | `AudioServer.set_bus_volume_db(idx, 0.8)` — a linear value into a dB setter (≈ inaudible), and the `SFX`/`Music` buses are never defined anywhere | buses created at runtime if missing; `linear_to_db()` |
| 19 | `AudioManager.gd` | `_layer_sounds()` returns `generators[0]`; every layered SFX is one tone | real additive mixing with offsets |
| 20 | `AudioManager.gd` | `_synth_lead_loop`/`pad`/`drum` all return the bass loop, which returns an **empty buffer**; `set_music_intensity()` is `pass` | four genuinely different layers, real crossfade |
| 21 | `HUD.gd` | `_get_mod_icon()` is called but never defined; `grant_weapon_exp`/`update_currency` are empty statics | mods are listed as text; XP lives in `WeaponSystem` |
| 22 | `Player.gd` | `$Sprite`, `$EngineTrail`, `$Sprite.material` — no scene defines them, and `AnimatedSprite2D` needs `SpriteFrames` that are never built | nodes built in code from `Art` textures |
| 23 | `MainMenu.gd` | `_on_continue()` loads a save then immediately calls `start_new_run()`, overwriting it | no resume-from-save path (honest scope cut) |
| 24 | `PauseMenu.gd` | emits `pause_toggled` but never sets `get_tree().paused` | `set_paused()` pauses the tree |
| 25 | `test_run.gd` | `extends EditorScript`, uses `await` and `get_tree()`, and `InputEventKey.set_keycode()` returns `void` so the "fake input" never presses a key | real `Node`-based test scene driving `Input.action_press()` |
| 26 | `generate_assets.gd` | `godot --headless --script tools/generate_assets.gd` cannot run an `EditorScript`; and writing to `res://` at export time is impossible inside a `.pck` | no asset step at all; `dump_sprites.gd` is a dev-only preview tool |
| 27 | `FONT_BASE64` | truncated (`"AAEAAAAKAI..."`) — undecodable | default theme font |

---

## 3. Shader problems

```glsl
uniform bool crt_enabled : true = true;
uniform sampler2D palette_texture : hint_white, ...
```

- `uniform bool x : true = true;` is invalid — the default goes after `=`.
- `hint_white` is Godot 3; Godot 4 uses `hint_default_white`.
- `return` is not allowed inside `fragment()` in Godot's shading language.
- `palette_texture` is never assigned by any script, so the palette lookup
  samples a white texture and the whole screen becomes white — the CRT pass
  would blank the game.
- `apply_chromatic(vec3(0), uv)` takes a colour argument it ignores.
- `particle_shader.gdshader` is written for a `GPUParticles2D` that no scene
  ever creates, and uses `SCALE` without the required `render_mode`.

**Done instead:** `shaders/crt_palette_combined.gdshader` compiles clean under
`gl_compatibility` (verified headless — Godot compiles shaders even with the
dummy renderer), has no early returns, and quantisation was dropped entirely
because the art is *already* drawn from the 16-colour palette; a second quantise
pass only muddied it. `player_glow.gdshader` is used on the ship;
`palette_shift.gdshader` ships as the documented hook for per-chunk themes.

---

## 4. Design and consistency issues

1. **Determinism is claimed but impossible.** The brief promises deterministic
   RNG and replays, then uses global `randf()` in `DroneEnemy` aiming,
   `CoreBoss` orb angles, and even inside audio synthesis. Two runs of the same
   seed diverge immediately. Here: chunk layout, formations and pickups come
   from a seeded `RandomNumberGenerator`; combat randomness is explicitly *not*
   part of the replay contract, which is why replays record inputs only.
2. **`level_bonus` confuses additive and multiplicative.** `{"projectile_count": 1}`
   multiplied into `projectile_count` is a no-op; the intent was "+1 per level".
3. **`_generate_mod_choices()` says "weight by tier rarity"** and then does not
   weight anything. Tiers are gone; every mod is available, filtered to the
   current weapon.
4. **`_synth_nova_charge()` returns the railgun sound**, documented as
   "simplified for spec" — two of six weapons would have shared a sound.
5. **`set_music_intensity()` is `pass`** while the spec's own table says layers
   fade in at chunk 1/2/4 — the headline "adaptive music" feature is absent.
6. **Startup cost.** ~1.5 M per-sample GDScript iterations (24 SFX at 44.1 kHz
   plus 4 × 6.857 s music layers) would stall the first frame for seconds, which
   contradicts "zero GC spikes, 60 FPS". Here: music is synthesised at 11 kHz
   and everything generates in well under a second.
7. **Performance claim vs. implementation.** "200+ entities at 60 FPS" is
   plausible with pooling, but the brief allocates new nodes when the pool is
   exhausted and never bounds the replay array (20 minutes of input at 60 Hz
   is 216 000 dictionaries here — 648 000 bytes in the shipped `PackedByteArray`).
8. **The file structure is fiction.** "60+ GDScript files, 15+ scenes, 30+
   sprites" is the checklist; the document contains ~20 scripts, no `.tscn`
   bodies, and ten hard-coded scene paths (`PlayerBullet.tscn`, `Missile.tscn`,
   `NovaBurst.tscn`, `LaserBeam.tscn`, `DamagePopup.tscn`, `ComboPopup.tscn`,
   `MuzzleFlash.tscn`, `DashAfterimage.tscn`, `EngineTrail.tscn`,
   `DifficultySelect.tscn`) that the structure section never lists.
9. **Referenced-but-missing sections.** `README.md`, `AUDIT.md`,
   `export_presets.cfg` and the GitHub Actions workflow are all "see full X in
   previous response" — that content is not in the document and cannot be
   recovered from it.
10. **Autoload order contradicts itself.** `AudioManager` (#3) reads
    `SaveSystem` (#5) in `_ready()`, and `GameManager` (#2) calls
    `LevelManager` (#7) and `HUD` before either exists.

---

## 5. What was kept from the brief

The parts that were sound, and are implemented here as written:

- **Signal-bus architecture.** Systems communicate through `EventBus`; nothing
  reaches into another system's node tree. The brief's best idea.
- **Object pooling** for bullets, enemies, sparks, explosions and pickups.
- **16-colour CGA/EGA-inspired palette** — kept exactly, but built with
  `Color8` so the values are not out of range.
- **The six weapons, their stat table and their names.**
- **18 mods** with the same names, blurbs and tiers of effect, all wired to real
  behaviour (chain, ramp, crit, ricochet, lifesteal, MIRV, EMP, multi-pulse).
- **Four difficulty levels** with the same multipliers.
- **Chunk streaming** with a boss every five chunks, and the four boss names.
- **4-layer adaptive music at 140 BPM**, now actually layered.
- **Local save + replay files** under `user://`, JSON, obfuscated with XOR and
  documented as *not* encryption.
- **PolyForm Noncommercial licence, CI workflow, export presets, headless test.**

---

## 6. Honest scope cuts

- **Replays are recorded but not playable.** The JSON is complete (seed,
  difficulty, 3 bytes of input per frame) but no playback UI is wired.
- **No difficulty-select screen.** Difficulty is chosen on the title screen and
  persisted in settings.
- **No ghost player, no damage popups, no combo popups, no muzzle-flash sprites,
  no engine-trail particles.** These were listed but never specified; pooled
  sparks and shockwaves cover the same feedback.
- **No embedded pixel font.** The default theme font is used, because the
  base64 blob in the brief is truncated.
- **Not verified:** the export presets and the CI workflow could not be
  exercised in this environment (no export templates, no runner). Everything
  else — parsing, import, the full gameplay loop, boss spawn, damage, death,
  save round-trip — is covered by the headless test.

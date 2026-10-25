extends Node
## Global signal bus.
##
## Systems never hold references to each other's nodes: they talk through these
## signals. This keeps the autoloads free of circular dependencies and lets the
## HUD subscribe to gameplay events without GameManager knowing the HUD exists.

signal game_started(difficulty: int)
signal game_over(final_score: int, wave: int, stats: Dictionary)
signal pause_toggled(paused: bool)
signal settings_changed(category: String, key: String, value: Variant)

signal score_changed(score: int, combo: int)
signal health_changed(current: int, maximum: int)
signal shield_changed(current: int, maximum: int)
signal weapon_changed(weapon_id: String, level: int)
signal mod_acquired(mod_id: String)
signal currency_changed(amount: int)
signal weapon_exp_changed(exp: int, needed: int)

signal chunk_started(chunk_index: int)
signal chunk_completed(chunk_index: int, score: int)
signal boss_spawned(boss_name: String, hp: int, max_hp: int)
signal boss_hp_changed(hp: int, max_hp: int)
signal boss_defeated(boss_name: String)

signal screen_shake(strength: float, duration: float)
signal mod_choices_offered(choices: Array)
signal run_paused_requested()

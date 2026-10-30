extends Node
## Headless smoke test.
##
##   godot --headless --path . res://scenes/TestRunner.tscn
##
## Boots the real Main scene, drives it with synthetic input for a few hundred
## physics frames, and asserts that the core loop actually runs: enemies spawn,
## shots are fired, kills score, a boss appears, damage lands and a save
## round-trips. Exits non-zero on failure, so CI can gate on it.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_tests()
	if _failures.is_empty():
		print("\nPASS - %d checks" % _checks)
		get_tree().quit(0)
	else:
		print("\nFAIL - %d of %d checks failed" % [_failures.size(), _checks])
		for failure in _failures:
			print("  - ", failure)
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		print("  [FAIL] ", label)


func _run_tests() -> void:
	# --- procedural content -------------------------------------------
	_check(AudioManager.has_sfx("shoot_plasma"), "SFX bank missing shoot_plasma")
	_check(AudioManager.has_sfx("boss_death"), "SFX bank missing boss_death")
	_check(Art.texture("player_ship") != null, "player sprite not generated")
	_check(Art.texture("boss_core").get_width() == 96, "boss sprite wrong size")
	_check(Art.texture("starfield") != null, "starfield not generated")

	# --- weapons and mods ---------------------------------------------
	WeaponSystem.reset()
	_check(int(WeaponSystem.get_stats()["damage"]) == 12, "plasma base damage wrong")
	WeaponSystem.select_weapon("spread")
	_check(int(WeaponSystem.get_stats()["count"]) == 5, "spread should fire 5 pellets")
	_check(WeaponSystem.roll_mod_choices(3).size() == 3, "mod roll should offer 3 mods")
	WeaponSystem.apply_mod("spread_wide")
	_check(int(WeaponSystem.get_stats()["count"]) == 6, "mod did not add a projectile")
	_check(WeaponSystem.mods.size() == 1, "mod was not recorded")
	WeaponSystem.select_weapon("railgun")
	_check(String(WeaponSystem.get_stats()["kind"]) == "railgun", "railgun kind wrong")

	# --- touch input plumbing -----------------------------------------
	TouchInput.enable()
	_check(TouchInput.enabled, "touch input did not enable")
	TouchInput.request_dash()
	_check(TouchInput.consume_dash(), "dash request was not queued")
	_check(not TouchInput.consume_dash(), "dash request was not cleared")
	TouchInput.request_weapon_step(1)
	_check(TouchInput.consume_weapon_step() == 1, "weapon step was not queued")
	TouchInput.request_pause()
	_check(TouchInput.consume_pause(), "pause request was not queued")
	TouchInput.reset()
	TouchInput.enabled = false

	# --- save round trip ----------------------------------------------
	SaveSystem.save_run({"score": 4242, "wave": 3, "kills": 9}, {"best_score": 4242})
	var loaded := SaveSystem.load_run()
	_check(int(loaded.get("run", {}).get("score", 0)) == 4242, "save/load round trip failed")

	# --- boot the real game -------------------------------------------
	GameManager.start_new_run(1)
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := get_tree().get_first_node_in_group("player")
	_check(player != null, "player was not created")
	_check(GameManager.running, "run did not start")
	_check(LevelManager.chunks.size() > 0, "no chunks were generated")
	_check(ObjectPool.active_count("drone") > 0, "no enemies were spawned")
	_check(main.get_node_or_null("World") != null, "world node missing")

	# --- drive it ------------------------------------------------------
	Input.action_press("fire")
	Input.action_press("move_right")
	var mod_select := _find_mod_select(main)
	var start_score := int(GameManager.run_data["score"])
	for i in 420:
		await get_tree().physics_frame
		# Resolve any mod offer so the run cannot stall on a paused tree.
		if get_tree().paused and mod_select != null and mod_select.is_open():
			mod_select.choose(0)
	Input.action_release("fire")
	Input.action_release("move_right")

	_check(int(GameManager.run_data["shots_fired"]) > 0, "player never fired")
	_check(ObjectPool.active_count("bullet_player") > 0, "no player bullets alive")
	_check(int(GameManager.run_data["kills"]) > 0, "nothing was killed in 7 seconds")
	_check(int(GameManager.run_data["score"]) > start_score, "score did not increase")
	_check(ReplaySystem.frame_count() > 0, "replay recorded no frames")
	_check(WeaponSystem.xp >= 0, "weapon xp went negative")

	# --- boss ----------------------------------------------------------
	var player_node := player as Node2D
	player_node.global_position.x = LevelManager.CHUNK_WIDTH * 4.0 + 40.0
	for i in 20:
		await get_tree().physics_frame
	var boss_found := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is CoreBoss:
			boss_found = true
	_check(boss_found, "boss did not spawn on chunk 4")

	# --- damage and death ---------------------------------------------
	# This check used to be "health went down", and that is only true while the
	# player holds NO shield: take_damage absorbs into the shield first, and a
	# shield powerup can be picked up during the 7-second run above. So the check
	# was a coin-flip that failed roughly whenever a shield was collected — it
	# failed in CI on 2026-10-26 (run 40301794539) and passed six times in a row
	# locally, which is the signature of a flaky assertion, not a broken game.
	# The invariant that always holds is that a 12-point hit costs 12 points of
	# EFFECTIVE health, wherever those points live. i-frames from a hit taken
	# during the run would swallow the blow too, so let any active invulnerability
	# expire first — the same wait the killing blow below already does.
	for i in 60:
		await get_tree().physics_frame
	var effective_before := int(player_node.get("health")) + int(player_node.get("shield"))
	player_node.call("take_damage", 12)
	var effective_after := int(player_node.get("health")) + int(player_node.get("shield"))
	_check(effective_after < effective_before,
		"player did not take damage (health + shield unchanged: %d -> %d)" % [effective_before, effective_after])

	# Let the post-hit invulnerability window expire before the killing blow.
	for i in 60:
		await get_tree().physics_frame
	var signal_fired := [false]
	EventBus.game_over.connect(func(_s: int, _w: int, _d: Dictionary) -> void: signal_fired[0] = true)
	player_node.call("take_damage", 100000)
	for i in 5:
		await get_tree().process_frame
	_check(signal_fired[0], "game_over was not emitted when the player died")
	_check(not GameManager.running, "run did not end")


func _find_mod_select(node: Node) -> ModSelect:
	for child in node.get_children():
		if child is ModSelect:
			return child
		var found := _find_mod_select(child)
		if found != null:
			return found
	return null

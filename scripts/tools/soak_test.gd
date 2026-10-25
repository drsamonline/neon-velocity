extends Node
## Longer soak run: plays the game for ~50 seconds of simulated time with fire
## held and the ship drifting right, so chunk streaming, pooling and the first
## boss fight all get exercised. Prints a summary; watch stderr for errors.
##
##   godot --headless --path . res://scenes/tools/SoakTest.tscn

const FRAMES := 3000


func _ready() -> void:
	await get_tree().process_frame
	GameManager.start_new_run(1)
	add_child(load("res://scenes/Main.tscn").instantiate())
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var mod_select := _find_mod_select(self)
	var pauses := 0

	Input.action_press("fire")
	var peak_bullets := 0
	var peak_drones := 0
	for i in FRAMES:
		await get_tree().physics_frame
		# A mod pickup pauses the game and waits for a click; the soak test
		# takes the first card instead of hanging there forever.
		if get_tree().paused:
			pauses += 1
			if mod_select != null and mod_select.is_open():
				mod_select.choose(0)
		if is_instance_valid(player) and player.visible:
			# Nudge forward so new chunks keep arriving.
			player.global_position.x += 6.0
			peak_bullets = maxi(peak_bullets, ObjectPool.active_count("bullet_player") + ObjectPool.active_count("bullet_enemy"))
			peak_drones = maxi(peak_drones, ObjectPool.active_count("drone"))
	Input.action_release("fire")

	print("--- soak summary ---")
	print("frames:            ", FRAMES)
	print("chunk reached:     ", LevelManager.current_chunk)
	print("score:             ", GameManager.run_data.get("score", 0))
	print("kills:             ", GameManager.run_data.get("kills", 0))
	print("shots fired:       ", GameManager.run_data.get("shots_fired", 0))
	print("peak live bullets: ", peak_bullets)
	print("peak live drones:  ", peak_drones)
	print("still running:     ", GameManager.running)
	print("mod offers:        ", pauses)
	print("fps (headless):    ", Engine.get_frames_per_second())
	get_tree().quit(0)


func _find_mod_select(node: Node) -> ModSelect:
	for child in node.get_children():
		if child is ModSelect:
			return child
		var found := _find_mod_select(child)
		if found != null:
			return found
	return null

extends CanvasLayer
class_name GameOverScreen
## End-of-run summary.

var _built: bool = false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_results(score: int, wave: int, stats: Dictionary) -> void:
	visible = true
	if _built:
		for child in get_children():
			child.queue_free()
	_built = true
	_build(score, wave, stats)


func _build(score: int, wave: int, stats: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(390, 130)
	box.size = Vector2(500, 460)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "RUN OVER"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var fired := int(stats.get("shots_fired", 0))
	var hits := int(stats.get("shots_hit", 0))
	var accuracy := 0.0 if fired == 0 else float(hits) / float(fired) * 100.0
	var lines := [
		"SCORE          %d" % score,
		"WAVE           %d" % wave,
		"KILLS          %d" % int(stats.get("kills", 0)),
		"MAX COMBO      x%d" % int(stats.get("max_combo", 0)),
		"ACCURACY       %.1f%%" % accuracy,
		"DAMAGE TAKEN   %d" % int(stats.get("damage_taken", 0)),
		"BEST SCORE     %d" % int(SaveSystem.meta.get("best_score", 0)),
	]
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var retry := Button.new()
	retry.text = "RETRY"
	retry.custom_minimum_size = Vector2(180, 46)
	Style.style_button(retry)
	retry.pressed.connect(_on_retry)
	row.add_child(retry)

	var menu := Button.new()
	menu.text = "MENU"
	menu.custom_minimum_size = Vector2(180, 46)
	Style.style_button(menu)
	menu.pressed.connect(_on_menu)
	row.add_child(menu)


func _on_retry() -> void:
	GameManager.start_new_run(GameManager.difficulty)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

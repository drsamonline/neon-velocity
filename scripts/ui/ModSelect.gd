extends CanvasLayer
class_name ModSelect
## Mod pickup: pause the run and offer three cards. Pick with a click, a tap or
## the 1-3 keys.

var _choices: Array[String] = []
var _open: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.mod_choices_offered.connect(open)


func open(choices: Array) -> void:
	if _open or choices.is_empty():
		return
	_open = true
	visible = true
	get_tree().paused = true
	TouchInput.reset()
	for child in get_children():
		child.queue_free()
	_build(choices)


func _build(choices: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "CHOOSE A MOD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.27))
	box.add_child(title)

	_choices.clear()
	for mod_id in choices:
		var mod: Dictionary = WeaponSystem.MODS[String(mod_id)]
		var id := String(mod_id)
		_choices.append(id)
		var button := Button.new()
		button.text = "%s\n%s" % [String(mod["name"]), String(mod["blurb"])]
		button.custom_minimum_size = Vector2(520, 64)
		button.add_theme_font_size_override("font_size", 18)
		Style.style_button(button, Style.GOLD)
		button.pressed.connect(func() -> void: _choose(id))
		box.add_child(button)


## Pick by index; also used by the number keys and by the automated tests.
func choose(index: int) -> void:
	if not _open or index < 0 or index >= _choices.size():
		return
	_choose(_choices[index])


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.is_pressed():
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_3:
		choose(key - KEY_1)
		get_viewport().set_input_as_handled()


func _choose(mod_id: String) -> void:
	WeaponSystem.apply_mod(mod_id)
	_close()


func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	for child in get_children():
		child.queue_free()


func is_open() -> bool:
	return _open

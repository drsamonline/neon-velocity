extends CanvasLayer
class_name TouchControls
## On-screen controls: a floating stick on the left, fire and dash on the right,
## plus weapon-switch and pause buttons.
##
## Everything is drawn in one Control rather than built from buttons, because a
## shooter needs multi-touch (move and fire at the same time) and Godot's Control
## focus system is single-touch. Touch indices are tracked by hand.

const STICK_RADIUS := 94.0
const KNOB_RADIUS := 42.0
const FIRE_RADIUS := 88.0
const DASH_RADIUS := 56.0
const SMALL_RADIUS := 42.0

const ACCENT := Color(0.29, 0.68, 1.0)
const GOLD := Color(1.0, 0.92, 0.27)
const IDLE := Color(0.55, 0.75, 1.0, 0.22)
const ACTIVE := Color(0.55, 0.85, 1.0, 0.55)

var _canvas: Control
var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_position: Vector2 = Vector2.ZERO
var _fire_index: int = -1
var _dash_index: int = -1
var _flash: Dictionary = {}

var _fire_center: Vector2 = Vector2.ZERO
var _dash_center: Vector2 = Vector2.ZERO
var _weapon_center: Vector2 = Vector2.ZERO
var _pause_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	visible = TouchInput.enabled
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_fire_center = Vector2(size.x - 140.0, size.y - 130.0)
	_dash_center = Vector2(size.x - 330.0, size.y - 108.0)
	_weapon_center = Vector2(size.x - 58.0, 168.0)
	_pause_center = Vector2(size.x - 58.0, 62.0)
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if visible != TouchInput.enabled:
		visible = TouchInput.enabled
	for key in _flash.keys():
		_flash[key] = maxf(0.0, float(_flash[key]) - delta * 3.0)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	# Any real touch turns the controls on, even if the device did not advertise
	# a touchscreen at startup.
	if event is InputEventScreenTouch and not TouchInput.enabled:
		TouchInput.enable()
		visible = true

	if not TouchInput.enabled:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# Mouse fallback, so the controls can be exercised on a desktop build.
		var button := event as InputEventMouseButton
		var synthetic := InputEventScreenTouch.new()
		synthetic.index = 0
		synthetic.pressed = button.pressed
		synthetic.position = button.position
		_handle_touch(synthetic)
	elif event is InputEventMouseMotion and _stick_index == 0:
		var motion := event as InputEventMouseMotion
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = motion.position
		_handle_drag(drag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var position := event.position
	if event.pressed:
		if _stick_index == -1 and position.x < _stick_zone_width():
			_stick_index = event.index
			_stick_origin = position
			_stick_position = position
			_update_stick(position)
		elif _fire_index == -1 and position.distance_to(_fire_center) <= FIRE_RADIUS:
			_fire_index = event.index
			TouchInput.firing = true
			_flash["fire"] = 1.0
		elif _dash_index == -1 and position.distance_to(_dash_center) <= DASH_RADIUS:
			_dash_index = event.index
			TouchInput.request_dash()
			_flash["dash"] = 1.0
		elif position.distance_to(_weapon_center) <= SMALL_RADIUS:
			TouchInput.request_weapon_step(1)
			_flash["weapon"] = 1.0
		elif position.distance_to(_pause_center) <= SMALL_RADIUS:
			TouchInput.request_pause()
			_flash["pause"] = 1.0
	else:
		if event.index == _stick_index:
			_stick_index = -1
			TouchInput.move = Vector2.ZERO
		elif event.index == _fire_index:
			_fire_index = -1
			TouchInput.firing = false
		elif event.index == _dash_index:
			_dash_index = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _stick_index:
		_update_stick(event.position)


func _update_stick(position: Vector2) -> void:
	_stick_position = position
	var offset := position - _stick_origin
	var length := offset.length()
	if length < 12.0:
		TouchInput.move = Vector2.ZERO
		return
	var strength := minf(length / STICK_RADIUS, 1.0)
	TouchInput.move = offset.normalized() * strength


func _stick_zone_width() -> float:
	return get_viewport().get_visible_rect().size.x * 0.45


func _draw_controls() -> void:
	if not TouchInput.enabled:
		return
	var size := get_viewport().get_visible_rect().size

	# --- stick ---
	if _stick_index == -1:
		var resting := Vector2(170.0, size.y - 130.0)
		_canvas.draw_circle(resting, STICK_RADIUS, Color(1, 1, 1, 0.05))
		_canvas.draw_arc(resting, STICK_RADIUS, 0.0, TAU, 48, IDLE, 3.0)
		_canvas.draw_circle(resting, KNOB_RADIUS, Color(1, 1, 1, 0.08))
	else:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.06))
		_canvas.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, ACTIVE, 3.0)
		var knob := _stick_origin + (TouchInput.move * STICK_RADIUS)
		_canvas.draw_circle(knob, KNOB_RADIUS, Color(0.55, 0.85, 1.0, 0.35))
		_canvas.draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 40, Color(0.8, 0.95, 1.0, 0.7), 3.0)

	# --- fire ---
	var fire_colour := Color(1.0, 0.45, 0.55, 0.75) if _fire_index != -1 else Color(1.0, 0.45, 0.55, 0.30)
	_canvas.draw_circle(_fire_center, FIRE_RADIUS, Color(fire_colour.r, fire_colour.g, fire_colour.b, fire_colour.a * 0.5))
	_canvas.draw_arc(_fire_center, FIRE_RADIUS, 0.0, TAU, 56, fire_colour, 4.0)
	_draw_label(_fire_center, "FIRE", 26, Color(1, 1, 1, 0.85))

	# --- dash ---
	var dash_colour := Color(0.6, 0.9, 1.0, 0.8) if _dash_index != -1 else Color(0.6, 0.9, 1.0, 0.28)
	_canvas.draw_circle(_dash_center, DASH_RADIUS, Color(dash_colour.r, dash_colour.g, dash_colour.b, dash_colour.a * 0.5))
	_canvas.draw_arc(_dash_center, DASH_RADIUS, 0.0, TAU, 48, dash_colour, 3.0)
	_draw_label(_dash_center, "DASH", 18, Color(1, 1, 1, 0.8))

	# --- small buttons ---
	_draw_small(_weapon_center, "WPN", float(_flash.get("weapon", 0.0)))
	_draw_small(_pause_center, "II", float(_flash.get("pause", 0.0)))


func _draw_small(center: Vector2, text: String, flash: float) -> void:
	var colour := ACCENT.lerp(GOLD, flash)
	colour.a = 0.30 + flash * 0.5
	_canvas.draw_circle(center, SMALL_RADIUS, Color(colour.r, colour.g, colour.b, 0.35))
	_canvas.draw_arc(center, SMALL_RADIUS, 0.0, TAU, 40, colour, 3.0)
	_draw_label(center, text, 18, Color(1, 1, 1, 0.85))


func _draw_label(center: Vector2, text: String, font_size: int, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-width * 0.5, font_size * 0.35)
	_canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

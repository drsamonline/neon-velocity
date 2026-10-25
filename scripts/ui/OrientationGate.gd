extends CanvasLayer
## Covers the screen in portrait. The game is a horizontal shooter, so a phone
## held upright gets a message instead of a letterboxed strip.

var _dim: ColorRect
var _label: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.06, 0.97)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.29, 0.68, 1.0))
	_label.text = "ROTATE YOUR DEVICE\n\nNeon Velocity is played in landscape."
	add_child(_label)
	visible = false
	get_viewport().size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var size := get_viewport().get_visible_rect().size
	visible = size.x < size.y * 1.05

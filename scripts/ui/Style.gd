extends RefCounted
class_name Style
## Shared look for buttons and panels.
##
## Godot's default theme draws dark text on a dark button, which is unreadable
## on this background, so every button in the game goes through here.

const ACCENT := Color(0.29, 0.68, 1.0)
const GOLD := Color(1.0, 0.92, 0.27)
const TEXT := Color(0.86, 0.93, 1.0)
const PANEL := Color(0.04, 0.05, 0.11, 0.92)


static func _box(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func style_button(button: Button, accent: Color = ACCENT) -> void:
	button.add_theme_stylebox_override("normal", _box(PANEL, Color(accent.r, accent.g, accent.b, 0.45)))
	button.add_theme_stylebox_override("hover", _box(Color(0.08, 0.14, 0.26, 0.96), accent))
	button.add_theme_stylebox_override("pressed", _box(Color(0.16, 0.30, 0.50, 0.96), accent))
	button.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), accent, 1))
	button.add_theme_stylebox_override("disabled", _box(Color(0.03, 0.03, 0.06, 0.7), Color(0.3, 0.3, 0.4, 0.4)))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.5))


static func style_option(option: OptionButton) -> void:
	option.add_theme_stylebox_override("normal", _box(PANEL, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)))
	option.add_theme_stylebox_override("hover", _box(Color(0.08, 0.14, 0.26, 0.96), ACCENT))
	option.add_theme_stylebox_override("pressed", _box(Color(0.16, 0.30, 0.50, 0.96), ACCENT))
	option.add_theme_color_override("font_color", TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_font_size_override("font_size", 18)


static func style_panel(box: Control) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.02, 0.06, 0.85)
	panel.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(24.0)
	box.add_theme_stylebox_override("panel", panel)

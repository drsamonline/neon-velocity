extends CanvasLayer
class_name HUD
## In-run interface. Built in code so there is no .tscn to drift out of sync
## with the scripts; it only ever listens to EventBus.

const ACCENT := Color(0.29, 0.68, 1.0)
const WARN := Color(1.0, 0.42, 0.42)
const GOLD := Color(1.0, 0.92, 0.27)

var _score_label: Label
var _combo_label: Label
var _currency_label: Label
var _weapon_label: Label
var _level_label: Label
var _health_bar: ProgressBar
var _shield_bar: ProgressBar
var _xp_bar: ProgressBar
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _mods_label: Label
var _fps_label: Label
var _show_fps: bool = false


func _ready() -> void:
	layer = 10
	_build()
	_connect_signals()
	EventBus.settings_changed.connect(_on_setting_changed)
	_show_fps = bool(SaveSystem.get_setting("visual", "show_fps", false))
	_fps_label.visible = _show_fps


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_score_label = _make_label(root, Vector2(24, 16), 26, ACCENT)
	_score_label.text = "SCORE 000000"
	_combo_label = _make_label(root, Vector2(24, 50), 20, GOLD)
	_combo_label.text = ""

	_currency_label = _make_label(root, Vector2(1000, 16), 22, GOLD)
	_currency_label.text = "0 CR"
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.size = Vector2(240, 30)

	_weapon_label = _make_label(root, Vector2(24, 640), 22, Color.WHITE)
	_level_label = _make_label(root, Vector2(24, 668), 18, ACCENT)
	_mods_label = _make_label(root, Vector2(24, 692), 15, Color(0.7, 0.7, 0.9))
	_mods_label.size = Vector2(700, 22)

	_health_bar = _make_bar(root, Vector2(24, 596), Vector2(260, 18), Color(1.0, 0.35, 0.42))
	_shield_bar = _make_bar(root, Vector2(24, 616), Vector2(260, 10), Color(0.35, 0.75, 1.0))
	_xp_bar = _make_bar(root, Vector2(24, 628), Vector2(260, 6), ACCENT)

	_boss_box = VBoxContainer.new()
	_boss_box.position = Vector2(390, 18)
	_boss_box.size = Vector2(500, 60)
	_boss_box.add_theme_constant_override("separation", 2)
	root.add_child(_boss_box)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 20)
	_boss_name.add_theme_color_override("font_color", WARN)
	_boss_box.add_child(_boss_name)
	var boss_bar_bg := _make_bar(_boss_box, Vector2.ZERO, Vector2(500, 16), WARN)
	boss_bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_bar = boss_bar_bg
	_boss_box.visible = false

	_fps_label = _make_label(root, Vector2(1180, 8), 14, Color(0.6, 0.9, 0.6))
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.size = Vector2(90, 20)


func _make_label(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_bar(parent: Node, pos: Vector2, bar_size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = bar_size
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	parent.add_child(bar)
	return bar


func _connect_signals() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.health_changed.connect(_on_health_changed)
	EventBus.shield_changed.connect(_on_shield_changed)
	EventBus.weapon_changed.connect(_on_weapon_changed)
	EventBus.weapon_exp_changed.connect(_on_xp_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.mod_acquired.connect(_on_mod_acquired)
	EventBus.game_started.connect(_on_game_started)


func _process(_delta: float) -> void:
	if _show_fps:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _on_game_started(_difficulty: int) -> void:
	_score_label.text = "SCORE 000000"
	_combo_label.text = ""
	_currency_label.text = "0 CR"
	_health_bar.value = 100
	_shield_bar.value = 0
	_xp_bar.value = 0
	_boss_box.visible = false
	_mods_label.text = ""


func _on_score_changed(score: int, combo: int) -> void:
	_score_label.text = "SCORE %06d" % score
	if combo > 1:
		_combo_label.text = "COMBO x%d" % combo
	else:
		_combo_label.text = ""


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_shield_changed(current: int, maximum: int) -> void:
	_shield_bar.max_value = maxi(1, maximum)
	_shield_bar.value = current


func _on_weapon_changed(weapon_id: String, level: int) -> void:
	var definition: Dictionary = WeaponSystem.WEAPONS[weapon_id]
	_weapon_label.text = "%s  ·  %s" % [String(definition["name"]).to_upper(), String(definition["blurb"])]
	_level_label.text = "LV %d" % level


func _on_xp_changed(exp: int, needed: int) -> void:
	_xp_bar.max_value = needed
	_xp_bar.value = exp


func _on_currency_changed(amount: int) -> void:
	_currency_label.text = "%d CR" % amount


func _on_mod_acquired(mod_id: String) -> void:
	var mod: Dictionary = WeaponSystem.MODS[mod_id]
	_mods_label.text = "MODS  " + ", ".join(WeaponSystem.mods.map(func(id: String) -> String: return String(WeaponSystem.MODS[id]["name"])))


func _on_boss_spawned(boss_name: String, hp: int, max_hp: int) -> void:
	_boss_name.text = boss_name.to_upper()
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	_boss_box.visible = true


func _on_boss_hp_changed(hp: int, max_hp: int) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp


func _on_boss_defeated(_boss_name: String) -> void:
	_boss_box.visible = false


func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if category == "visual" and key == "show_fps":
		_show_fps = bool(value)
		_fps_label.visible = _show_fps

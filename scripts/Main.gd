extends Node2D
## Scene assembly and run lifecycle.
##
## Main builds the world, the camera, the HUD and the overlays, starts the run
## and then gets out of the way: gameplay systems talk through EventBus.

const CRT_SHADER := preload("res://shaders/crt_palette_combined.gdshader")

var world: Node2D
var player: Player
var camera: Camera2D
var hud: HUD
var pause_menu: PauseMenu
var mod_select: ModSelect
var game_over_screen: GameOverScreen
var crt_layer: CanvasLayer
var crt_rect: ColorRect
var crt_material: ShaderMaterial

var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _game_over: bool = false


func _ready() -> void:
	if not GameManager.running:
		var saved_difficulty := int(SaveSystem.get_setting("gameplay", "difficulty", 1))
		GameManager.start_new_run(saved_difficulty)

	_build_background()

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	player.global_position = Vector2(220, 0)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(260, 0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)
	camera.make_current()

	hud = HUD.new()
	add_child(hud)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)

	mod_select = ModSelect.new()
	add_child(mod_select)

	game_over_screen = GameOverScreen.new()
	add_child(game_over_screen)

	_build_crt()

	EventBus.game_over.connect(_on_game_over)
	EventBus.screen_shake.connect(_on_screen_shake)
	EventBus.settings_changed.connect(_on_setting_changed)

	player.reset_for_run()
	LevelManager.start_run(GameManager.seed_value(), world, player)
	ReplaySystem.start_recording(GameManager.seed_value(), GameManager.difficulty, WeaponSystem.current_weapon)
	_apply_visual_settings()


func _build_background() -> void:
	var parallax := ParallaxBackground.new()
	parallax.name = "Parallax"
	parallax.layer = -10
	add_child(parallax)

	_add_parallax_layer(parallax, "nebula", 0.06, Color(0.55, 0.55, 0.8, 0.45), 3.0)
	_add_parallax_layer(parallax, "starfield", 0.18, Color(0.9, 0.9, 1.0, 0.9), 3.0)
	_add_parallax_layer(parallax, "mountains", 0.45, Color(0.7, 0.7, 0.9, 0.75), 1.0)


func _add_parallax_layer(parent: ParallaxBackground, texture_name: String, motion: float, tint: Color, scale_y: float) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(motion, motion * 0.35)
	var sprite := Sprite2D.new()
	sprite.texture = Art.texture(texture_name)
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var texture_size := sprite.texture.get_size()
	var scale_x := ceilf(1280.0 / texture_size.x) + 1.0
	var scale_y_needed := ceilf(720.0 / texture_size.y) + 1.0
	sprite.scale = Vector2(scale_x, scale_y_needed * scale_y)
	sprite.position = Vector2(-640, -360)
	sprite.modulate = tint
	layer.motion_mirroring = Vector2(texture_size.x * sprite.scale.x, 0)
	layer.add_child(sprite)
	parent.add_child(layer)


func _build_crt() -> void:
	crt_layer = CanvasLayer.new()
	crt_layer.name = "CRT"
	crt_layer.layer = 40
	add_child(crt_layer)
	crt_rect = ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_material = ShaderMaterial.new()
	crt_material.shader = CRT_SHADER
	crt_rect.material = crt_material
	crt_layer.add_child(crt_rect)


func _apply_visual_settings() -> void:
	var enabled := bool(SaveSystem.get_setting("visual", "crt_enabled", true))
	crt_layer.visible = enabled
	crt_material.set_shader_parameter("scanlines", float(SaveSystem.get_setting("visual", "scanlines", 0.6)))


func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	if category != "visual":
		return
	match key:
		"crt_enabled":
			crt_layer.visible = bool(value)
		"scanlines":
			crt_material.set_shader_parameter("scanlines", float(value))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		if mod_select.is_open():
			return
		pause_menu.set_paused(not pause_menu.is_open())
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var strength := _shake_strength * clampf(_shake_time / 0.35, 0.0, 1.0)
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func _on_screen_shake(strength: float, duration: float) -> void:
	if not bool(SaveSystem.get_setting("visual", "screen_shake", true)):
		return
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)


func _on_game_over(score: int, wave: int, stats: Dictionary) -> void:
	if _game_over:
		return
	_game_over = true
	ReplaySystem.stop_recording(score, wave)
	AudioManager.set_music_intensity(0)
	game_over_screen.show_results(score, wave, stats)

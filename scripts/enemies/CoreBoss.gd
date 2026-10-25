extends CharacterBody2D
class_name CoreBoss
## Chunk bosses. Each boss owns a list of attack patterns; the boss advances to
## the next pattern every time a quarter of its health is gone.

const LAYER_ENEMY := 3

const BOSSES := [
	{
		"name": "Core Interceptor",
		"hp": 2600.0,
		"patterns": [
			{"type": "spiral", "interval": 0.12, "count": 8, "speed": 240.0},
			{"type": "aimed", "interval": 1.2, "count": 5, "speed": 380.0},
			{"type": "radial", "interval": 1.0, "count": 14, "speed": 220.0},
		],
	},
	{
		"name": "Void Warden",
		"hp": 5200.0,
		"patterns": [
			{"type": "radial", "interval": 0.9, "count": 18, "speed": 200.0},
			{"type": "orbs", "interval": 2.0, "count": 6, "speed": 190.0},
			{"type": "spiral", "interval": 0.09, "count": 10, "speed": 260.0},
			{"type": "teleport", "interval": 2.6, "count": 1, "speed": 0.0},
		],
	},
	{
		"name": "Neon Titan",
		"hp": 9000.0,
		"patterns": [
			{"type": "aimed", "interval": 0.8, "count": 7, "speed": 420.0},
			{"type": "spiral", "interval": 0.07, "count": 12, "speed": 300.0},
			{"type": "radial", "interval": 0.7, "count": 20, "speed": 240.0},
			{"type": "orbs", "interval": 1.6, "count": 8, "speed": 220.0},
		],
	},
	{
		"name": "The Architect",
		"hp": 14000.0,
		"patterns": [
			{"type": "spiral", "interval": 0.06, "count": 14, "speed": 320.0},
			{"type": "radial", "interval": 0.6, "count": 24, "speed": 260.0},
			{"type": "aimed", "interval": 0.6, "count": 9, "speed": 460.0},
			{"type": "orbs", "interval": 1.4, "count": 10, "speed": 240.0},
			{"type": "teleport", "interval": 2.0, "count": 1, "speed": 0.0},
		],
	},
]

var boss_name: String = "Core Interceptor"
var hp: float = 100.0
var max_hp: float = 100.0
var phase: int = 0
var patterns: Array = []
var _attack_timer: float = 1.0
var _phase_timer: float = 0.0
var _invuln: bool = false
var _alive: bool = false
var _spin: float = 0.0
var _anchor: Vector2 = Vector2.ZERO
var _phase_threshold: float = 0.75

var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1 << (LAYER_ENEMY - 1)
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var circle := CircleShape2D.new()
	circle.radius = 62.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("boss_core")
	_sprite.scale = Vector2(2.0, 2.0)
	add_child(_sprite)


func activate(boss_index: int, hp_scale: float) -> void:
	var definition: Dictionary = BOSSES[boss_index % BOSSES.size()]
	boss_name = String(definition["name"])
	patterns = (definition["patterns"] as Array).duplicate(true)
	max_hp = float(definition["hp"]) * maxf(0.5, hp_scale)
	hp = max_hp
	phase = 0
	_phase_threshold = 0.75
	_attack_timer = 1.5
	_phase_timer = 0.0
	_invuln = false
	_alive = true
	_anchor = global_position
	add_to_group("enemies")
	AudioManager.play_sfx("boss_spawn")
	AudioManager.set_music_intensity(3)
	EventBus.boss_spawned.emit(boss_name, int(hp), int(max_hp))


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_spin += delta
	_sprite.rotation = _spin * 0.6
	# Slow vertical hover so the fight is not a static target.
	var drift := sin(_spin * 0.8) * 120.0
	global_position.y = lerpf(global_position.y, _anchor.y + drift, 2.0 * delta)
	global_position.x = lerpf(global_position.x, _anchor.x, 1.5 * delta)

	_attack_timer -= delta
	_phase_timer += delta
	if _attack_timer <= 0.0:
		_run_pattern()
		_attack_timer = float(patterns[phase].get("interval", 1.0))

	if GameManager.running == false:
		_attack_timer = 1.0


func _run_pattern() -> void:
	var pattern: Dictionary = patterns[phase]
	var count := int(pattern.get("count", 8))
	var speed := float(pattern.get("speed", 220.0))
	var target := _player()
	match String(pattern["type"]):
		"spiral":
			for i in count:
				var angle := TAU * float(i) / float(count) + _spin * 2.0
				_fire(angle, speed)
		"radial":
			for i in count:
				var angle := TAU * float(i) / float(count)
				_fire(angle, speed)
		"aimed":
			if target != null:
				var base := global_position.angle_to_point(target.global_position) + PI
				for i in count:
					var offset := (float(i) - float(count - 1) * 0.5) * 0.12
					_fire(base + offset, speed)
		"orbs":
			for i in count:
				var angle := randf() * TAU
				_fire(angle, speed, 2.5)
		"teleport":
			if target != null:
				var blast := ObjectPool.acquire("explosion")
				if blast != null and blast.has_method("activate"):
					blast.call("activate", global_position, 2.0, Color(0.8, 0.3, 1.0))
				_anchor = target.global_position + Vector2(randf_range(260.0, 420.0), randf_range(-200.0, 200.0))
				global_position = _anchor
				AudioManager.play_sfx("dash")


func _fire(angle: float, speed: float, homing: float = 0.0) -> void:
	var bullet := ObjectPool.acquire("bullet_enemy")
	if bullet == null:
		return
	var stats := {
		"speed": speed,
		"damage": 10,
		"pierce": 0,
		"color": Color(1.0, 0.4, 0.9),
		"homing": homing,
		"crit_chance": 0.0,
		"crit_mult": 1.0,
		"effects": [],
	}
	bullet.call("fire", global_position, angle, stats, true)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func take_damage(amount: int, crit: bool = false) -> void:
	if not _alive or _invuln:
		return
	hp -= float(amount)
	AudioManager.play_sfx("boss_hit")
	_sprite.modulate = Color(2.0, 2.0, 2.0) if crit else Color(1.5, 1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
	EventBus.boss_hp_changed.emit(int(hp), int(max_hp))
	_check_phase()


func _check_phase() -> void:
	if hp <= 0.0:
		_die()
		return
	if hp <= max_hp * _phase_threshold:
		phase = mini(phase + 1, patterns.size() - 1)
		_phase_threshold -= 0.25
		_invuln = true
		_attack_timer = 0.8
		AudioManager.play_sfx("level_up")
		var tween := create_tween()
		tween.tween_interval(0.6)
		tween.tween_callback(func() -> void: _invuln = false)


func _die() -> void:
	_alive = false
	remove_from_group("enemies")
	GameManager.register_kill()
	GameManager.add_score(1500)
	GameManager.run_data["bosses_killed"] = int(GameManager.run_data.get("bosses_killed", 0)) + 1
	AudioManager.play_sfx("boss_death")
	AudioManager.set_music_intensity(1)
	EventBus.screen_shake.emit(20.0, 0.8)
	EventBus.boss_defeated.emit(boss_name)
	for i in 5:
		var blast := ObjectPool.acquire("explosion")
		if blast == null:
			continue
		var offset := Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0))
		if blast.has_method("activate"):
			blast.call("activate", global_position + offset, randf_range(1.5, 3.0), Color(1.0, 0.6, 0.3))
	# Reward drops.
	for kind in ["health", "weapon", "mod"]:
		var pickup := ObjectPool.acquire("powerup")
		if pickup == null:
			continue
		pickup.global_position = global_position + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
		if pickup.has_method("activate"):
			pickup.call("activate", kind)
	queue_free()

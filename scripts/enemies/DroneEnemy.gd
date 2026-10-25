extends CharacterBody2D
class_name DroneEnemy
## Standard enemy. Pooled, so `activate()` resets every field that matters.

const LAYER_ENEMY := 3

var hp: float = 20.0
var max_hp: float = 20.0
var behaviour: String = "strafe"
var elite: bool = false
var _speed: float = 150.0
var _fire_timer: float = 1.5
var _pattern_time: float = 0.0
var _slow_time: float = 0.0
var _base_y: float = 0.0
var _alive: bool = false

var _sprite: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << (LAYER_ENEMY - 1)
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var circle := CircleShape2D.new()
	circle.radius = 20.0 if elite else 17.0
	_shape = CollisionShape2D.new()
	_shape.shape = circle
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("elite_drone" if elite else "drone")
	_sprite.scale = Vector2(2.6, 2.6)
	add_child(_sprite)


func _on_acquire() -> void:
	_alive = true
	add_to_group("enemies")


func _on_release() -> void:
	_alive = false
	remove_from_group("enemies")
	velocity = Vector2.ZERO


func activate(hp_multiplier: float, behaviour_name: String = "strafe", is_elite: bool = false) -> void:
	elite = is_elite
	behaviour = behaviour_name
	max_hp = (34.0 if is_elite else 18.0) * maxf(0.2, hp_multiplier)
	hp = max_hp
	_speed = (110.0 if is_elite else 150.0) * (0.8 + 0.1 * GameManager.difficulty)
	_fire_timer = randf_range(0.8, 2.0)
	_pattern_time = randf() * TAU
	_slow_time = 0.0
	_base_y = global_position.y
	_sprite.texture = Art.texture("elite_drone" if is_elite else "drone")
	_sprite.scale = Vector2(3.0, 3.0) if is_elite else Vector2(2.6, 2.6)
	_sprite.modulate = Color.WHITE
	_alive = true


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_pattern_time += delta
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)

	var speed_scale := 0.45 if _slow_time > 0.0 else 1.0
	match behaviour:
		"dive":
			velocity = Vector2(-_speed * 1.6, sin(_pattern_time * 3.0) * 120.0)
		"pulse":
			velocity = Vector2(-_speed * 0.55, sin(_pattern_time * 2.0) * 220.0)
		"hunt":
			var target := _player()
			if target != null:
				velocity = global_position.direction_to(target.global_position) * _speed * 0.9
			else:
				velocity = Vector2(-_speed, 0.0)
		_:
			velocity = Vector2(-_speed, (_base_y - global_position.y) * 0.8 + sin(_pattern_time) * 60.0)

	move_and_slide()
	velocity *= speed_scale

	# Face the player.
	_sprite.flip_h = global_position.x < _player_x()

	_fire_timer -= delta
	if _fire_timer <= 0.0 and _on_screen():
		_shoot()
		_fire_timer = randf_range(1.1, 2.2) / (1.0 + 0.15 * GameManager.difficulty)

	if global_position.x < _player_x() - 900.0:
		_despawn()


func _player() -> Node2D:
	var node := get_tree().get_first_node_in_group("player")
	return node as Node2D


func _player_x() -> float:
	var target := _player()
	return target.global_position.x if target != null else global_position.x


func _on_screen() -> bool:
	var target := _player()
	if target == null:
		return false
	var distance := global_position.x - target.global_position.x
	return distance < 1400.0 and distance > -200.0


func _shoot() -> void:
	var target := _player()
	if target == null:
		return
	var angle := global_position.angle_to_point(target.global_position) + PI
	var stats := {
		"speed": 300.0 + 20.0 * GameManager.difficulty,
		"damage": 8,
		"pierce": 0,
		"color": Color(1.0, 0.35, 0.35),
		"crit_chance": 0.0,
		"crit_mult": 1.0,
		"effects": [],
	}
	if elite:
		stats["damage"] = 12
		for i in 3:
			var bullet := ObjectPool.acquire("bullet_enemy")
			if bullet != null:
				bullet.call("fire", global_position, angle + (float(i) - 1.0) * 0.18, stats, true)
	else:
		var bullet := ObjectPool.acquire("bullet_enemy")
		if bullet != null:
			bullet.call("fire", global_position, angle, stats, true)


func apply_slow(duration: float) -> void:
	_slow_time = maxf(_slow_time, duration)
	_sprite.modulate = Color(0.6, 0.8, 1.4)


func take_damage(amount: int, crit: bool = false) -> void:
	if not _alive:
		return
	hp -= float(amount)
	_sprite.modulate = Color(2.0, 2.0, 2.0) if crit else Color(1.4, 1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		_die()


func _die() -> void:
	GameManager.register_kill()
	GameManager.add_score(10 if not elite else 40)
	WeaponSystem.add_xp(12 if elite else 5)
	AudioManager.play_sfx("explosion_small")
	var blast := ObjectPool.acquire("explosion")
	if blast != null:
		blast.global_position = global_position
		if blast.has_method("activate"):
			blast.call("activate", global_position, 1.0, Color(1.0, 0.6, 0.2))
	_drop_loot()
	_despawn()


func _drop_loot() -> void:
	if randf() > 0.16:
		return
	var pickup := ObjectPool.acquire("powerup")
	if pickup == null:
		return
	pickup.global_position = global_position
	var roll := randf()
	var kind := "currency"
	if roll > 0.75:
		kind = "health"
	elif roll > 0.5:
		kind = "weapon"
	if pickup.has_method("activate"):
		pickup.call("activate", kind)


func _despawn() -> void:
	ObjectPool.release("drone", self)

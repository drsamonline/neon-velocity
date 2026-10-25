extends CharacterBody2D
class_name Player
## The ship.
##
## Movement, dash, firing (all six weapons) and damage intake. The camera is a
## child of this node, added by Main.

const LAYER_PLAYER := 2
const MAX_HEALTH := 100

var move_speed: float = 420.0
var dash_speed: float = 1250.0
var dash_duration: float = 0.16
var dash_cooldown: float = 0.7

var health: int = MAX_HEALTH
var shield: int = 0
var max_shield: int = 40

var _fire_cooldown: float = 0.0
var _dash_time: float = 0.0
var _dash_cooldown_time: float = 0.0
var _invuln_time: float = 0.0
var _ramp_hits: int = 0
var _ramp_timer: float = 0.0
var _dead: bool = false

var _sprite: Sprite2D
var _thruster: Sprite2D
var _tilt: float = 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << (LAYER_PLAYER - 1)
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("player_ship")
	_sprite.scale = Vector2(2.4, 2.4)
	add_child(_sprite)

	_thruster = Sprite2D.new()
	_thruster.texture = Art.texture("spark")
	_thruster.scale = Vector2(1.4, 1.0)
	_thruster.modulate = Color(0.4, 0.8, 1.0, 0.9)
	_thruster.position = Vector2(-40, 0)
	add_child(_thruster)

	EventBus.weapon_changed.connect(_on_weapon_changed)


func reset_for_run() -> void:
	health = MAX_HEALTH
	shield = 0
	_dead = false
	visible = true
	set_physics_process(true)
	_ramp_hits = 0
	EventBus.health_changed.emit(health, MAX_HEALTH)
	EventBus.shield_changed.emit(shield, max_shield)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_tick_timers(delta)

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed

	if _dash_time > 0.0:
		velocity = _dash_dir * dash_speed
		_tilt = lerpf(_tilt, _dash_dir.angle() * 0.2, 10.0 * delta)
	else:
		_tilt = lerpf(_tilt, direction.y * 0.25, 6.0 * delta)

	move_and_slide()
	_clamp_to_view()

	if Input.is_action_just_pressed("weapon_next"):
		WeaponSystem.cycle_weapon(1)
	if Input.is_action_just_pressed("weapon_prev"):
		WeaponSystem.cycle_weapon(-1)

	_handle_firing(delta)

	_sprite.rotation = _tilt
	_thruster.visible = direction != Vector2.ZERO or _dash_time > 0.0
	_thruster.modulate.a = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.02))

	if ReplaySystem.recording:
		ReplaySystem.record_frame(direction, Input.is_action_pressed("fire"), _dash_time > 0.0)


var _dash_dir: Vector2 = Vector2.RIGHT


func _tick_timers(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_dash_cooldown_time = maxf(0.0, _dash_cooldown_time - delta)
	_invuln_time = maxf(0.0, _invuln_time - delta)
	_ramp_timer = maxf(0.0, _ramp_timer - delta)
	if _ramp_timer <= 0.0:
		_ramp_hits = 0
	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
	if Input.is_action_just_pressed("dash") and _dash_cooldown_time <= 0.0:
		_start_dash()


func _start_dash() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_dir = direction if direction != Vector2.ZERO else Vector2.RIGHT
	_dash_time = dash_duration
	_dash_cooldown_time = dash_cooldown
	_invuln_time = maxf(_invuln_time, dash_duration + 0.05)
	AudioManager.play_sfx("dash")
	var ghost := ObjectPool.acquire("spark")
	if ghost != null:
		ghost.global_position = global_position
		if ghost.has_method("activate"):
			ghost.call("activate", global_position, Color(0.4, 0.8, 1.0), 2.0)


func _clamp_to_view() -> void:
	global_position.y = clampf(global_position.y, -320.0, 320.0)
	global_position.x = maxf(global_position.x, 80.0)


func _handle_firing(_delta: float) -> void:
	if not Input.is_action_pressed("fire") or _fire_cooldown > 0.0:
		return
	var stats := WeaponSystem.get_stats()
	_fire(stats)
	_fire_cooldown = float(stats["fire_rate"])
	GameManager.count_shot()


func _fire(stats: Dictionary) -> void:
	var kind := String(stats.get("kind", "projectile"))
	AudioManager.play_sfx("shoot_%s" % WeaponSystem.current_weapon)

	match kind:
		"nova":
			_fire_nova(stats)
		_:
			_fire_projectiles(stats)


func _fire_projectiles(stats: Dictionary) -> void:
	var count := int(stats.get("count", 1))
	var spread := float(stats.get("spread", 0.0))
	var muzzle := global_position + Vector2(34.0, 0.0)
	# Gentle aim assist: the ship still has to line up, but a shot that is within
	# ten degrees of an enemy bends onto it. Without this the game reads as
	# broken on a first run, because a straight line misses anything a little
	# above or below the ship.
	var assist := _aim_assist_angle()
	for i in count:
		var angle := assist
		if count > 1:
			angle = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var bullet := ObjectPool.acquire("bullet_player")
		if bullet == null:
			return
		var shot := stats.duplicate(true)
		shot["damage"] = _damage_with_ramp(int(stats["damage"]))
		bullet.call("fire", muzzle, angle, shot, false)


func _aim_assist_angle() -> float:
	var nearest: Node2D = null
	var best := 1400.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var target := node as Node2D
		var offset := target.global_position - global_position
		if offset.x < 60.0:
			continue
		var distance := offset.length()
		if distance < best:
			best = distance
			nearest = target
	if nearest == null:
		return 0.0
	var angle := (nearest.global_position - global_position).angle()
	return clampf(angle, -0.18, 0.18)


func _damage_with_ramp(base: int) -> int:
	if not WeaponSystem.has_effect("ramp"):
		return base
	_ramp_hits = mini(_ramp_hits + 1, 10)
	_ramp_timer = 1.2
	return int(round(float(base) * (1.0 + 0.05 * float(_ramp_hits))))


func _fire_nova(stats: Dictionary) -> void:
	var radius := float(stats.get("radius", 150.0))
	var damage := _damage_with_ramp(int(stats["damage"]))
	var pulses := 3 if (stats.get("effects", []) as Array).has("multi_pulse") else 1
	AudioManager.play_sfx("shoot_nova")
	EventBus.screen_shake.emit(6.0, 0.25)
	for pulse in pulses:
		_apply_nova_pulse(radius, damage, pulse)


func _apply_nova_pulse(radius: float, damage: int, pulse: int) -> void:
	var blast := ObjectPool.acquire("explosion")
	if blast != null:
		blast.global_position = global_position
		if blast.has_method("activate"):
			blast.call("activate", global_position, radius / 40.0, Color(1.0, 1.0, 0.4))
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var distance := global_position.distance_to((node as Node2D).global_position)
		if distance <= radius * (1.0 + 0.15 * float(pulse)):
			node.call("take_damage", damage, false)
			GameManager.count_hit()


func take_damage(amount: int) -> void:
	if _dead or _invuln_time > 0.0:
		return
	var scaled := int(round(float(amount) * GameManager.multiplier("damage")))
	if shield > 0:
		var absorbed := mini(shield, scaled)
		shield -= absorbed
		scaled -= absorbed
		EventBus.shield_changed.emit(shield, max_shield)
	if scaled > 0:
		health = maxi(0, health - scaled)
		GameManager.add_damage_taken(scaled)
		EventBus.health_changed.emit(health, MAX_HEALTH)
	_invuln_time = 0.8
	AudioManager.play_sfx("hit_player")
	EventBus.screen_shake.emit(9.0, 0.3)
	_flash()
	if health <= 0:
		_die()


func heal(amount: int) -> void:
	if _dead:
		return
	health = mini(MAX_HEALTH, health + amount)
	EventBus.health_changed.emit(health, MAX_HEALTH)


func add_shield(amount: int) -> void:
	shield = mini(max_shield, shield + amount)
	EventBus.shield_changed.emit(shield, max_shield)


func add_weapon_xp(amount: int) -> void:
	WeaponSystem.add_xp(amount)


func _flash() -> void:
	_sprite.modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func _die() -> void:
	_dead = true
	visible = false
	set_physics_process(false)
	var blast := ObjectPool.acquire("explosion")
	if blast != null:
		blast.global_position = global_position
		if blast.has_method("activate"):
			blast.call("activate", global_position, 3.0, Color(1.0, 0.5, 0.2))
	AudioManager.play_sfx("explosion_large")
	EventBus.screen_shake.emit(18.0, 0.6)
	GameManager.end_run(false)


func _on_weapon_changed(_weapon_id: String, _level: int) -> void:
	pass


func is_dead() -> bool:
	return _dead

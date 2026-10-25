extends Area2D
class_name Bullet
## A single pooled projectile, used for both the player and enemies.
##
## Collision is Area2D vs CharacterBody2D: player bullets watch layer 3
## (enemies), enemy bullets watch layer 2 (the player).

const LAYER_PLAYER := 2
const LAYER_ENEMY := 3
const LAYER_PLAYER_BULLET := 4
const LAYER_ENEMY_BULLET := 5

var _velocity: Vector2 = Vector2.ZERO
var _speed: float = 800.0
var _damage: int = 10
var _pierce_left: int = 0
var _life: float = 3.0
var _homing: float = 0.0
var _hostile: bool = false
var _effects: Array = []
var _crit_chance: float = 0.0
var _crit_mult: float = 2.0
var _bounces: int = 0
var _pool_name: String = "bullet_player"
var _sprite: Sprite2D
var _homing_target: Node2D = null
var _retarget_timer: float = 0.0

@onready var _shape: CollisionShape2D = null


func _ready() -> void:
	monitoring = true
	monitorable = false
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	_shape = CollisionShape2D.new()
	_shape.shape = circle
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("bullet_player")
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _on_acquire() -> void:
	set_deferred("monitoring", true)
	_life = 4.0
	_homing_target = null


func _on_release() -> void:
	set_deferred("monitoring", false)
	_velocity = Vector2.ZERO


## direction is an angle in radians; stats comes from WeaponSystem.get_stats().
func fire(pos: Vector2, angle: float, stats: Dictionary, hostile: bool = false) -> void:
	global_position = pos
	rotation = angle
	_velocity = Vector2(cos(angle), sin(angle))
	_speed = float(stats.get("speed", 800.0))
	_damage = int(stats.get("damage", 10))
	_pierce_left = int(stats.get("pierce", 0))
	_homing = float(stats.get("homing", 0.0))
	_crit_chance = float(stats.get("crit_chance", 0.0))
	_crit_mult = float(stats.get("crit_mult", 2.0))
	_effects = stats.get("effects", [])
	_hostile = hostile
	_bounces = 1 if _effects.has("bounce") else 0
	_pool_name = "bullet_enemy" if hostile else "bullet_player"
	_life = 4.0
	_homing_target = null

	if hostile:
		collision_layer = 1 << (LAYER_ENEMY_BULLET - 1)
		collision_mask = 1 << (LAYER_PLAYER - 1)
		_sprite.texture = Art.texture("bullet_enemy")
		_sprite.modulate = Color.WHITE
		_sprite.scale = Vector2(1.6, 1.6)
	else:
		collision_layer = 1 << (LAYER_PLAYER_BULLET - 1)
		collision_mask = 1 << (LAYER_ENEMY - 1)
		var is_missile: bool = stats.get("id", "") == "missile"
		_sprite.texture = Art.texture("missile" if is_missile else "bullet_player")
		_sprite.scale = Vector2(2, 2) if not is_missile else Vector2(1.6, 1.6)
		_sprite.modulate = stats.get("color", Color.WHITE)


func _physics_process(delta: float) -> void:
	if _homing > 0.0:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0 or not is_instance_valid(_homing_target):
			_retarget_timer = 0.15
			_homing_target = _nearest_enemy()
		if is_instance_valid(_homing_target):
			var want := global_position.angle_to_point(_homing_target.global_position) + PI
			rotation = lerp_angle(rotation, want, clampf(_homing * delta, 0.0, 1.0))
			_velocity = Vector2(cos(rotation), sin(rotation))

	global_position += _velocity * _speed * delta
	_life -= delta
	if _life <= 0.0:
		_despawn()
		return

	# Recycle well outside the camera window.
	var camera_x := _camera_x()
	if global_position.x > camera_x + 1500.0 or global_position.x < camera_x - 1300.0:
		_despawn()
		return
	if global_position.y > 460.0 or global_position.y < -460.0:
		if _bounces > 0:
			_bounces -= 1
			_velocity.y = -_velocity.y
			rotation = _velocity.angle()
		else:
			_despawn()


func _camera_x() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return (player as Node2D).global_position.x
	return global_position.x


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := 900.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node):
			var distance := global_position.distance_to((node as Node2D).global_position)
			if distance < best_distance:
				best_distance = distance
				best = node
	return best


func _on_body_entered(body: Node) -> void:
	if _hostile:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", _damage)
			_despawn()
		return

	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	var crit := _crit_chance > 0.0 and randf() < _crit_chance
	var amount := int(round(float(_damage) * (_crit_mult if crit else 1.0)))
	body.call("take_damage", amount, crit)
	GameManager.count_hit()

	if _effects.has("lifesteal"):
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("heal"):
			player.call("heal", 1)

	if _effects.has("chain"):
		_chain_to_neighbours(body as Node2D, amount)

	if _effects.has("emp"):
		_apply_slow(body as Node2D)

	if _effects.has("split") and body.has_method("get") and body.get("global_position") != null:
		_split(body as Node2D)

	var spark := ObjectPool.acquire("spark")
	if spark != null:
		spark.global_position = global_position
		if spark.has_method("activate"):
			spark.call("activate", global_position, Color(1.0, 0.9, 0.4), 1.0)
	AudioManager.play_sfx("hit_enemy")

	_pierce_left -= 1
	if _pierce_left < 0:
		_despawn()


func _chain_to_neighbours(origin: Node2D, amount: int) -> void:
	var jumps := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if jumps >= 2:
			return
		if node == origin or not (node is Node2D):
			continue
		if origin.global_position.distance_to((node as Node2D).global_position) <= 220.0:
			node.call("take_damage", int(amount * 0.5), false)
			jumps += 1


func _apply_slow(target: Node2D) -> void:
	if target.has_method("apply_slow"):
		target.call("apply_slow", 1.5)


func _split(origin: Node2D) -> void:
	if not _effects.has("split"):
		return
	for i in 3:
		var angle := -0.6 + 0.6 * float(i)
		var mini_bullet := ObjectPool.acquire("bullet_player")
		if mini_bullet == null:
			return
		var stats := {
			"speed": 500.0, "damage": int(float(_damage) * 0.5), "pierce": 0,
			"color": Color(1.0, 0.7, 0.2), "id": "missile", "homing": 4.0,
			"crit_chance": 0.0, "crit_mult": 1.0, "effects": [],
		}
		mini_bullet.call("fire", origin.global_position, angle, stats, false)


func _despawn() -> void:
	ObjectPool.release(_pool_name, self)

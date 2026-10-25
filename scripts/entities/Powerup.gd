extends Area2D
class_name Powerup
## Floating pickup. Pooled.

const LAYER_PICKUP := 6
const LAYER_PLAYER := 2

const KINDS := {
	"health": {"sprite": "pickup_health", "sfx": "pickup_health"},
	"currency": {"sprite": "pickup_currency", "sfx": "pickup_currency"},
	"shield": {"sprite": "pickup_shield", "sfx": "pickup_shield"},
	"weapon": {"sprite": "pickup_weapon", "sfx": "pickup_weapon"},
	"mod": {"sprite": "pickup_mod", "sfx": "pickup_mod"},
}

var kind: String = "currency"
var _sprite: Sprite2D
var _bob: float = 0.0
var _base_y: float = 0.0
var _armed: bool = false


func _ready() -> void:
	collision_layer = 1 << (LAYER_PICKUP - 1)
	collision_mask = 1 << (LAYER_PLAYER - 1)
	monitoring = true
	monitorable = false
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("pickup_currency")
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _on_acquire() -> void:
	_armed = true
	_bob = 0.0
	set_deferred("monitoring", true)


func _on_release() -> void:
	_armed = false
	set_deferred("monitoring", false)


func activate(pickup_kind: String) -> void:
	kind = pickup_kind if KINDS.has(pickup_kind) else "currency"
	_sprite.texture = Art.texture(String(KINDS[kind]["sprite"]))
	_base_y = global_position.y
	_bob = randf() * TAU
	_armed = true


func _process(delta: float) -> void:
	if not _armed:
		return
	_bob += delta * 3.0
	global_position.y = _base_y + sin(_bob) * 10.0
	_sprite.rotation = sin(_bob * 0.6) * 0.25


func _on_body_entered(body: Node) -> void:
	if not _armed or not body.is_in_group("player"):
		return
	_armed = false
	_apply(body)
	AudioManager.play_sfx(String(KINDS[kind]["sfx"]))
	var spark := ObjectPool.acquire("spark")
	if spark != null and spark.has_method("activate"):
		spark.call("activate", global_position, Color(1.0, 1.0, 0.6), 1.4)
	ObjectPool.release("powerup", self)


func _apply(player: Node) -> void:
	match kind:
		"health":
			player.call("heal", 30)
		"currency":
			GameManager.add_currency(15)
			GameManager.add_score(5)
		"shield":
			player.call("add_shield", 20)
		"weapon":
			player.call("add_weapon_xp", 60)
			GameManager.add_score(15)
		"mod":
			EventBus.mod_choices_offered.emit(WeaponSystem.roll_mod_choices(3))

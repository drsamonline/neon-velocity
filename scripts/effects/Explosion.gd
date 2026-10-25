extends Node2D
class_name Explosion
## Expanding shockwave ring, pooled.

var _sprite: Sprite2D
var _time: float = 0.0
var _duration: float = 0.45
var _size: float = 1.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("shockwave")
	_sprite.scale = Vector2(0.5, 0.5)
	add_child(_sprite)


func _on_acquire() -> void:
	_time = 0.0


func _on_release() -> void:
	_time = 0.0


func activate(pos: Vector2, size: float = 1.0, color: Color = Color(1.0, 0.7, 0.3)) -> void:
	global_position = pos
	_size = size
	_sprite.modulate = color
	_sprite.scale = Vector2.ONE * 0.4 * size


func _process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _duration, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * (0.4 + t * 2.2) * _size
	_sprite.modulate.a = 1.0 - t
	if t >= 1.0:
		ObjectPool.release("explosion", self)

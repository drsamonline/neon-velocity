extends Node2D
class_name Spark
## Short-lived impact spark, pooled.

var _sprite: Sprite2D
var _time: float = 0.0
var _duration: float = 0.18


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = Art.texture("spark")
	_sprite.scale = Vector2(1.6, 1.6)
	add_child(_sprite)


func _on_acquire() -> void:
	_time = 0.0


func _on_release() -> void:
	_time = 0.0


func activate(pos: Vector2, color: Color = Color.WHITE, size: float = 1.0) -> void:
	global_position = pos
	_sprite.modulate = color
	_sprite.scale = Vector2.ONE * 1.6 * size


func _process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / _duration, 0.0, 1.0)
	_sprite.modulate.a = 1.0 - t
	_sprite.scale = Vector2.ONE * (1.6 + t * 2.0)
	if t >= 1.0:
		ObjectPool.release("spark", self)

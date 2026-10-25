extends Node
## Preallocated object pool.
##
## Bullets, sparks, drones and pickups are recycled instead of allocated, which
## is what keeps the frame time flat at 200+ entities. Pooled nodes stay children
## of this autoload (identity transform) and are positioned in world space; the
## camera moves the canvas, so they render correctly wherever they are parented.

const POOL_DEFS := {
	"bullet_player": {"script": preload("res://scripts/entities/Bullet.gd"), "size": 220},
	"bullet_enemy": {"script": preload("res://scripts/entities/Bullet.gd"), "size": 320},
	"drone": {"script": preload("res://scripts/enemies/DroneEnemy.gd"), "size": 60},
	"powerup": {"script": preload("res://scripts/entities/Powerup.gd"), "size": 24},
	"spark": {"script": preload("res://scripts/effects/Spark.gd"), "size": 48},
	"explosion": {"script": preload("res://scripts/effects/Explosion.gd"), "size": 24},
}

var _pools: Dictionary = {}
var _active: Dictionary = {}
var _factories: Dictionary = {}


func _ready() -> void:
	for pool_name in POOL_DEFS:
		var def: Dictionary = POOL_DEFS[pool_name]
		_factories[pool_name] = def["script"]
		var bucket: Array[Node2D] = []
		for i in int(def["size"]):
			var node: Node2D = _instantiate(pool_name)
			add_child(node)
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node.has_method("_on_release"):
				node.call("_on_release")
			bucket.append(node)
		_pools[pool_name] = bucket
		_active[pool_name] = []


func _instantiate(pool_name: String) -> Node2D:
	var script: Script = _factories[pool_name]
	var node: Node2D = script.new()
	node.name = "%s_%d" % [pool_name, randi() % 100000]
	return node


func acquire(pool_name: String) -> Node2D:
	if not _pools.has(pool_name):
		push_warning("Unknown pool '%s'" % pool_name)
		return null
	var bucket: Array = _pools[pool_name]
	var node: Node2D
	if bucket.is_empty():
		# Pool exhausted: grow rather than drop the entity, but say so once.
		push_warning("Pool '%s' exhausted, growing." % pool_name)
		node = _instantiate(pool_name)
		add_child(node)
	else:
		node = bucket.pop_back()
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("_on_acquire"):
		node.call("_on_acquire")
	var active: Array = _active[pool_name]
	active.append(node)
	return node


func release(pool_name: String, node: Node2D) -> void:
	if node == null or not _pools.has(pool_name):
		return
	var active: Array = _active[pool_name]
	active.erase(node)
	node.visible = false
	# Deferred: release() is usually called from a physics callback, and Godot
	# refuses to disable a CollisionObject mid-flush.
	node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if node.has_method("_on_release"):
		node.call("_on_release")
	var bucket: Array = _pools[pool_name]
	if not bucket.has(node):
		bucket.append(node)


func release_all(pool_name: String) -> void:
	if not _active.has(pool_name):
		return
	var active: Array = _active[pool_name]
	for node in active.duplicate():
		release(pool_name, node)


func active_count(pool_name: String) -> int:
	return _active.get(pool_name, []).size()

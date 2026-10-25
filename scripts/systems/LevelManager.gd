extends Node
## Chunk streaming and deterministic spawns.
##
## The world is an endless strip of fixed-width chunks. Each chunk's contents
## come from a RandomNumberGenerator seeded with run_seed + chunk index, so a
## given seed always produces the same run.

const CHUNK_WIDTH := 2400.0
const CHUNKS_AHEAD := 2
const CHUNKS_BEHIND := 2
const BOSS_EVERY := 5

## Spawn patterns: formation, count, hp multiplier, behaviour.
const PATTERNS := [
	{"formation": "line", "count": [4, 7], "hp": 1.0, "behaviour": "strafe", "min_chunk": 0},
	{"formation": "vee", "count": [3, 6], "hp": 1.1, "behaviour": "dive", "min_chunk": 1},
	{"formation": "grid", "count": [6, 10], "hp": 0.9, "behaviour": "pulse", "min_chunk": 2},
	{"formation": "ring", "count": [6, 9], "hp": 1.2, "behaviour": "hunt", "min_chunk": 3},
	{"formation": "vee", "count": [3, 5], "hp": 2.4, "behaviour": "hunt", "min_chunk": 5, "elite": true},
]

var world: Node2D = null
var player: Node2D = null
var run_seed: int = 0
var current_chunk: int = -1
var chunks: Dictionary = {}
var bosses_spawned: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func start_run(seed_value: int, world_node: Node2D, player_node: Node2D) -> void:
	clear()
	run_seed = seed_value
	world = world_node
	player = player_node
	current_chunk = -1
	_rng.seed = run_seed
	_update_chunk()


func clear() -> void:
	for index in chunks:
		var chunk: Node2D = chunks[index]
		if is_instance_valid(chunk):
			chunk.queue_free()
	chunks.clear()
	bosses_spawned.clear()
	ObjectPool.release_all("drone")
	ObjectPool.release_all("bullet_enemy")
	ObjectPool.release_all("powerup")
	ObjectPool.release_all("spark")
	ObjectPool.release_all("explosion")
	current_chunk = -1


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_update_chunk()


func _update_chunk() -> void:
	var index := int(floor(player.global_position.x / CHUNK_WIDTH))
	if index == current_chunk:
		return
	current_chunk = index
	for i in range(index - CHUNKS_BEHIND, index + CHUNKS_AHEAD + 1):
		if i < 0:
			continue
		if not chunks.has(i):
			_spawn_chunk(i)
	# Retire chunks the player has left well behind.
	for existing in chunks.keys():
		if int(existing) < index - CHUNKS_BEHIND:
			var chunk: Node2D = chunks[existing]
			if is_instance_valid(chunk):
				chunk.queue_free()
			chunks.erase(existing)
	GameManager.set_wave(int(index / BOSS_EVERY) + 1)
	AudioManager.set_music_intensity(clampi(int(index / 2), 0, 3))
	EventBus.chunk_started.emit(index)


func _spawn_chunk(index: int) -> void:
	var chunk := Node2D.new()
	chunk.name = "Chunk%d" % index
	chunk.position = Vector2(index * CHUNK_WIDTH, 0)
	world.add_child(chunk)
	chunks[index] = chunk

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + index * 7919
	var hp_scale := GameManager.multiplier("hp") * (1.0 + index * 0.05)

	var boss_chunk := index > 0 and index % BOSS_EVERY == BOSS_EVERY - 1
	if boss_chunk:
		_spawn_boss(index, hp_scale)
		_spawn_pickup(chunk, rng, Vector2(CHUNK_WIDTH * 0.5, -120.0), "health")
		return

	# One or two formations per chunk.
	var formation_count := rng.randi_range(1, 2)
	for f in formation_count:
		var valid: Array = []
		for pattern in PATTERNS:
			if index >= int(pattern["min_chunk"]):
				valid.append(pattern)
		if valid.is_empty():
			continue
		var pattern: Dictionary = valid[rng.randi_range(0, valid.size() - 1)]
		_spawn_formation(chunk, rng, pattern, hp_scale, f)

	# Pickups: one guaranteed, then a couple of chances.
	_spawn_pickup(chunk, rng, _random_point(rng, 0.3), _pick_pickup(rng))
	for i in rng.randi_range(1, 3):
		_spawn_pickup(chunk, rng, _random_point(rng, 0.7), _pick_pickup(rng))


func _spawn_formation(chunk: Node2D, rng: RandomNumberGenerator, pattern: Dictionary, hp_scale: float, slot: int) -> void:
	var count := rng.randi_range(int(pattern["count"][0]), int(pattern["count"][1]))
	var base_x := 900.0 + slot * 700.0 + rng.randf_range(-100.0, 100.0)
	var base_y := rng.randf_range(-220.0, 220.0)
	var hp: float = float(pattern["hp"]) * hp_scale
	var behaviour := String(pattern["behaviour"])
	var elite: bool = bool(pattern.get("elite", false))
	for i in count:
		var offset := Vector2.ZERO
		match String(pattern["formation"]):
			"line":
				offset = Vector2(i * 110.0, 0.0)
			"vee":
				var spread := (i - (count - 1) / 2.0) * 90.0
				offset = Vector2(absf(spread) * 0.6, spread)
			"grid":
				offset = Vector2((i % 3) * 130.0, (i / 3) * 110.0 - 110.0)
			"ring":
				var angle := TAU * float(i) / float(count)
				offset = Vector2(cos(angle), sin(angle)) * 260.0
		var drone := ObjectPool.acquire("drone")
		if drone == null:
			return
		drone.global_position = chunk.global_position + Vector2(base_x + offset.x, base_y + offset.y)
		if drone.has_method("activate"):
			drone.call("activate", hp, behaviour, elite)


func _spawn_boss(index: int, hp_scale: float) -> void:
	var boss_number := int(index / BOSS_EVERY)
	var boss := CoreBoss.new()
	world.add_child(boss)
	boss.global_position = Vector2(index * CHUNK_WIDTH + 1500.0, 0.0)
	boss.activate(boss_number, hp_scale)
	bosses_spawned[index] = boss


func _spawn_pickup(chunk: Node2D, rng: RandomNumberGenerator, at: Vector2, kind: String) -> void:
	var pickup := ObjectPool.acquire("powerup")
	if pickup == null:
		return
	pickup.global_position = chunk.global_position + at
	if pickup.has_method("activate"):
		pickup.call("activate", kind)


func _random_point(rng: RandomNumberGenerator, min_ratio: float) -> Vector2:
	return Vector2(rng.randf_range(CHUNK_WIDTH * min_ratio, CHUNK_WIDTH * 0.95), rng.randf_range(-300.0, 300.0))


func _pick_pickup(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.30:
		return "currency"
	if roll < 0.55:
		return "health"
	if roll < 0.75:
		return "weapon"
	if roll < 0.90:
		return "shield"
	return "mod"


func furthest_chunk() -> int:
	return current_chunk

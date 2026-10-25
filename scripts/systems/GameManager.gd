extends Node
## Run state, difficulty and scoring.
##
## Deliberately knows nothing about nodes in the scene: everything it wants to
## show goes out through EventBus, which the HUD subscribes to.

const DIFFICULTIES := [
	{"name": "Easy", "hp": 0.8, "damage": 0.6, "score": 0.8},
	{"name": "Normal", "hp": 1.0, "damage": 1.0, "score": 1.0},
	{"name": "Hard", "hp": 1.3, "damage": 1.4, "score": 1.3},
	{"name": "Nightmare", "hp": 1.8, "damage": 2.0, "score": 1.6},
]

var difficulty: int = 1
var run_data: Dictionary = {}
var running: bool = false


func difficulty_name() -> String:
	return String(DIFFICULTIES[difficulty]["name"])


func multiplier(key: String) -> float:
	return float(DIFFICULTIES[difficulty][key])


func start_new_run(diff_index: int) -> Dictionary:
	difficulty = clampi(diff_index, 0, DIFFICULTIES.size() - 1)
	run_data = {
		"seed": randi(),
		"score": 0,
		"combo": 0,
		"max_combo": 0,
		"kills": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"damage_taken": 0,
		"currency": 0,
		"wave": 1,
		"chunks": 0,
		"bosses_killed": 0,
		"difficulty": difficulty_name(),
		"started_at": int(Time.get_unix_time_from_system()),
	}
	running = true
	WeaponSystem.reset()
	EventBus.game_started.emit(difficulty)
	EventBus.score_changed.emit(0, 0)
	EventBus.currency_changed.emit(0)
	return run_data


func seed_value() -> int:
	return int(run_data.get("seed", 0))


func add_score(base: int) -> void:
	if not running:
		return
	run_data["combo"] = int(run_data["combo"]) + 1
	run_data["max_combo"] = maxi(int(run_data["max_combo"]), int(run_data["combo"]))
	var combo_mult: float = 1.0 + minf(float(run_data["combo"]) * 0.1, 3.0)
	var gained := int(round(float(base) * combo_mult * multiplier("score")))
	run_data["score"] = int(run_data["score"]) + gained
	EventBus.score_changed.emit(int(run_data["score"]), int(run_data["combo"]))


func register_kill() -> void:
	if not running:
		return
	run_data["kills"] = int(run_data["kills"]) + 1


func add_currency(amount: int) -> void:
	run_data["currency"] = int(run_data.get("currency", 0)) + amount
	EventBus.currency_changed.emit(int(run_data["currency"]))


func add_damage_taken(amount: int) -> void:
	run_data["damage_taken"] = int(run_data.get("damage_taken", 0)) + amount
	# Taking a hit breaks the combo, but the run keeps going.
	run_data["combo"] = 0
	EventBus.score_changed.emit(int(run_data["score"]), 0)


func count_shot() -> void:
	run_data["shots_fired"] = int(run_data.get("shots_fired", 0)) + 1


func count_hit() -> void:
	run_data["shots_hit"] = int(run_data.get("shots_hit", 0)) + 1


func set_wave(wave: int) -> void:
	run_data["wave"] = maxi(int(run_data.get("wave", 1)), wave)


func end_run(victory: bool = false) -> void:
	if not running:
		return
	running = false
	var meta := SaveSystem.update_meta(run_data, victory)
	SaveSystem.save_run(run_data, meta)
	EventBus.game_over.emit(int(run_data["score"]), int(run_data["wave"]), run_data)


func accuracy() -> float:
	var fired := int(run_data.get("shots_fired", 0))
	if fired <= 0:
		return 0.0
	return float(run_data.get("shots_hit", 0)) / float(fired)

extends Node
## Local persistence: run/meta save, settings, replays.
##
## Everything lives under user:// and is plain JSON (the save file is lightly
## obfuscated with a repeating XOR so casual editing is not rewarded, which is
## all the spec asked for -- it is explicitly not cryptographic).

const SAVE_PATH := "user://save_game.save"
const SETTINGS_PATH := "user://settings.cfg"
const REPLAY_DIR := "user://replays/"
const SAVE_VERSION := 2
const _KEY := "NEON_VELOCITY_LOCAL_ONLY"

var meta: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	meta = _load_meta()


# --- Settings -----------------------------------------------------------

func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for section in settings:
		var group: Dictionary = settings[section]
		for key in group:
			cfg.set_value(section, key, group[key])
	cfg.save(SETTINGS_PATH)


func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {}
	if cfg.load(SETTINGS_PATH) != OK:
		return out
	for section in cfg.get_sections():
		out[section] = {}
		for key in cfg.get_section_keys(section):
			out[section][key] = cfg.get_value(section, key)
	return out


func get_setting(section: String, key: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return fallback
	return cfg.get_value(section, key, fallback)


# --- Run / meta save ----------------------------------------------------

func save_run(run_data: Dictionary, meta_stats: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"run": run_data,
		"meta": meta_stats,
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing.")
		return false
	file.store_string(_obfuscate(JSON.stringify(payload)))
	file.close()
	return true


func load_run() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(_deobfuscate(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --- Replays ------------------------------------------------------------

func save_replay(replay: Dictionary) -> String:
	var stamp := int(Time.get_unix_time_from_system())
	var filename := "replay_%s_%d.json" % [str(replay.get("seed", 0)), stamp]
	var path := REPLAY_DIR.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(replay))
	file.close()
	return path


func load_replay(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func list_replays() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(REPLAY_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			out.append(REPLAY_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	out.reverse()
	return out


# --- Meta stats ---------------------------------------------------------

func _load_meta() -> Dictionary:
	var data := load_run()
	if data.has("meta") and typeof(data["meta"]) == TYPE_DICTIONARY:
		return data["meta"]
	return {
		"total_runs": 0,
		"total_kills": 0,
		"total_score": 0,
		"best_score": 0,
		"best_wave": 1,
		"wins": 0,
	}


func update_meta(run: Dictionary, victory: bool) -> Dictionary:
	meta["total_runs"] = int(meta.get("total_runs", 0)) + 1
	meta["total_kills"] = int(meta.get("total_kills", 0)) + int(run.get("kills", 0))
	meta["total_score"] = int(meta.get("total_score", 0)) + int(run.get("score", 0))
	meta["best_score"] = maxi(int(meta.get("best_score", 0)), int(run.get("score", 0)))
	meta["best_wave"] = maxi(int(meta.get("best_wave", 1)), int(run.get("wave", 1)))
	if victory:
		meta["wins"] = int(meta.get("wins", 0)) + 1
	return meta


# --- Obfuscation --------------------------------------------------------

func _obfuscate(text: String) -> String:
	var key := _KEY.to_utf8_buffer()
	var data := text.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(data.size())
	for i in data.size():
		out[i] = data[i] ^ key[i % key.size()]
	return Marshalls.raw_to_base64(out)


func _deobfuscate(text: String) -> String:
	var key := _KEY.to_utf8_buffer()
	var data := Marshalls.base64_to_raw(text.strip_edges())
	if data.is_empty():
		return ""
	var out := PackedByteArray()
	out.resize(data.size())
	for i in data.size():
		out[i] = data[i] ^ key[i % key.size()]
	return out.get_string_from_utf8()

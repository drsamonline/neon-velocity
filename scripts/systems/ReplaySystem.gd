extends Node
## Input recording.
##
## Every physics frame during a run is appended to a compact frame list and
## written to user://replays as JSON when the run ends. Playback is not wired
## into the game yet: the files are complete enough to re-simulate a run, and
## the format is documented in README.

const MAX_FRAMES := 60 * 60 * 20  # 20 minutes of input at 60 Hz

var recording: bool = false
var frames: PackedByteArray = PackedByteArray()
var seed: int = 0
var difficulty: int = 1
var weapon: String = "plasma"


func start_recording(run_seed: int, diff: int, start_weapon: String) -> void:
	seed = run_seed
	difficulty = diff
	weapon = start_weapon
	frames = PackedByteArray()
	recording = true


## dir: -1/0/1 on each axis, fire/dash as bits. Three bytes per frame.
func record_frame(dir: Vector2, firing: bool, dashing: bool) -> void:
	if not recording or frames.size() >= MAX_FRAMES * 3:
		return
	frames.append(int(clampi(roundi(dir.x), -1, 1)) + 1)
	frames.append(int(clampi(roundi(dir.y), -1, 1)) + 1)
	var flags := 0
	if firing:
		flags |= 1
	if dashing:
		flags |= 2
	frames.append(flags)


func stop_recording(final_score: int, wave: int) -> String:
	if not recording:
		return ""
	recording = false
	var payload := {
		"version": 1,
		"seed": seed,
		"difficulty": difficulty,
		"start_weapon": weapon,
		"frame_count": frames.size() / 3,
		"final_score": final_score,
		"final_wave": wave,
		"timestamp": int(Time.get_unix_time_from_system()),
		"input_base64": Marshalls.raw_to_base64(frames),
	}
	var path := SaveSystem.save_replay(payload)
	EventBus.chunk_completed.emit(-1, final_score)
	return path


func frame_count() -> int:
	return frames.size() / 3


func decode_frame(index: int) -> Dictionary:
	var offset := index * 3
	if offset + 2 >= frames.size():
		return {}
	return {
		"dir": Vector2(frames[offset] - 1, frames[offset + 1] - 1),
		"fire": (frames[offset + 2] & 1) != 0,
		"dash": (frames[offset + 2] & 2) != 0,
	}

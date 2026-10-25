extends Node
## Touch input state, shared between the on-screen controls and the ship.
##
## The controls layer writes here; Player reads it alongside the keyboard, so the
## same build is playable with keys, with a gamepad-less touchscreen, or with a
## mouse. Nothing else in the game needs to know which one is in use.

var enabled: bool = false
var move: Vector2 = Vector2.ZERO
var firing: bool = false

var _dash_queued: bool = false
var _weapon_step: int = 0
var _pause_queued: bool = false


func _ready() -> void:
	# A touchscreen, or a platform where touch is the only option.
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func enable() -> void:
	enabled = true


func request_dash() -> void:
	_dash_queued = true


func request_weapon_step(step: int) -> void:
	_weapon_step = step


func request_pause() -> void:
	_pause_queued = true


func consume_dash() -> bool:
	var queued := _dash_queued
	_dash_queued = false
	return queued


func consume_weapon_step() -> int:
	var step := _weapon_step
	_weapon_step = 0
	return step


func consume_pause() -> bool:
	var queued := _pause_queued
	_pause_queued = false
	return queued


func reset() -> void:
	move = Vector2.ZERO
	firing = false
	_dash_queued = false
	_weapon_step = 0
	_pause_queued = false

extends Node
## Weapons, upgrades and mods.
##
## A weapon is a base dictionary; the current level multiplies its stats and any
## acquired mods are applied on top. Everything is additive to `stats`, so the
## rest of the game only ever asks for `get_stats()`.

const WEAPONS := {
	"plasma": {
		"name": "Plasma Cannon",
		"blurb": "Balanced rapid fire",
		"damage": 12.0, "fire_rate": 0.12, "speed": 900.0,
		"pierce": 0, "spread": 0.0, "count": 1,
		"color": Color(0.2, 0.8, 1.0), "kind": "projectile",
	},
	"spread": {
		"name": "Spread Shot",
		"blurb": "Wide cone, low damage per pellet",
		"damage": 6.0, "fire_rate": 0.25, "speed": 820.0,
		"pierce": 0, "spread": 0.5, "count": 5,
		"color": Color(0.3, 1.0, 0.5), "kind": "projectile",
	},
	"laser": {
		"name": "Laser Lance",
		"blurb": "Fast piercing beam",
		"damage": 9.0, "fire_rate": 0.05, "speed": 2400.0,
		"pierce": 999, "spread": 0.0, "count": 1,
		"color": Color(1.0, 0.35, 0.35), "kind": "projectile",
	},
	"missile": {
		"name": "Seeker Missiles",
		"blurb": "Homing, explodes on impact",
		"damage": 35.0, "fire_rate": 0.8, "speed": 430.0,
		"pierce": 0, "spread": 0.0, "count": 1, "homing": 3.2,
		"color": Color(1.0, 0.6, 0.1), "kind": "projectile",
	},
	"railgun": {
		"name": "Railgun",
		"blurb": "Charge shot, punches through everything",
		"damage": 200.0, "fire_rate": 1.2, "speed": 3000.0,
		"pierce": 999, "spread": 0.0, "count": 1, "charge_time": 1.2,
		"color": Color(0.8, 0.3, 1.0), "kind": "railgun",
	},
	"nova": {
		"name": "Nova Burst",
		"blurb": "Radial blast around the ship",
		"damage": 80.0, "fire_rate": 1.5, "speed": 0.0,
		"pierce": 999, "spread": 0.0, "count": 1, "radius": 150.0,
		"color": Color(1.0, 1.0, 0.3), "kind": "nova",
	},
}

const WEAPON_ORDER := ["plasma", "spread", "laser", "missile", "railgun", "nova"]

## Every mod is a plain stat multiplier plus an optional named effect that the
## bullet/player code knows how to honour.
const MODS := {
	"overclock": {"name": "Overclock", "blurb": "+25% fire rate, -10% damage", "stats": {"fire_rate": 0.8, "damage": 0.9}},
	"heavy_rounds": {"name": "Heavy Rounds", "blurb": "+30% damage, -20% fire rate", "stats": {"damage": 1.3, "fire_rate": 1.25}},
	"extended_mag": {"name": "Extended Mag", "blurb": "+1 projectile, +1 pierce", "stats": {"count_add": 1, "pierce_add": 1}},
	"plasma_chain": {"name": "Chain Lightning", "blurb": "Hits arc to 2 nearby enemies", "weapon": "plasma", "effects": ["chain"]},
	"plasma_overheat": {"name": "Overheat", "blurb": "+5% damage per consecutive hit, up to +50%", "weapon": "plasma", "effects": ["ramp"]},
	"plasma_crit": {"name": "Ionised Tip", "blurb": "15% chance of triple damage", "weapon": "plasma", "stats": {"crit_chance_add": 0.15, "crit_mult_add": 2.0}},
	"spread_wide": {"name": "Wide Angle", "blurb": "+40% spread, +1 projectile", "weapon": "spread", "stats": {"spread": 1.4, "count_add": 1}},
	"spread_concentrate": {"name": "Concentrated Burst", "blurb": "-30% spread, +25% damage", "weapon": "spread", "stats": {"spread": 0.7, "damage": 1.25}},
	"spread_ricochet": {"name": "Ricochet", "blurb": "Projectiles bounce off screen edges", "weapon": "spread", "effects": ["bounce"]},
	"laser_sweep": {"name": "Auto-Sweep", "blurb": "Beam curves towards the nearest enemy", "weapon": "laser", "stats": {"homing_add": 1.8}},
	"laser_focus": {"name": "Focused Lens", "blurb": "+50% damage", "weapon": "laser", "stats": {"damage": 1.5}},
	"laser_siphon": {"name": "Life Siphon", "blurb": "Heals 1 HP per 50 damage dealt", "weapon": "laser", "effects": ["lifesteal"]},
	"missile_mirv": {"name": "MIRV Warhead", "blurb": "Impacts split into 3 mini missiles", "weapon": "missile", "effects": ["split"]},
	"missile_swarm": {"name": "Swarm Launcher", "blurb": "Two missiles per shot, -15% damage", "weapon": "missile", "stats": {"count_add": 1, "damage": 0.85}},
	"missile_emp": {"name": "EMP Warhead", "blurb": "Hits slow enemies for 1.5s", "weapon": "missile", "effects": ["emp"]},
	"rail_penetrator": {"name": "Uranium Slug", "blurb": "+100% damage, +5 pierce", "weapon": "railgun", "stats": {"damage": 2.0, "pierce_add": 5}},
	"rail_quickcharge": {"name": "Capacitor Bank", "blurb": "-40% charge time", "weapon": "railgun", "stats": {"charge_time": 0.6}},
	"nova_pulse": {"name": "Pulsar", "blurb": "Nova fires three pulses", "weapon": "nova", "effects": ["multi_pulse"]},
	"nova_gravity": {"name": "Gravity Well", "blurb": "+35% blast radius", "weapon": "nova", "stats": {"radius": 1.35}},
}

const MAX_LEVEL := 5
const XP_PER_LEVEL := 120

var current_weapon: String = "plasma"
var level: int = 1
var xp: int = 0
var mods: Array[String] = []


func reset() -> void:
	current_weapon = "plasma"
	level = 1
	xp = 0
	mods.clear()
	EventBus.weapon_changed.emit(current_weapon, level)
	EventBus.weapon_exp_changed.emit(xp, XP_PER_LEVEL)


func select_weapon(weapon_id: String) -> void:
	if not WEAPONS.has(weapon_id):
		return
	current_weapon = weapon_id
	level = 1
	xp = 0
	EventBus.weapon_changed.emit(current_weapon, level)
	EventBus.weapon_exp_changed.emit(xp, XP_PER_LEVEL)


func cycle_weapon(step: int) -> void:
	var idx := WEAPON_ORDER.find(current_weapon)
	if idx == -1:
		idx = 0
	idx = wrapi(idx + step, 0, WEAPON_ORDER.size())
	select_weapon(WEAPON_ORDER[idx])


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		xp = 0
		EventBus.weapon_exp_changed.emit(xp, XP_PER_LEVEL)
		return
	xp += amount
	while xp >= XP_PER_LEVEL and level < MAX_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		AudioManager.play_sfx("level_up")
		EventBus.weapon_changed.emit(current_weapon, level)
	EventBus.weapon_exp_changed.emit(xp, XP_PER_LEVEL)


func has_mod(mod_id: String) -> bool:
	return mods.has(mod_id)


func apply_mod(mod_id: String) -> void:
	if not MODS.has(mod_id) or mods.has(mod_id):
		return
	mods.append(mod_id)
	AudioManager.play_sfx("pickup_mod")
	EventBus.mod_acquired.emit(mod_id)


func has_effect(effect: String) -> bool:
	for mod_id in mods:
		var mod: Dictionary = MODS[mod_id]
		if mod.has("effects") and (mod["effects"] as Array).has(effect):
			return true
	return false


## Three mods that make sense for the current weapon, never repeats.
func roll_mod_choices(count: int = 3) -> Array[String]:
	var pool: Array[String] = []
	for mod_id in MODS:
		if mods.has(mod_id):
			continue
		var mod: Dictionary = MODS[mod_id]
		if mod.has("weapon") and mod["weapon"] != current_weapon:
			continue
		pool.append(mod_id)
	pool.shuffle()
	var out: Array[String] = []
	for i in mini(count, pool.size()):
		out.append(pool[i])
	return out


func get_stats() -> Dictionary:
	var stats: Dictionary = (WEAPONS[current_weapon] as Dictionary).duplicate(true)
	stats["id"] = current_weapon
	# Level scaling: +18% damage and -6% cooldown per level past the first.
	var level_steps := level - 1
	stats["damage"] = float(stats["damage"]) * pow(1.18, level_steps)
	stats["fire_rate"] = float(stats["fire_rate"]) * pow(0.94, level_steps)
	stats["crit_chance"] = 0.0
	stats["crit_mult"] = 2.0
	stats["homing"] = float(stats.get("homing", 0.0))
	stats["effects"] = []
	for mod_id in mods:
		var mod: Dictionary = MODS[mod_id]
		if mod.has("weapon") and mod["weapon"] != current_weapon:
			continue
		var stat_mods: Dictionary = mod.get("stats", {})
		for key in stat_mods:
			var value: float = float(stat_mods[key])
			match key:
				"damage", "speed", "fire_rate", "spread", "charge_time", "radius":
					stats[key] = float(stats.get(key, 1.0)) * value
				"count_add":
					stats["count"] = int(stats.get("count", 1)) + int(value)
				"pierce_add":
					stats["pierce"] = int(stats.get("pierce", 0)) + int(value)
				"crit_chance_add":
					stats["crit_chance"] = float(stats["crit_chance"]) + value
				"crit_mult_add":
					stats["crit_mult"] = float(stats["crit_mult"]) + value
				"homing_add":
					stats["homing"] = float(stats["homing"]) + value
		for effect in mod.get("effects", []):
			(stats["effects"] as Array).append(effect)
	stats["damage"] = int(round(float(stats["damage"])))
	stats["count"] = maxi(1, int(stats["count"]))
	stats["pierce"] = int(stats["pierce"])
	return stats

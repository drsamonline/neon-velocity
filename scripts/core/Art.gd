extends Node
## Procedural pixel art.
##
## Every sprite in the game is rasterised here at startup with the Image API and
## wrapped in an ImageTexture. No PNG files are shipped, which is why the whole
## repository is text-only.
##
## Generation is deterministic: a fixed RNG seed per sprite means the starfield
## and the ship greebles look the same on every launch.

const PALETTE: Array[Color] = [
	Color8(0x00, 0x00, 0x00),  # 0 black
	Color8(0x1A, 0x1C, 0x2C),  # 1 dark blue
	Color8(0x5D, 0x27, 0x5D),  # 2 dark purple
	Color8(0xB1, 0x3E, 0x53),  # 3 dark red
	Color8(0xEF, 0x7D, 0x57),  # 4 orange
	Color8(0xFF, 0xCD, 0x75),  # 5 light yellow
	Color8(0xA7, 0xF0, 0x70),  # 6 light green
	Color8(0x38, 0xB7, 0x64),  # 7 green
	Color8(0x25, 0x71, 0x79),  # 8 teal
	Color8(0x29, 0xAD, 0xFF),  # 9 light blue
	Color8(0x83, 0x76, 0x9C),  # 10 lavender
	Color8(0xFF, 0x77, 0xA8),  # 11 pink
	Color8(0xFF, 0xCC, 0xAA),  # 12 peach
	Color8(0xFF, 0xEC, 0x27),  # 13 yellow
	Color8(0x00, 0xE4, 0x36),  # 14 bright green
	Color8(0xFF, 0xFF, 0xFF),  # 15 white
]

const BLACK := 0
const DARK_BLUE := 1
const DARK_PURPLE := 2
const DARK_RED := 3
const ORANGE := 4
const LIGHT_YELLOW := 5
const LIGHT_GREEN := 6
const GREEN := 7
const TEAL := 8
const LIGHT_BLUE := 9
const LAVENDER := 10
const PINK := 11
const PEACH := 12
const YELLOW := 13
const BRIGHT_GREEN := 14
const WHITE := 15

var _cache: Dictionary = {}


func _ready() -> void:
	# Textures are generated lazily on first request; warm the common ones so
	# the first frame of gameplay never stalls on rasterisation.
	for name in ["player_ship", "drone", "elite_drone", "bullet_player", "bullet_enemy", "missile", "spark"]:
		texture(name)


func texture(sprite_name: String) -> Texture2D:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var img: Image = _build(sprite_name)
	if img == null:
		img = _build("spark")
	var tex := ImageTexture.create_from_image(img)
	_cache[sprite_name] = tex
	return tex


func palette_color(index: int) -> Color:
	return PALETTE[clampi(index, 0, PALETTE.size() - 1)]


func _build(sprite_name: String) -> Image:
	match sprite_name:
		"player_ship":
			return _player_ship()
		"drone":
			return _drone(false)
		"elite_drone":
			return _drone(true)
		"boss_core":
			return _boss_core()
		"bullet_player":
			return _bolt(Vector2i(16, 7), LIGHT_BLUE, WHITE)
		"bullet_enemy":
			return _bolt(Vector2i(9, 9), ORANGE, DARK_RED)
		"missile":
			return _missile()
		"spark":
			return _spark()
		"pickup_health":
			return _pickup_health()
		"pickup_currency":
			return _pickup_currency()
		"pickup_shield":
			return _pickup_shield()
		"pickup_weapon":
			return _pickup_weapon()
		"pickup_mod":
			return _pickup_mod()
		"starfield":
			return _starfield()
		"nebula":
			return _nebula()
		"mountains":
			return _mountains()
		"shockwave":
			return _ring(64)
		_:
			push_warning("Unknown sprite '%s'" % sprite_name)
			return _spark()


# --- Image helpers ------------------------------------------------------

func _new_image(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


func _fill(img: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(maxi(0, y0), mini(img.get_height(), y1)):
		for x in range(maxi(0, x0), mini(img.get_width(), x1)):
			img.set_pixel(x, y, color)


func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 := radius * radius
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			var d := Vector2(x + 0.5, y + 0.5) - center
			if d.length_squared() <= r2:
				_put(img, x, y, color)


func _ring_pixels(img: Image, center: Vector2, inner: float, outer: float, color: Color) -> void:
	for y in range(int(center.y - outer), int(center.y + outer) + 1):
		for x in range(int(center.x - outer), int(center.x + outer) + 1):
			var d := (Vector2(x + 0.5, y + 0.5) - center).length()
			if d >= inner and d <= outer:
				_put(img, x, y, color)


func _triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(floor(minf(a.x, minf(b.x, c.x))))
	var max_x := int(ceil(maxf(a.x, maxf(b.x, c.x))))
	var min_y := int(floor(minf(a.y, minf(b.y, c.y))))
	var max_y := int(ceil(maxf(a.y, maxf(b.y, c.y))))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := _sign(p, a, b)
			var d2 := _sign(p, b, c)
			var d3 := _sign(p, c, a)
			var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (has_neg and has_pos):
				_put(img, x, y, color)


func _sign(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)


# --- Sprites ------------------------------------------------------------

func _player_ship() -> Image:
	# A clean dart rather than a pile of greebles: at 3x on screen, detail turns
	# into noise, so the silhouette does the work.
	var img := _new_image(Vector2i(40, 20))
	# Main hull.
	_triangle(img, Vector2(2, 10), Vector2(34, 4), Vector2(34, 16), PALETTE[LIGHT_BLUE])
	# Bright core running down the middle.
	_triangle(img, Vector2(8, 10), Vector2(33, 7), Vector2(33, 13), PALETTE[WHITE])
	# Wings, swept back.
	_triangle(img, Vector2(12, 6), Vector2(26, 1), Vector2(28, 7), PALETTE[LAVENDER])
	_triangle(img, Vector2(12, 14), Vector2(26, 19), Vector2(28, 13), PALETTE[LAVENDER])
	# Cockpit.
	_disc(img, Vector2(24, 10), 2.4, PALETTE[YELLOW])
	_put(img, 24, 10, PALETTE[WHITE])
	# Twin engines.
	_fill(img, 0, 6, 4, 9, PALETTE[ORANGE])
	_fill(img, 0, 11, 4, 14, PALETTE[ORANGE])
	_fill(img, 0, 8, 3, 12, PALETTE[LIGHT_YELLOW])
	return img


func _drone(elite: bool) -> Image:
	var size := 30 if elite else 24
	var img := _new_image(Vector2i(size, size))
	var mid := size / 2.0
	var hull := PALETTE[DARK_PURPLE] if elite else PALETTE[DARK_RED]
	var edge := PALETTE[PINK] if elite else PALETTE[ORANGE]
	# Nose points left (towards the player).
	_triangle(img, Vector2(1, mid), Vector2(size - 3, 3), Vector2(size - 3, size - 3), hull)
	_triangle(img, Vector2(1, mid), Vector2(size - 6, 6), Vector2(size - 6, size - 6), edge)
	_disc(img, Vector2(mid + 2, mid), 3.0 if elite else 2.0, PALETTE[YELLOW])
	if elite:
		_ring_pixels(img, Vector2(mid, mid), 10.0, 12.0, PALETTE[BRIGHT_GREEN])
		_put(img, 4, 4, PALETTE[WHITE])
		_put(img, 4, size - 5, PALETTE[WHITE])
	return img


func _boss_core() -> Image:
	var size := 96
	var img := _new_image(Vector2i(size, size))
	var c := Vector2(size / 2.0, size / 2.0)
	_ring_pixels(img, c, 34.0, 44.0, PALETTE[DARK_PURPLE])
	_ring_pixels(img, c, 30.0, 34.0, PALETTE[PINK])
	_ring_pixels(img, c, 22.0, 26.0, PALETTE[LAVENDER])
	_disc(img, c, 20.0, PALETTE[DARK_RED])
	_disc(img, c, 13.0, PALETTE[ORANGE])
	_disc(img, c, 7.0, PALETTE[LIGHT_YELLOW])
	_disc(img, c, 3.0, PALETTE[WHITE])
	# Six spokes.
	for i in 6:
		var angle := TAU * float(i) / 6.0
		for step in range(24, 46):
			var p := c + Vector2(cos(angle), sin(angle)) * float(step)
			_put(img, int(p.x), int(p.y), PALETTE[LAVENDER])
	return img


func _bolt(size: Vector2i, core: int, edge: int) -> Image:
	# A streak, not a ball: projectiles read as motion when they are longer than
	# they are tall.
	var img := _new_image(size)
	var half := size.y / 2.0
	var core_half := maxf(1.0, size.y * 0.28)
	for x in size.x:
		# Taper towards both ends so the streak looks like it is travelling.
		var t := float(x) / float(maxi(1, size.x - 1))
		var taper := 1.0 - pow(absf(t - 0.35) / 0.65, 2.0)
		var h := half * clampf(taper, 0.15, 1.0)
		for y in size.y:
			var d := absf(float(y) + 0.5 - half)
			if d <= h:
				img.set_pixel(x, y, PALETTE[edge])
			if d <= h * 0.55:
				img.set_pixel(x, y, PALETTE[core])
	# Hot tip at the front.
	for y in range(int(half - core_half), int(half + core_half) + 1):
		_put(img, size.x - 1, y, PALETTE[WHITE])
	return img


func _missile() -> Image:
	var img := _new_image(Vector2i(18, 8))
	_fill(img, 4, 2, 15, 6, PALETTE[ORANGE])
	_triangle(img, Vector2(14, 1), Vector2(18, 4), Vector2(14, 7), PALETTE[LIGHT_YELLOW])
	_fill(img, 0, 3, 4, 5, PALETTE[YELLOW])
	_fill(img, 6, 0, 10, 2, PALETTE[DARK_RED])
	_fill(img, 6, 6, 10, 8, PALETTE[DARK_RED])
	return img


func _spark() -> Image:
	var img := _new_image(Vector2i(9, 9))
	var c := Vector2(4.5, 4.5)
	_disc(img, c, 4.0, PALETTE[ORANGE])
	_disc(img, c, 2.0, PALETTE[YELLOW])
	_put(img, 4, 4, PALETTE[WHITE])
	return img


func _pickup_health() -> Image:
	var img := _new_image(Vector2i(18, 18))
	_fill(img, 7, 2, 11, 16, PALETTE[BRIGHT_GREEN])
	_fill(img, 2, 7, 16, 11, PALETTE[BRIGHT_GREEN])
	_fill(img, 8, 3, 10, 15, PALETTE[WHITE])
	_fill(img, 3, 8, 15, 10, PALETTE[WHITE])
	return img


func _pickup_currency() -> Image:
	var img := _new_image(Vector2i(14, 14))
	_disc(img, Vector2(7, 7), 6.5, PALETTE[YELLOW])
	_disc(img, Vector2(7, 7), 4.5, PALETTE[LIGHT_YELLOW])
	_fill(img, 6, 4, 8, 10, PALETTE[ORANGE])
	return img


func _pickup_shield() -> Image:
	var img := _new_image(Vector2i(18, 18))
	_triangle(img, Vector2(1, 3), Vector2(17, 3), Vector2(9, 17), PALETTE[LIGHT_BLUE])
	_triangle(img, Vector2(4, 5), Vector2(14, 5), Vector2(9, 14), PALETTE[TEAL])
	_put(img, 9, 8, PALETTE[WHITE])
	return img


func _pickup_weapon() -> Image:
	var img := _new_image(Vector2i(18, 18))
	_ring_pixels(img, Vector2(9, 9), 6.0, 8.0, PALETTE[LIGHT_GREEN])
	_triangle(img, Vector2(3, 5), Vector2(12, 9), Vector2(3, 13), PALETTE[BRIGHT_GREEN])
	_fill(img, 12, 8, 16, 10, PALETTE[WHITE])
	return img


func _pickup_mod() -> Image:
	var img := _new_image(Vector2i(18, 18))
	_ring_pixels(img, Vector2(9, 9), 5.0, 7.0, PALETTE[LAVENDER])
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var p := Vector2(9, 9) + Vector2(cos(a), sin(a)) * 8.0
		_disc(img, p, 2.0, PALETTE[PINK])
	_disc(img, Vector2(9, 9), 3.0, PALETTE[WHITE])
	return img


func _starfield() -> Image:
	var img := _new_image(Vector2i(256, 256))
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 260:
		var x := rng.randi_range(0, 255)
		var y := rng.randi_range(0, 255)
		var bright := rng.randf()
		var color: Color = PALETTE[WHITE] if bright > 0.85 else PALETTE[LAVENDER]
		color.a = 0.35 + bright * 0.65
		_put(img, x, y, color)
		if bright > 0.94:
			_put(img, x + 1, y, Color(color.r, color.g, color.b, 0.4))
			_put(img, x, y + 1, Color(color.r, color.g, color.b, 0.4))
	return img


func _nebula() -> Image:
	var img := _new_image(Vector2i(256, 256))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var tints := [PALETTE[DARK_PURPLE], PALETTE[TEAL], PALETTE[DARK_BLUE], PALETTE[DARK_RED]]
	for i in 60:
		var center := Vector2(rng.randf_range(0, 256), rng.randf_range(0, 256))
		var radius := rng.randf_range(18.0, 64.0)
		var base: Color = tints[rng.randi_range(0, tints.size() - 1)]
		for y in range(int(center.y - radius), int(center.y + radius) + 1):
			for x in range(int(center.x - radius), int(center.x + radius) + 1):
				var d := (Vector2(x, y) - center).length() / radius
				if d >= 1.0:
					continue
				var alpha := (1.0 - d) * 0.10
				var existing := img.get_pixel(clampi(x, 0, 255), clampi(y, 0, 255))
				var blended := existing.lerp(Color(base.r, base.g, base.b, 1.0), alpha)
				blended.a = minf(1.0, existing.a + alpha)
				_put(img, x, y, blended)
	return img


func _mountains() -> Image:
	var img := _new_image(Vector2i(512, 160))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var heights := PackedInt32Array()
	heights.resize(512)
	var y := 90
	for x in 512:
		y += rng.randi_range(-3, 3)
		y = clampi(y, 40, 150)
		heights[x] = y
	# Ridge only: the area below stays transparent so the layer does not paint a
	# black wall over the playfield.
	for x in 512:
		var top: int = heights[x]
		for yy in range(top, mini(top + 26, 160)):
			var fade: float = 1.0 - float(yy - top) / 26.0
			img.set_pixel(x, yy, Color(0.10, 0.11, 0.20, fade * 0.9))
	return img


func _ring(size: int) -> Image:
	var img := _new_image(Vector2i(size, size))
	var c := Vector2(size / 2.0, size / 2.0)
	_ring_pixels(img, c, size * 0.40, size * 0.48, PALETTE[WHITE])
	_ring_pixels(img, c, size * 0.30, size * 0.36, Color(1, 1, 1, 0.5))
	return img

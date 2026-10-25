extends Node
## Dev utility: writes every generated sprite to res://art_preview/ as PNG so
## the procedural art can be eyeballed outside the game.
##
##   godot --headless --path . res://scenes/tools/DumpSprites.tscn

const SPRITES := [
	"player_ship", "drone", "elite_drone", "boss_core", "bullet_player",
	"bullet_enemy", "missile", "spark", "pickup_health", "pickup_currency",
	"pickup_shield", "pickup_weapon", "pickup_mod", "starfield", "nebula",
	"mountains", "shockwave",
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://art_preview")
	for sprite_name in SPRITES:
		var texture := Art.texture(sprite_name)
		var image := texture.get_image()
		# Upscale small sprites so they are legible as previews.
		if image.get_width() < 128:
			image.resize(image.get_width() * 6, image.get_height() * 6, Image.INTERPOLATE_NEAREST)
		image.save_png("res://art_preview/%s.png" % sprite_name)
		print("wrote art_preview/%s.png (%dx%d)" % [sprite_name, image.get_width(), image.get_height()])
	print("done")
	get_tree().quit(0)

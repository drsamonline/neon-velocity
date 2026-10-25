shader_type canvas_item;

// Subtle additive pulse for the ship sprite, plus a white hit flash driven from
// Player.gd via `hit_flash`.

uniform float glow_strength : hint_range(0.0, 2.0) = 0.25;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = 0.75 + 0.25 * sin(TIME * 6.0);
	vec3 tinted = tex.rgb * (1.0 + glow_strength * pulse);
	tinted = mix(tinted, vec3(1.0), hit_flash);
	COLOR = vec4(tinted, tex.a);
}

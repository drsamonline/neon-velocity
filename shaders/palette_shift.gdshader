shader_type canvas_item;

// Optional palette-cycling pass, used by nothing at the moment but kept as the
// documented hook for per-chunk colour themes.

uniform float shift_speed : hint_range(0.0, 4.0) = 0.4;
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float shift = sin(TIME * shift_speed + lum * 6.2831) * strength;
	vec3 shifted = clamp(tex.rgb + vec3(shift * 0.5, shift * 0.2, -shift * 0.4), vec3(0.0), vec3(1.0));
	COLOR = vec4(shifted, tex.a);
}

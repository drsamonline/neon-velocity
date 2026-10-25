shader_type canvas_item;
render_mode unshaded;

// Full-screen CRT pass: curvature, chromatic aberration, scanlines, vignette,
// grain and a slow flicker. The palette quantisation from the original spec was
// dropped because the art is already drawn from a 16-colour palette; quantising
// twice only muddied it.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform bool crt_enabled = true;
uniform float scanlines : hint_range(0.0, 1.0) = 0.6;
uniform float curvature : hint_range(0.0, 0.25) = 0.06;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float aberration : hint_range(0.0, 0.01) = 0.0018;
uniform float grain : hint_range(0.0, 0.15) = 0.03;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;

vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
	uv += uv * offset * offset * curvature;
	return uv * 0.5 + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = curve_uv(UV);
	vec3 col = vec3(0.0);
	bool outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;

	if (!outside) {
		if (!crt_enabled) {
			col = texture(screen_texture, UV).rgb;
		} else {
			col.r = texture(screen_texture, uv + vec2(aberration, 0.0)).r;
			col.g = texture(screen_texture, uv).g;
			col.b = texture(screen_texture, uv - vec2(aberration, 0.0)).b;

			float scan = 1.0 - scanlines * 0.45 * (0.5 + 0.5 * sin(uv.y * 1200.0));
			col *= scan;

			float vignette_mask = smoothstep(0.95, 0.25, length(uv - vec2(0.5)));
			col *= mix(1.0, vignette_mask, vignette);

			col += (hash(uv * vec2(1024.0, 768.0) + TIME) - 0.5) * grain;
			col *= 1.0 + sin(TIME * 47.0) * flicker;
		}
	}

	COLOR = vec4(col, 1.0);
}

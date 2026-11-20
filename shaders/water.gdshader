// Pixel-art water: deeper and darker away from the edges, a slow drifting swell, ripple bands,
// caustics in the shallows, glints riding the crests and a scum line at the stone. Everything is
// snapped to whole pixels and posterized with ordered dithering so it matches the pixel art.
shader_type canvas_item;

uniform vec2 rect_size = vec2(200.0, 120.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.075, 0.13, 1.0);
uniform vec4 mid_color : source_color = vec4(0.06, 0.15, 0.24, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.13, 0.27, 0.34, 1.0);
uniform vec4 glint_color : source_color = vec4(0.56, 0.71, 0.79, 1.0);
uniform vec4 scum_color : source_color = vec4(0.12, 0.2, 0.18, 1.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[idx] / 16.0;
}

void fragment() {
	vec2 px = floor(UV * rect_size);
	float t = TIME;
	float edge = min(min(px.x, px.y), min(rect_size.x - 1.0 - px.x, rect_size.y - 1.0 - px.y));
	float depth = clamp(edge / 40.0, 0.0, 1.0);

	vec2 q = px * 0.018 + vec2(t * 0.025, t * 0.017);
	float swell = fbm(q + vec2(fbm(q * 1.7 + t * 0.04), 0.0));
	// Ripples bend with the swell and lean slightly, so they never line up in rows.
	float ripple = sin((px.y + px.x * 0.18 + swell * 40.0) * 0.32 + t * 1.3) * 0.5 + 0.5;

	vec3 col = mix(shallow_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, depth));
	col = mix(col, deep_color.rgb, smoothstep(0.45, 1.0, depth));
	col += (swell - 0.5) * 0.1;
	col += (ripple - 0.5) * 0.018 * (0.4 + depth);

	// Caustics: thin bright webs in the shallows.
	float c = abs(sin(fbm(px * 0.055 + vec2(t * 0.12, -t * 0.09)) * 14.0));
	float caustic = (1.0 - smoothstep(0.0, 0.08, c)) * (1.0 - depth);
	col = mix(col, glint_color.rgb, caustic * 0.3);

	// Glints: a few bright pixels on the ripple crests, twinkling.
	float glint = step(0.992, ripple) * step(0.9, hash(floor(px / 3.0) + floor(t * 2.0))) * step(0.55, swell);
	col = mix(col, glint_color.rgb, glint * 0.7);

	// Scum and wet stone right at the edge.
	float scum = step(edge, 1.5 + vnoise(px * 0.35) * 2.5);
	col = mix(col, scum_color.rgb, scum * 0.75);

	// Posterize with ordered dithering: pixel-art colour steps.
	float steps = 8.0;
	col = floor(col * steps + bayer4(px)) / steps;
	COLOR = vec4(col, 1.0);
}

shader_type canvas_item;

uniform float torch_intensity : hint_range(0.0, 0.4) = 0.14;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.5;

// Hash para ruido
vec2 _hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Value noise
float _vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = _hash2(i).x;
	float b = _hash2(i + vec2(1.0, 0.0)).x;
	float c = _hash2(i + vec2(0.0, 1.0)).x;
	float d = _hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM — 4 octavas
float _fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * _vnoise(p);
		p  = p * 2.1 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;

	// --- Textura de piedra ---
	vec2 p = uv * vec2(3.8, 2.4);
	float n  = _fbm(p);
	float n2 = _fbm(p * 1.6 + vec2(5.3, 2.1));
	float stone = n * 0.55 + n2 * 0.45;

	vec3 stone_dark  = vec3(0.038, 0.032, 0.025);
	vec3 stone_light = vec3(0.095, 0.080, 0.060);
	vec3 col = mix(stone_dark, stone_light, stone);

	// --- Juntas de mortero (bloques de piedra) ---
	float row_off = floor(uv.y * 4.0) * 0.5;
	float mh = smoothstep(0.035, 0.0, abs(fract(uv.y * 4.0) - 0.0));
	float mv = smoothstep(0.030, 0.0, abs(fract(uv.x * 4.0 + row_off + stone * 0.08)));
	col = mix(col, stone_dark * 0.55, max(mh, mv) * 0.65);

	// --- Brillo de antorcha (centelleo cálido centrado) ---
	float flicker = 0.5 + 0.5 * sin(TIME * 1.3) * sin(TIME * 2.8) * sin(TIME * 0.71);
	float cx = length(uv - vec2(0.5, 0.42));
	float glow = (1.0 - smoothstep(0.0, 0.85, cx)) * (0.65 + 0.35 * flicker);
	vec3 torch = vec3(0.82, 0.44, 0.10);
	col += torch * torch_intensity * glow;

	// --- Viñeta ---
	float vig = length(uv - vec2(0.5)) * vignette_strength;
	col *= (1.0 - clamp(vig * vig * 0.9, 0.0, 0.88));

	COLOR = vec4(col, 1.0);
}

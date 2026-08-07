shader_type canvas_item;

uniform float strength : hint_range(0.0, 2.0) = 0.75;

void fragment() {
	float d = length(UV - vec2(0.5)) * 1.5;
	float vig = smoothstep(0.35, 1.0, d) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, vig);
}

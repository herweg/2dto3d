shader_type canvas_item;

uniform sampler2D grass_tex : source_color, repeat_enable;
uniform vec2 player_pos = vec2(0.0, 0.0);
uniform float tile_size : hint_range(64.0, 2048.0) = 600.0;

void fragment() {
	vec2 world = FRAGCOORD.xy + player_pos;
	vec2 uv    = fract(world / tile_size);
	COLOR = texture(grass_tex, uv);
}

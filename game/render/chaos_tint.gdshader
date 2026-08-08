shader_type canvas_item;

// Corrida de control del benchmark de VFX (docs/diseno-grafico.md sección 5,
// punto 4): Torreta del Caos recicla el color de las otras 19 en cada
// disparo — un solo shader de modulación de color sobre una malla, contra
// mantener 19 variantes de sprite pre-coloreadas. Rotación de matiz simple
// en YIQ, barata a propósito: lo que este benchmark mide es si "barato" es
// cierto, no busca el hue-shift más preciso posible.
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float angle = hue_shift * 6.283185307;
	float s = sin(angle);
	float cs = cos(angle);
	mat3 yiq_from_rgb = mat3(
		vec3(0.299, 0.587, 0.114),
		vec3(0.596, -0.274, -0.322),
		vec3(0.211, -0.523, 0.312)
	);
	mat3 rgb_from_yiq = mat3(
		vec3(1.0, 0.956, 0.621),
		vec3(1.0, -0.272, -0.647),
		vec3(1.0, -1.106, 1.703)
	);
	vec3 yiq = yiq_from_rgb * c.rgb;
	vec2 iq = mat2(vec2(cs, s), vec2(-s, cs)) * yiq.yz;
	vec3 rotated = rgb_from_yiq * vec3(yiq.x, iq.x, iq.y);
	COLOR = vec4(clamp(rotated, 0.0, 1.0), c.a);
}

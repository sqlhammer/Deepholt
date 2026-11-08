shader_type canvas_item;

// A fixture or ladder top in the dark (D-148): the sprite in
// greyscale at its tile's brightness, the same grey the level shader
// draws Sensed and Remembered tiles in (D-146).
uniform float brightness = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(luma * brightness), color.a);
}

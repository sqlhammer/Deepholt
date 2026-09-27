shader_type canvas_item;

uniform vec2 tiles_across = vec2(32,20);
uniform vec4 rock_colour : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;


void fragment() {
	COLOR = vec4(1.0, 0.0, 1.0, 1.0);  // magenta
	
	vec2 tile = floor(UV * tiles_across);
	
	// 0.0 or 1.0, alternating on both axes
	float check = mod(tile.x + tile.y, 2.0);
	
	COLOR = vec4(vec3(check), 1.0);
}

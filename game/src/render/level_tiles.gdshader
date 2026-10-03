shader_type canvas_item;

// Atlas cells are 16 x 16 px, laid out in a single row.
const int TILE_PIXELS = 16;

uniform vec2 tiles_across = vec2(32, 20);
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;

// Which atlas cell draws each top-layer byte, indexed by the byte
// (D-064). Filled from GDScript by LevelRenderer.
uniform int top_cells[256];

// C-3 only: every tile draws this top kind. Edit and relaunch.
const int HARD_CODED_KIND = 2;


// One texel of one atlas cell. texelFetch reads by integer texel, so
// it cannot land on a neighbouring cell -- no half-texel inset needed.
vec4 atlas_texel(int cell, ivec2 within_tile) {
	ivec2 cell_origin = ivec2(cell * TILE_PIXELS, 0);
	return texelFetch(atlas, cell_origin + within_tile, 0);
}


// QuadMesh is a 3D mesh: its UV.y runs bottom-to-top, the opposite of
// the 2D canvas. Flipped here so (0, 0) is the top-left, like the
// arrays. A symmetric checkerboard cannot show this; the atlas can.
vec2 top_down_uv(vec2 mesh_uv) {
	return vec2(mesh_uv.x, 1.0 - mesh_uv.y);
}


void fragment() {
	vec2 quad_pixels = tiles_across * float(TILE_PIXELS);
	ivec2 pixel = ivec2(floor(top_down_uv(UV) * quad_pixels));
	ivec2 within_tile = pixel % TILE_PIXELS;

	COLOR = atlas_texel(top_cells[HARD_CODED_KIND], within_tile);
}

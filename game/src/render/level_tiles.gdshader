shader_type canvas_item;

// Atlas cells are 16 x 16 px, laid out in a single row.
const int TILE_PIXELS = 16;

// One texel per tile: the byte a read of the top layer returns there
// (D-065). No source_color -- these are ids, not colours, and gamma
// conversion would silently change every one of them.
uniform sampler2D top_data : filter_nearest, repeat_disable;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;

// Which atlas cell draws each top-layer byte, indexed by the byte
// (D-064). Filled from GDScript by LevelRenderer.
uniform int top_cells[256];


// QuadMesh is a 3D mesh: its UV.y runs bottom-to-top, the opposite of
// the 2D canvas. Flipped here so (0, 0) is the top-left, like the
// arrays. A symmetric checkerboard cannot show this; the atlas can.
vec2 top_down_uv(vec2 mesh_uv) {
	return vec2(mesh_uv.x, 1.0 - mesh_uv.y);
}


// The byte stored for one tile. R8 hands it back as a float, k / 255,
// which is rarely exact -- the + 0.5 rounds rather than truncating.
int kind_at(sampler2D layer_data, ivec2 tile) {
	float stored = texelFetch(layer_data, tile, 0).r;
	return int(stored * 255.0 + 0.5);
}


// One texel of one atlas cell. texelFetch reads by integer texel, so
// it cannot land on a neighbouring cell -- no half-texel inset needed.
vec4 atlas_texel(int cell, ivec2 within_tile) {
	ivec2 cell_origin = ivec2(cell * TILE_PIXELS, 0);
	return texelFetch(atlas, cell_origin + within_tile, 0);
}


void fragment() {
	ivec2 tiles = textureSize(top_data, 0);
	ivec2 level_pixels = tiles * TILE_PIXELS;
	ivec2 pixel = ivec2(floor(top_down_uv(UV) * vec2(level_pixels)));
	pixel = clamp(pixel, ivec2(0), level_pixels - 1);

	ivec2 tile = pixel / TILE_PIXELS;
	ivec2 within_tile = pixel % TILE_PIXELS;

	COLOR = atlas_texel(top_cells[kind_at(top_data, tile)], within_tile);
}

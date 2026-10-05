// Upscales the low-resolution game viewport to the window at a non-integer
// scale (2.5x, per art-and-camera §3) without shimmer during panning.
//
// Plain nearest-neighbour at a non-integer scale maps each source texel to an
// alternating 2px/3px block on screen, and which texels land on a 2px block
// vs. a 3px block shifts as the camera moves — that shift is the shimmer.
// Plain bilinear avoids the shimmer but blurs every edge, all the time.
//
// This shader gives the best of both: it snaps to the nearest texel almost
// everywhere (flat, crisp interiors, like nearest-neighbour) but blends over
// a hair's width exactly at texel boundaries (so edges anti-alias instead of
// popping between blocks as they cross a screen pixel). This is the
// "sharp-bilinear" / anti-aliased-nearest technique.
shader_type canvas_item;

void fragment() {
	// Move into texel space, where one unit == one source pixel.
	vec2 texel_uv = UV / TEXTURE_PIXEL_SIZE;

	// The texel boundary (seam) this screen pixel is nearest to.
	vec2 seam = floor(texel_uv + 0.5);

	// How fast texel_uv changes per screen pixel, in each direction — this is
	// the width of the blend band, sized to exactly one screen pixel so the
	// blend never spreads into a texel's flat interior.
	vec2 screen_pixel_in_texels = max(fwidth(texel_uv), vec2(0.0001));

	// Distance from the seam, in screen pixels, clamped to +-0.5.
	// More than half a screen pixel away it saturates, landing on
	// a texel center (pure nearest). Within that band it slides
	// across the seam, so bilinear blends only right at the edge.
	vec2 offset = clamp((texel_uv - seam) / screen_pixel_in_texels, -0.5, 0.5);

	vec2 sample_uv = (seam + offset) * TEXTURE_PIXEL_SIZE;
	COLOR = texture(TEXTURE, sample_uv);
}

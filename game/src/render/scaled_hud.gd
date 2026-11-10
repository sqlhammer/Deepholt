class_name ScaledHud
extends CanvasLayer

# A screen layer laid out in the game's own pixels (the project's
# viewport size, 512 x 320) and scaled to the window exactly as the
# game picture is: the largest whole fit, centered, letterboxed. The
# game is drawn into a 512 x 320 SubViewport and shown scaled up, but
# the window itself is full size, so a layer anchored to the window
# would sit at the window's real pixel size, tiny and at its very
# edge (011's missing hotbar and carry bar). Children go under `root`,
# whose anchors are then the game's 512 x 320 frame.

var root: Control


func _init() -> void:
	root = Control.new()
	root.name = "Root"
	root.size = design_size()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Text sized for the design frame: 8 game pixels, scaled with it
	root.theme = Theme.new()
	root.theme.default_font_size = 8
	add_child(root)


func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()


# The game's frame: the project's viewport size.
static func design_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 512),
		ProjectSettings.get_setting("display/window/size/viewport_height", 320))


# The transform that puts the design frame inside a screen of `screen`
# pixels: scaled to fit, centered, as the game picture's keep-aspect,
# centered TextureRect does.
static func transform_for(screen: Vector2) -> Transform2D:
	var frame: Vector2 = design_size()
	var scale_by: float = minf(screen.x / frame.x, screen.y / frame.y)
	if scale_by <= 0.0: scale_by = 1.0
	var origin: Vector2 = (screen - frame * scale_by) / 2.0
	return Transform2D(0.0, Vector2(scale_by, scale_by), 0.0, origin)


func fit() -> void:
	transform = transform_for(Vector2(get_viewport().get_visible_rect().size))


# A point on the screen, in the design frame: for mouse hit tests.
func to_design(screen_point: Vector2) -> Vector2:
	return transform.affine_inverse() * screen_point

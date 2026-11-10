class_name ScaledHud
extends CanvasLayer

# A screen layer laid out in HUD pixels and scaled to the window by a
# whole number, so its pixel font and icons stay sharp (D-188). The
# game picture is the 512 x 320 game scaled to fit the window, often
# by a fraction (2.5 on the Steam Deck); the HUD covers that picture,
# at the largest whole scale that still leaves it a frame of at least
# MIN_FRAME HUD pixels: 2 on the Deck, a 640 x 400 frame. Children go
# under `root`, whose anchors are then that frame's edges: a layer
# anchored to the window would sit at the window's real pixel size,
# tiny and at its very edge (011's missing hotbar).

# The smallest frame the HUD is laid out for: everything on it fits
# in this many HUD pixels (the inventory is the tallest).
const MIN_FRAME: Vector2 = Vector2(576, 360)
# Every HUD's text: a pixel font, drawn only at a whole multiple of
# its size, anti-aliasing off on import (D-189)
const FONT: Font = preload("res://content/fonts/PressStart2P-Regular.ttf")
const FONT_SIZE: int = 8

var root: Control
# HUD pixels to screen pixels
var hud_scale: int = 1


func _init() -> void:
	root = Control.new()
	root.name = "Root"
	root.size = design_size()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = FONT
	root.theme.default_font_size = FONT_SIZE
	add_child(root)


func _ready() -> void:
	get_viewport().size_changed.connect(fit)
	fit()


# The game's frame: the project's viewport size.
static func design_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 512),
		ProjectSettings.get_setting("display/window/size/viewport_height", 320))


# Where the game picture sits on a screen of `screen` pixels: the
# game's frame scaled to fit, centered, as the game picture's
# keep-aspect, centered TextureRect shows it.
static func picture_for(screen: Vector2) -> Rect2:
	var frame: Vector2 = design_size()
	var scale_by: float = minf(screen.x / frame.x, screen.y / frame.y)
	if scale_by <= 0.0: scale_by = 1.0
	var size: Vector2 = frame * scale_by
	return Rect2((screen - size) / 2.0, size)


# The HUD's whole scale over a picture: the largest that leaves at
# least MIN_FRAME, and never under 1.
static func scale_for(picture: Vector2) -> int:
	return maxi(1, floori(minf(picture.x / MIN_FRAME.x, picture.y / MIN_FRAME.y)))


# The transform that puts the HUD's frame on the picture, at its whole
# scale, on whole screen pixels.
static func transform_for(screen: Vector2) -> Transform2D:
	var picture: Rect2 = picture_for(screen)
	var by: int = scale_for(picture.size)
	return Transform2D(0.0, Vector2(by, by), 0.0, picture.position.floor())


# The frame's size in HUD pixels, for a screen.
static func frame_for(screen: Vector2) -> Vector2:
	var picture: Rect2 = picture_for(screen)
	return (picture.size / scale_for(picture.size)).floor()


func fit() -> void:
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	transform = transform_for(screen)
	hud_scale = scale_for(picture_for(screen).size)
	root.size = frame_for(screen)


# Hidden while the inventory is open: it shows the bars, the load and
# its own messages itself, over most of the frame.
func watch_inventory(inventory: InventoryOverlay) -> void:
	inventory.open_changed.connect(func(open: bool) -> void: visible = not open)


# A point on the screen, in the frame: for mouse hit tests.
func to_design(screen_point: Vector2) -> Vector2:
	return transform.affine_inverse() * screen_point

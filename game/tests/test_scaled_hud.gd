extends GutTest

# The screen layers (D-188): laid out in HUD pixels on the game
# picture, at the largest whole scale that leaves a frame of at least
# 576 x 360, so the pixel font and icons stay sharp (012's soft text:
# scaled with the game by 2.5 on the Deck, no pixel was whole). Laid
# out against the full-size window instead, they sat tiny at its very
# bottom edge (011's missing hotbar).


func test_the_game_frame_is_the_projects_viewport_size() -> void:
	assert_eq(ScaledHud.design_size(), Vector2(512, 320), "the game's pixels")


func test_on_the_steam_deck_the_hud_is_doubled_on_a_640_by_400_frame() -> void:
	var deck: Vector2 = Vector2(1280, 800)
	assert_eq(ScaledHud.picture_for(deck), Rect2(0, 0, 1280, 800), "the game fills the Deck")
	var fit: Transform2D = ScaledHud.transform_for(deck)
	assert_eq(fit.get_scale(), Vector2(2, 2), "a whole 2, where the game is scaled by 2.5")
	assert_eq(fit.origin, Vector2.ZERO, "at the corner")
	assert_eq(ScaledHud.frame_for(deck), Vector2(640, 400), "640 x 400 HUD pixels")


func test_the_scale_is_always_whole_and_the_frame_never_under_the_minimum() -> void:
	for screen: Vector2 in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080),
			Vector2(2560, 1440), Vector2(3840, 2160), Vector2(1920, 1200)]:
		var by: float = ScaledHud.transform_for(screen).get_scale().x
		assert_eq(by, floorf(by), "%s: a whole scale" % screen)
		var frame: Vector2 = ScaledHud.frame_for(screen)
		assert_true(frame.x >= ScaledHud.MIN_FRAME.x and frame.y >= ScaledHud.MIN_FRAME.y,
			"%s: a frame of %s" % [screen, frame])


func test_the_frame_sits_on_the_game_picture_not_its_black_bars() -> void:
	# 1920 x 1080: the game picture is 1728 wide, 96 in from each side
	var wide: Vector2 = Vector2(1920, 1080)
	var fit: Transform2D = ScaledHud.transform_for(wide)
	assert_eq(fit.get_scale().x, 3.0, "3, where the game is 3.375")
	assert_eq(fit.origin, Vector2(96, 0), "at the picture's corner")
	assert_eq(ScaledHud.frame_for(wide), Vector2(576, 360), "the picture's width, over 3")


func test_a_small_window_still_gets_a_whole_scale_of_one() -> void:
	assert_eq(ScaledHud.transform_for(Vector2(600, 400)).get_scale().x, 1.0, "never under 1")


func test_a_screen_point_maps_back_into_the_frame() -> void:
	var hud: ScaledHud = add_child_autofree(ScaledHud.new())
	hud.transform = ScaledHud.transform_for(Vector2(1920, 1080))
	assert_eq(hud.to_design(Vector2(96 + 30, 60)), Vector2(10, 20), "through the scale and offset")


func test_every_hud_lays_out_in_its_frame_in_the_pixel_font() -> void:
	for hud: ScaledHud in [CarryHud.new(), HotbarHud.new(), RefusalNotice.new(),
			InventoryOverlay.new()]:
		add_child_autofree(hud)
		var screen: Vector2 = Vector2(hud.get_viewport().get_visible_rect().size)
		assert_eq(hud.root.size, ScaledHud.frame_for(screen), "%s: the frame" % hud.name)
		assert_eq(hud.root.theme.default_font, ScaledHud.FONT, "%s: the pixel font" % hud.name)
		assert_eq(hud.root.get_child_count(), 1, "%s: its content is in the frame" % hud.name)
		assert_eq(hud.get_child_count(), 1, "%s: nothing anchored to the window" % hud.name)


func test_the_font_is_imported_sharp() -> void:
	var font: FontFile = ScaledHud.FONT as FontFile
	assert_not_null(font, "a font file")
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "no anti-aliasing")
	assert_eq(font.hinting, TextServer.HINTING_NONE, "no hinting")
	assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED,
		"whole-pixel positions")
	assert_eq(ScaledHud.FONT_SIZE, 8, "the size it's drawn for")


func test_the_hotbar_sits_at_the_bottom_center_of_the_frame() -> void:
	var hud: HotbarHud = add_child_autofree(HotbarHud.new())
	await get_tree().process_frame
	var row: Rect2 = hud.root.get_child(0).get_rect()
	assert_almost_eq(row.end.y, hud.root.size.y - 6, 0.5, "6 px above the frame's bottom")
	assert_almost_eq(row.get_center().x, hud.root.size.x / 2, 0.5, "centered")
	# Eight slots: the row's middle is the gap between 4 and 5, so aim
	# at slot 4's own middle, through the layer's scaling
	var slot_4: Vector2 = row.position + Vector2(3 * 34 + 16, 16)
	assert_eq(hud.slot_at(hud.transform * slot_4), 3, "slot 4, found from a screen point")
	assert_eq(hud.slot_at(hud.transform * (row.position - Vector2(5, 5))), -1, "off the bar")

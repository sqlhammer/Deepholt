extends GutTest

# The screen layers are laid out in the game's 512 x 320 frame and
# scaled to the window as the game picture is (011's missing hotbar:
# laid out against the full-size window, they sat tiny at its very
# bottom edge, under the taskbar).


func test_the_frame_is_the_projects_viewport_size() -> void:
	assert_eq(ScaledHud.design_size(), Vector2(512, 320), "the game's pixels")


func test_it_fits_the_frame_to_the_screen_centered() -> void:
	var fit: Transform2D = ScaledHud.transform_for(Vector2(2422, 1512))
	assert_almost_eq(fit.get_scale().x, 4.725, 0.001, "scaled by height, the tighter side")
	assert_almost_eq(fit.origin, Vector2((2422 - 512 * 4.725) / 2.0, 0), Vector2(0.01, 0.01),
		"centered across")
	var tall: Transform2D = ScaledHud.transform_for(Vector2(1024, 1000))
	assert_almost_eq(tall.get_scale().x, 2.0, 0.001, "scaled by width")
	assert_almost_eq(tall.origin.y, (1000 - 640) / 2.0, 0.01, "centered down")


func test_a_screen_point_maps_back_into_the_frame() -> void:
	var hud: ScaledHud = add_child_autofree(ScaledHud.new())
	hud.transform = ScaledHud.transform_for(Vector2(1024, 640))
	assert_almost_eq(hud.to_design(Vector2(1024, 640)), Vector2(512, 320), Vector2(0.01, 0.01),
		"the screen's corner is the frame's")


func test_every_hud_lays_out_inside_the_frame() -> void:
	for hud: ScaledHud in [CarryHud.new(), HotbarHud.new(), RefusalNotice.new(),
			InventoryOverlay.new()]:
		add_child_autofree(hud)
		assert_not_null(hud.root, "%s has its frame" % hud.name)
		assert_eq(hud.root.size, Vector2(512, 320), "%s: 512 x 320" % hud.name)
		assert_eq(hud.root.get_child_count(), 1, "%s: its content is in the frame" % hud.name)
		assert_eq(hud.get_child_count(), 1, "%s: nothing anchored to the window" % hud.name)


func test_the_hotbar_sits_at_the_bottom_center_of_the_frame() -> void:
	var hud: HotbarHud = add_child_autofree(HotbarHud.new())
	await get_tree().process_frame
	var row: Rect2 = hud.root.get_child(0).get_rect()
	assert_almost_eq(row.end.y, 314.0, 0.5, "6 px above the frame's bottom")
	assert_almost_eq(row.get_center().x, 256.0, 0.5, "centered")
	# Eight slots: the row's middle is the gap between 4 and 5, so aim
	# at slot 4's own middle, through the layer's scaling
	var slot_4: Vector2 = row.position + Vector2(3 * 32 + 15, 10)
	assert_eq(hud.slot_at(hud.transform * slot_4), 3, "slot 4, found from a screen point")
	assert_eq(hud.slot_at(hud.transform * (row.position - Vector2(5, 5))), -1, "off the bar")

extends Node
## Windowed check: the border can change the window, and the root stays 640x360.


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Settings.fullscreen = false
	Settings.apply_display()
	await get_tree().process_frame
	await get_tree().process_frame
	var failed := 0
	var disabled := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED)
	print("DISPLAY resize_disabled=", disabled, " mode=", DisplayServer.window_get_mode())
	if disabled:
		push_error("display_check: window resize is still disabled")
		failed += 1
	var window := get_tree().root
	print("DISPLAY scale_mode=", window.content_scale_mode, " aspect=", window.content_scale_aspect, " stretch=", window.content_scale_stretch, " base=", window.content_scale_size)
	if window.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
		push_error("display_check: stretch mode is not viewport")
		failed += 1
	if window.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP:
		push_error("display_check: aspect is not keep")
		failed += 1
	if window.content_scale_stretch != Window.CONTENT_SCALE_STRETCH_FRACTIONAL:
		push_error("display_check: scale is not fractional")
		failed += 1
	if window.content_scale_size != Vector2i(640, 360):
		push_error("display_check: design size is %s" % window.content_scale_size)
		failed += 1
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var frame := main.get_node("WorldFrame") as SubViewportContainer
	var world := frame.get_node("World") as SubViewport
	for asked in [Vector2i(900, 520), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1680, 1050), Vector2i(2400, 900)]:
		DisplayServer.window_set_size(asked)
		await get_tree().process_frame
		await get_tree().process_frame
		var got := DisplayServer.window_get_size()
		var visible := window.get_visible_rect().size
		var screen := window.get_final_transform()
		print("DISPLAY asked=", asked, " got=", got, " visible=", visible, " world=", world.size, " frame_scale=", frame.scale, " xform=", screen)
		if visible != Vector2(640, 360):
			push_error("display_check: design rect became %s at %s" % [visible, asked])
			failed += 1
		if world.size != Vector2i(640, 360):
			push_error("display_check: world viewport became %s" % world.size)
			failed += 1
		if frame.scale.distance_to(Vector2.ONE) > 0.01:
			push_error("display_check: WorldFrame scaled itself to %s" % frame.scale)
			failed += 1
		if absi(got.x - asked.x) > 8 or absi(got.y - asked.y) > 8:
			push_error("display_check: window did not follow %s (got %s)" % [asked, got])
			failed += 1
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED):
		push_error("display_check: resize was disabled again after the size changes")
		failed += 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await get_tree().process_frame
	await get_tree().process_frame
	var full_visible := window.get_visible_rect().size
	print("DISPLAY fullscreen visible=", full_visible, " world=", world.size, " frame_scale=", frame.scale)
	if full_visible != Vector2(640, 360):
		push_error("display_check: fullscreen design rect became %s" % full_visible)
		failed += 1
	if world.size != Vector2i(640, 360):
		push_error("display_check: fullscreen world viewport became %s" % world.size)
		failed += 1
	if frame.scale.distance_to(Vector2.ONE) > 0.01:
		push_error("display_check: fullscreen WorldFrame scaled itself to %s" % frame.scale)
		failed += 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	if TouchControls._root != null:
		TouchControls._root.visible = true
		TouchControls._stick.queue_redraw()
		for pad in TouchControls._pads.values():
			(pad as Control).queue_redraw()
		await RenderingServer.frame_post_draw
		TouchControls._root.visible = false
		TouchControls._release_all()
	print("DISPLAY_CHECK_RESULT ", failed)
	get_tree().quit(1 if failed > 0 else 0)

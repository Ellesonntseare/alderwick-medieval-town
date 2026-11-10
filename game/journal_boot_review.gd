extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	var boot: Control=load("res://town_boot.gd").new();root.add_child(boot);boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(5):await process_frame
	assert(not boot.started and boot.skin_buttons.size()==22)
	for id in boot.skin_buttons:
		boot.skin_buttons[id].pressed.emit()
		assert(boot.selected_skin==id and boot.skin_buttons[id].button_pressed)
	boot.appearance_scroll.ensure_control_visible(boot.skin_buttons["saxon"])
	await process_frame
	assert(boot.appearance_scroll.scroll_vertical>0)
	boot.skin_buttons["medieval"].pressed.emit()
	boot.appearance_scroll.ensure_control_visible(boot.skin_buttons["medieval"])
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/journal-start.png")
	root.size=Vector2i(480,720)
	for frame in range(5):await process_frame
	assert(boot.spread.vertical and boot.appearance_grid.columns==3)
	boot.appearance_scroll.ensure_control_visible(boot.skin_buttons["saxon"])
	await process_frame
	assert(boot.appearance_scroll.scroll_vertical>0 and boot.cover.size.x<=root.size.x)
	print("JOURNAL_BOOT_REVIEW_COMPLETE automatic_entry=false appearances=22 selection_before_world=true narrow_scroll=true")
	quit()

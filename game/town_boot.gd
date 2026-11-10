extends Control

const Phone=preload("res://mobile_runtime.gd")

var elapsed:=0.0
var started:=false
var status: Label
var selected_skin:="medieval"
var selection_label: Label
var main_column: VBoxContainer
var preferences: VBoxContainer
var skin_buttons: Dictionary={}
var cover: PanelContainer
var spread: BoxContainer
var appearance_scroll: ScrollContainer
var appearance_grid: GridContainer

func _ready() -> void:
	get_window().title="Alderwick"
	if FileAccess.file_exists("user://player-appearance.json"):
		var saved=JSON.parse_string(FileAccess.get_file_as_string("user://player-appearance.json"))
		if saved is Dictionary:selected_skin=String(saved.get("skin","medieval"))
	var background:=ColorRect.new();background.color=Color("201b16")
	add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover=PanelContainer.new()
	cover.theme=preload("res://journal_theme.gd").create()
	add_child(cover)
	spread=BoxContainer.new()
	spread.add_theme_constant_override("separation",20)
	cover.add_child(spread)
	var left:=VBoxContainer.new()
	left.custom_minimum_size.x=230
	spread.add_child(left)
	main_column=VBoxContainer.new();main_column.add_theme_constant_override("separation",8);left.add_child(main_column)
	var title:=Label.new();title.text="Alderwick";title.add_theme_font_size_override("font_size",40);main_column.add_child(title)
	var description:=Label.new();description.text="A life of your own\nin a living medieval town.";description.add_theme_font_size_override("font_size",19);main_column.add_child(description)
	var has_session:=FileAccess.file_exists("user://town-session.json") or FileAccess.file_exists("user://town-session.json.backup")
	add_button(main_column,"Continue town" if has_session else "Enter town",start_town)
	add_button(main_column,"Settings",func():main_column.hide();preferences.show())
	add_button(main_column,"Quit",func():get_tree().quit())
	status=Label.new();status.text="Your town awaits.";status.custom_minimum_size.x=260;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",15);main_column.add_child(status)
	var right:=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",8)
	spread.add_child(right)
	selection_label=Label.new();selection_label.text="Choose your character";selection_label.add_theme_font_size_override("font_size",25);right.add_child(selection_label)
	selection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	appearance_scroll=ScrollContainer.new()
	appearance_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	appearance_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	appearance_scroll.follow_focus=true
	right.add_child(appearance_scroll)
	appearance_grid=GridContainer.new()
	appearance_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	appearance_grid.add_theme_constant_override("h_separation",8)
	appearance_grid.add_theme_constant_override("v_separation",8)
	appearance_scroll.add_child(appearance_grid)
	var skins: Array=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	for skin in skins:
		var choice:=Button.new();choice.custom_minimum_size=Vector2(116,170);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choice.toggle_mode=true;choice.tooltip_text=skin.description;appearance_grid.add_child(choice)
		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;choice.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=6;content.offset_top=6;content.offset_right=-6;content.offset_bottom=-6
		var portrait:=TextureRect.new();portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait.texture=load("res://portraits/"+skin.portrait+".png");portrait.custom_minimum_size=Vector2(104,126);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;content.add_child(portrait)
		var caption:=Label.new();caption.text=skin.name;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",12);caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(caption)
		skin_buttons[skin.id]=choice
		choice.pressed.connect(func():select_skin(skin.id,skin.name))
		if skin.id==selected_skin:select_skin(skin.id,skin.name)
	preferences=VBoxContainer.new();preferences.add_theme_constant_override("separation",16);left.add_child(preferences);preferences.hide()
	var settings_title:=Label.new();settings_title.text="Settings";settings_title.add_theme_font_size_override("font_size",28);preferences.add_child(settings_title)
	var quality:=OptionButton.new();for label in ["Performance","Balanced","High","Ultra"]:quality.add_item(label)
	var saved_quality=JSON.parse_string(FileAccess.get_file_as_string("user://graphics-settings.json")) if FileAccess.file_exists("user://graphics-settings.json") else {}
	quality.select(clampi(int(saved_quality.get("quality",0)),0,3) if saved_quality is Dictionary else 0);preferences.add_child(quality)
	quality.item_selected.connect(func(index: int):
		var file:=FileAccess.open("user://graphics-settings.json",FileAccess.WRITE);if file:file.store_string(JSON.stringify({"version":3,"quality":index})))
	add_button(preferences,"Back",func():preferences.hide();main_column.show())
	if not skin_buttons.has(selected_skin):
		select_skin("medieval","Townsperson")
	resized.connect(layout_appearances)
	layout_appearances()
	appearance_scroll.ensure_control_visible.call_deferred(skin_buttons[selected_skin])
	if "--validate-town-boot" in OS.get_cmdline_user_args():start_town.call_deferred()

func add_button(parent: Node,text: String,callback: Callable) -> void:
	var control:=Button.new();control.text=text;control.custom_minimum_size.y=48;parent.add_child(control);control.pressed.connect(callback)

func layout_appearances() -> void:
	var available:=get_viewport_rect().size
	var panel_size:=Vector2(minf(1040,available.x-32),minf(690,available.y-32))
	spread.vertical=panel_size.x<640
	var picker_width:=panel_size.x-44.0
	if not spread.vertical:
		picker_width-=250.0
	appearance_grid.columns=clampi(floori((picker_width-14.0)/124.0),1,6)
	cover.size=panel_size
	cover.position=(available-panel_size)*0.5

func select_skin(id: String,label: String) -> void:
	selected_skin=id;selection_label.text="Your character · "+label
	for key in skin_buttons:skin_buttons[key].set_pressed_no_signal(key==id)

func _process(delta: float) -> void:
	if not started:elapsed+=delta

func start_town() -> void:
	if started:return
	started=true
	var appearance:=FileAccess.open("user://player-appearance.json",FileAccess.WRITE)
	if appearance:appearance.store_string(JSON.stringify({"skin":selected_skin}))
	if "--validate-town-boot" in OS.get_cmdline_user_args():
		print("TOWN_BOOT_REVIEW_COMPLETE dialogue_disabled=true elapsed=",elapsed)
		get_tree().quit(0)
		return
	var tree := get_tree()
	tree.set_meta("alderwick_join_started", Time.get_ticks_msec())
	status.text="Opening Alderwick…"
	main_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control in main_column.get_children():
		if control is Button:control.disabled = true
	await tree.process_frame
	await tree.process_frame
	var error := tree.change_scene_to_file("res://town.tscn")
	if error != OK:
		tree.remove_meta("alderwick_join_started")
		started = false
		status.text = "Alderwick could not open. Try entering again."
		for control in main_column.get_children():
			if control is Button:control.disabled = false



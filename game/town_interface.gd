extends CanvasLayer

var town: Node3D
var ready_for_use:=false
var shade: ColorRect
var book: PanelContainer
var pages: TabContainer
var page_nodes: Dictionary={}
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var settings_tabs: TabContainer
var settings_nodes: Dictionary={}
var quick: HBoxContainer
var camera_panel: PopupPanel
var closing:=false
var switching:=false
var previous_enabled:=false
var previous_mouse:=Input.MOUSE_MODE_VISIBLE
var previous_paused:=false
var previous_view:=1
var active:=false
var opened_page:=""
var activities_list: VBoxContainer
var activity_clock:=0.0
var belongings: Label

func _ready() -> void:
	town=get_parent();name="TownInterface";layer=28;process_mode=Node.PROCESS_MODE_ALWAYS
	build();bind.call_deferred()

func button(parent: Node,text: String,callback: Callable) -> Button:
	var control:=Button.new();control.text=text;control.custom_minimum_size.y=43
	control.pressed.connect(callback);parent.add_child(control);return control

func column(parent: Node,title: String) -> VBoxContainer:
	var box:=VBoxContainer.new();box.name=title;box.add_theme_constant_override("separation",10);parent.add_child(box);return box

func heading(parent: Node,text: String,size:=24) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size);parent.add_child(label);return label

func scroll_page(parent: TabContainer,title: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
	var box:=column(scroll,"Contents");box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return box

func build() -> void:
	var theme:=preload("res://journal_theme.gd").create()
	shade=ColorRect.new();shade.color=Color(0.06,.04,.025,.6);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.hide()
	book=PanelContainer.new();book.name="MedievalJournal";book.theme=theme;add_child(book)
	var body:=column(book,"Book")
	var header:=HBoxContainer.new();body.add_child(header)
	var title:=heading(header,"The Alderwick Journal",28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(header,"Return to town  ·  Esc",close)
	pages=TabContainer.new();pages.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(pages)
	for label in ["Map","My Life","Activities","Challenges","Journal"]:
		var page:=column(pages,label);page_nodes[label]=page
	page_nodes["Belongings"]=scroll_page(pages,"Belongings")
	pages.tab_changed.connect(func(index: int):if ready_for_use and book.visible:select_page(pages.get_tab_title(index)))
	var footer:=heading(body,"ALDERWICK     •     Your places, people and everyday life",13);footer.modulate=Color("796446")
	book.hide()
	pause_panel=PanelContainer.new();pause_panel.theme=theme;add_child(pause_panel)
	var pause_body:=column(pause_panel,"Pause")
	heading(pause_body,"Alderwick",30);heading(pause_body,"A moment of rest",16)
	button(pause_body,"Return to town",close)
	button(pause_body,"Settings",open_settings)
	button(pause_body,"Design town",func():close();town.builder.toggle())
	var save_status:=heading(pause_body,"",15)
	button(pause_body,"Save game",func():
		if town.session:
			town.session.save_now();save_status.text=town.session.status_text)
	button(pause_body,"Return to title",func():
		if town.session and town.session.flush_and_save()!=OK:save_status.text=town.session.status_text;return
		close();get_tree().change_scene_to_file("res://town_boot.tscn"))
	button(pause_body,"Quit game",func():
		if town.session and town.session.flush_and_save()!=OK:save_status.text=town.session.status_text;return
		get_tree().quit())
	pause_panel.hide()
	settings_panel=PanelContainer.new();settings_panel.theme=theme;add_child(settings_panel)
	var settings_body:=column(settings_panel,"Settings")
	var settings_header:=HBoxContainer.new();settings_body.add_child(settings_header)
	var label:=heading(settings_header,"Settings",27);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button(settings_header,"Back",func():settings_panel.hide();pause_panel.show())
	settings_tabs=TabContainer.new();settings_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;settings_body.add_child(settings_tabs)
	for section in ["World","Audio & Voices","Graphics","Controls"]:settings_nodes[section]=scroll_page(settings_tabs,section)
	heading(settings_nodes["Controls"],"Keyboard & mouse",21)
	for line in ["WASD / arrows — move or pan the overhead view","Mouse — look around; right drag — rotate overhead","Shift — run; Space — jump","E — use; F — talk or join a conversation","Tab — change camera; K — open the map","J — journal; L — life; G — nearby activities","Esc — close the book or open the pause screen"]:heading(settings_nodes["Controls"],line,16)
	button(settings_nodes["Controls"],"Touch control settings",func():
		var mobile:=get_node_or_null("/root/Mobile")
		if mobile and is_instance_valid(mobile.preferences):mobile.preferences.popup_centered())
	settings_panel.hide()
	quick=HBoxContainer.new();quick.add_theme_constant_override("separation",7);add_child(quick);quick.theme=theme
	button(quick,"Journal",func():open_page("Journal")).tooltip_text="Missions, belongings and relationships [J]"
	button(quick,"View",func():camera_panel.popup()).tooltip_text="Choose your camera [Tab]"
	button(quick,"Pause",toggle_pause).tooltip_text="Settings and town design [Esc]"
	camera_panel=PopupPanel.new();camera_panel.theme=theme;add_child(camera_panel)
	get_viewport().size_changed.connect(layout);layout()

func layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	book.position=Vector2(24,30);book.size=Vector2(maxf(650,size.x-48),maxf(460,size.y-60))
	settings_panel.position=Vector2(40,45);settings_panel.size=Vector2(maxf(620,size.x-80),maxf(420,size.y-90))
	pause_panel.size=Vector2(360,0);pause_panel.position=Vector2((size.x-360)/2,maxf(30,(size.y-430)/2))
	quick.position=Vector2(size.x-310,18)
	camera_panel.position=Vector2i(int(size.x)-300,70);camera_panel.size=Vector2i(275,70)

func bind() -> void:
	while not town.life.navigation_ready or not town.character_life.bound:await get_tree().process_frame
	for frame in range(3):await get_tree().process_frame
	# Existing widgets retain their callbacks, state and save behavior. The old
	# menu is only a hidden construction registry, never a gameplay panel.
	for control in town.menu_body.get_children():
		if control==town.view_selector:continue
		var text: String=String(control.get("text")) if control.get("text")!=null else ""
		if control is OptionButton:
			text=control.get_item_text(0)
		if text.begins_with("Weather") or text=="Day/night cycle" or text.begins_with("Preview"):
			control.reparent(settings_nodes["World"])
		elif text.begins_with("Quality") or (control is Label and text.contains("FPS")):
			control.reparent(settings_nodes["Graphics"])
		elif text in ["Character voices","Hear nearby conversations"] or (control is HBoxContainer and control.find_children("*","HSlider",true,false).size()>0):
			control.reparent(settings_nodes["Audio & Voices"])
		elif text=="Needs & moods":control.reparent(page_nodes["My Life"])
		elif text=="Visit a place…":
			heading(page_nodes["Map"],"Travel to a place",16);control.reparent(page_nodes["Map"])
			control.item_selected.connect(func(index: int):if index>0:close())
	var camera_column:=VBoxContainer.new();camera_panel.add_child(camera_column)
	town.view_selector.reparent(camera_column)
	town.menu_panel.hide();town.menu_collapsed=true
	var map: Node=town.town_map
	map.process_mode=Node.PROCESS_MODE_ALWAYS
	map.root.reparent(page_nodes["Map"]);map.root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	map.root.size_flags_vertical=Control.SIZE_EXPAND_FILL;map.root.custom_minimum_size=Vector2(0,360)
	map.root.add_theme_stylebox_override("panel",preload("res://journal_theme.gd").style(Color("dfd0ab")))
	map.root.theme=book.theme
	# The existing life pages become pages inside the same book.
	var view: Node=town.character_life.view
	var life_body: Control=view.panel.get_child(0)
	life_body.reparent(page_nodes["My Life"]);life_body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	view.tabs.custom_minimum_size=Vector2(0,330);view.tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var journal_scroll: Control=town.adventures.content.get_parent()
	journal_scroll.reparent(page_nodes["Journal"]);journal_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	town.adventures.content.custom_minimum_size.x=0
	belongings=heading(page_nodes["Journal"],"",17)
	var challenge_body: Control=town.challenges.message.get_parent()
	challenge_body.reparent(page_nodes["Challenges"])
	for control in challenge_body.get_children():
		if control is Button and not control.text.begins_with("Abandon"):
			control.pressed.connect(func():if not town.challenges.active.is_empty():close())
	activities_list=column(page_nodes["Activities"],"Nearby")
	if town.inventory_ui:town.inventory_ui.build(page_nodes["Belongings"])
	town.economy.wallet_label.hide();town.economy.eat_button.hide()
	town.player_home.panel.theme=book.theme
	town.physical_gameplay.panel.theme=book.theme
	var hint_style:=StyleBoxFlat.new()
	hint_style.bg_color=Color("16231fe8");hint_style.set_corner_radius_all(6);hint_style.set_content_margin_all(7)
	town.life.hint.add_theme_stylebox_override("normal",hint_style)
	town.life.hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	town.life.hint.modulate.a=0
	var mobile:=get_node_or_null("/root/Mobile")
	if mobile and is_instance_valid(mobile.preferences):
		mobile.preferences.theme=book.theme;mobile.preferences.process_mode=Node.PROCESS_MODE_ALWAYS
	else:
		for control in settings_nodes["Controls"].get_children():
			if control is Button:control.hide()
	if town.festival:
		var dancing:=CheckBox.new();dancing.text="Village gatherings";dancing.button_pressed=town.festival.enabled;settings_nodes["World"].add_child(dancing)
		dancing.toggled.connect(town.festival.set_enabled)
		var local_music:=CheckBox.new();local_music.text="Music at the village dance";local_music.button_pressed=town.festival.music_enabled;settings_nodes["Audio & Voices"].add_child(local_music)
		local_music.toggled.connect(func(value: bool):town.festival.music_enabled=value)
	ready_for_use=true
	print("JOURNAL_INTERFACE_READY pages=",pages.get_tab_count()," old_sidebar=false appearance_before_play=true")

func start_overlay() -> void:
	if active:return
	if town.life.active:town.life.close_dialog()
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;previous_paused=get_tree().paused
	previous_view=town.view_mode
	active=true;town.player.enabled=false;town.player.velocity=Vector3.ZERO
	get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	shade.show();quick.hide();camera_panel.hide()

func open_page(page: String) -> void:
	if not ready_for_use or town.builder.active:return
	start_overlay();pause_panel.hide();settings_panel.hide();book.show()
	get_tree().paused=previous_paused
	for index in range(pages.get_tab_count()):
		if pages.get_tab_title(index)==page:pages.current_tab=index;break
	select_page(page)

func select_page(page: String) -> void:
	if switching:return
	switching=true;opened_page=page
	if town.town_map.opened and page!="Map":town.town_map.close()
	if page=="Map":town.town_map.open()
	elif page=="My Life":town.character_life.view.refresh()
	elif page=="Journal":
		town.adventures.refresh_journal()
		belongings.text="Your purse: %d coins     •     Food: %d portions"%[town.economy.player_coins,town.economy.player_food]
	elif page=="Activities":refresh_activities()
	elif page=="Belongings" and town.inventory_ui:town.inventory_ui.refresh()
	switching=false

func refresh_activities() -> void:
	for child in activities_list.get_children():activities_list.remove_child(child);child.queue_free()
	heading(activities_list,"Here & now",25)
	heading(activities_list,"Actions depend on nearby furniture and the supplies you carry.",16)
	for option in town.interior_activities.available():
		var callback: Callable=option.action
		button(activities_list,option.label,func():close();callback.call())

func toggle_pause() -> void:
	if active:close();return
	start_overlay();book.hide();settings_panel.hide();pause_panel.show()
	get_tree().paused=true

func open_settings() -> void:
	start_overlay();book.hide();pause_panel.hide();settings_panel.show()
	get_tree().paused=true

func close() -> void:
	if not active or closing:return
	closing=true
	if town.town_map.opened:town.town_map.close()
	town.character_life.cancel_activity()
	book.hide();pause_panel.hide();settings_panel.hide();shade.hide();quick.show()
	get_tree().paused=previous_paused
	town.player.enabled=previous_enabled if town.view_mode==previous_view else town.view_mode!=1
	Input.mouse_mode=previous_mouse
	active=false;opened_page="";closing=false

func _process(delta: float) -> void:
	if not ready_for_use:return
	if not active:
		quick.visible=not town.builder.active and not town.life.active and not town.character_directory.is_open()
		update_focus_prompt(delta)
	else:
		town.life.hint.hide();town.life.talk_button.hide()
	town.physical_gameplay.status.visible=not active and (town.physical_gameplay.stamina<99 or town.physical_gameplay.carried!=null or town.physical_gameplay.mounted!=null or town.physical_gameplay.pushing or town.physical_gameplay.crouching)
	if book.visible and opened_page=="My Life":
		activity_clock+=delta
		if activity_clock>.3:activity_clock=0;town.character_life.view.refresh()

func update_focus_prompt(delta: float) -> void:
	var hint: Label=town.life.hint
	if not preload("res://interaction_target.gd").gameplay_visible(town) or town.physical_gameplay.panel.visible:
		hint.hide();hint.modulate.a=0;return
	var target: Dictionary=town.life.hud_target
	if target.get("kind","none")=="none":
		hint.modulate.a=move_toward(hint.modulate.a,0,delta*8)
		if hint.modulate.a<=0:hint.hide()
		return
	var use: String="" if preload("res://mobile_runtime.gd").enabled() else "Hold E · " if target.get("hold",false) else "E · "
	var title: String=target.label
	if target.get("hold",false) and town.adventures.work_elapsed>0:title+=" · %d%%"%int(town.adventures.work_elapsed/4*100)
	var detail: String=target.get("detail","")
	var line:=use+title+("\n"+detail.left(65) if not detail.is_empty() else "")
	if hint.text!=line:hint.text=line;hint.reset_size()
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var screen:=get_viewport().get_visible_rect().size
	var camera:=get_viewport().get_camera_3d()
	var anchor:=screen/2
	if is_instance_valid(camera) and target.has("point"):anchor=camera.unproject_position(target.point)
	var top_left:=anchor+Vector2(-hint.size.x/2,30)
	hint.position=top_left.clamp(Vector2(12,48),Vector2(maxf(12,screen.x-hint.size.x-12),maxf(48,screen.y-hint.size.y-48)))
	hint.show();hint.modulate.a=move_toward(hint.modulate.a,1,delta*12)

func _input(event: InputEvent) -> void:
	if not ready_for_use or not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_ESCAPE and town.crafting and not town.crafting.job.is_empty():
		town.crafting.cancel();get_viewport().set_input_as_handled();return
	if event.physical_keycode==KEY_ESCAPE:
		if town.life.active or town.builder.active:return
		if active:close()
		else:toggle_pause()
		get_viewport().set_input_as_handled()
	elif active and event.physical_keycode in [KEY_J,KEY_K,KEY_L,KEY_G]:
		open_page({KEY_J:"Journal",KEY_K:"Map",KEY_L:"My Life",KEY_G:"Activities"}[event.physical_keycode])
		get_viewport().set_input_as_handled()

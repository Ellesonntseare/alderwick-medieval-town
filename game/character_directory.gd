extends CanvasLayer

var town: Node3D
var panel: PanelContainer
var search: LineEdit
var grid: GridContainer
var profile: RichTextLabel
var large_face: TextureRect
var selected: CharacterBody3D
var talk: Button
var count_label: Label
var entries: Array[Dictionary]=[]
var stories: Dictionary={}
var portraits: Dictionary={}
var clock := 0.0
var bound := false

func _ready() -> void:
	town=get_parent()
	layer=9
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://character_stories.json"))
	for person in data.characters:stories[person.name]=person
	build()
	var button := Button.new()
	button.text="People · browse faces"
	button.pressed.connect(open)
	town.menu_body.add_child(button)
	bind.call_deferred()

func face(name: String) -> Texture2D:
	if portraits.has(name):return portraits[name]
	var path := "res://portraits/"+name+".png"
	if not FileAccess.file_exists(path):return null
	var picture := Image.load_from_file(ProjectSettings.globalize_path(path))
	if picture.is_empty():return null
	portraits[name]=ImageTexture.create_from_image(picture)
	return portraits[name]

func bind() -> void:
	while not town.life or not town.life.navigation_ready:await get_tree().process_frame
	entries.clear()
	for person in town.life.people:
		entries.append({"person":person,"name":person.person_name,"role":person.occupation,"district":district_name(person)})
	entries.sort_custom(func(a: Dictionary,b: Dictionary):return a.name.naturalnocasecmp_to(b.name)<0)
	bound=true
	if is_open():refresh()
	print("CHARACTER_DIRECTORY_READY residents=",entries.size())

func district_name(person: Node) -> String:
	if person.get_meta("industrial_worker",false):return "Industrial town"
	return {"city":"Alderwick","west":"Western village","castle":"Castle districts","industrial":"Industrial town"}.get(String(person.get_meta("district")),"Alderwick")

func build() -> void:
	panel=PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.045,0.065,0.055,0.98)
	style.content_margin_left=24
	style.content_margin_right=24
	style.content_margin_top=20
	style.content_margin_bottom=20
	style.corner_radius_top_left=12
	style.corner_radius_top_right=12
	style.corner_radius_bottom_left=12
	style.corner_radius_bottom_right=12
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text="People of Alderwick"
	title.add_theme_font_size_override("font_size",25)
	title.modulate=Color("efd7a8")
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text="Close [Esc]"
	close.pressed.connect(hide_directory)
	header.add_child(close)
	search=LineEdit.new()
	search.placeholder_text="Search names, jobs, or places…"
	search.text_changed.connect(func(_text: String):refresh())
	column.add_child(search)
	count_label=Label.new()
	count_label.add_theme_font_size_override("font_size",14)
	column.add_child(count_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",22)
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid=GridContainer.new()
	grid.columns=3
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x=275
	body.add_child(detail)
	large_face=TextureRect.new()
	large_face.custom_minimum_size=Vector2(180,200)
	large_face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	large_face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(large_face)
	profile=RichTextLabel.new()
	profile.custom_minimum_size=Vector2(275,100)
	profile.size_flags_vertical=Control.SIZE_EXPAND_FILL
	profile.add_theme_font_size_override("normal_font_size",16)
	profile.text="Choose a face to see their name, work, and background."
	detail.add_child(profile)
	talk=Button.new()
	talk.text="Talk to this person"
	talk.disabled=true
	talk.pressed.connect(talk_selected)
	detail.add_child(talk)
	get_viewport().size_changed.connect(layout)
	layout()
	panel.hide()

func layout() -> void:
	if not panel:return
	var size := get_viewport().get_visible_rect().size
	panel.position=Vector2(24,24)
	panel.size=size-Vector2(48,48)
	grid.columns=5 if size.x>=1280 else 4 if size.x>=1100 else 3 if size.x>=930 else 2

func refresh() -> void:
	if not grid:return
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var query := search.text.strip_edges().to_lower()
	var count := 0
	for entry in entries:
		if not query.is_empty() and not (entry.name+" "+entry.role+" "+entry.district).to_lower().contains(query):continue
		var button := Button.new()
		button.custom_minimum_size=Vector2(160,240)
		button.tooltip_text=entry.name+" · "+entry.role
		button.pressed.connect(select.bind(entry.person))
		grid.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=8
		content.offset_right= -8
		content.offset_top=8
		content.offset_bottom= -8
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var image := TextureRect.new()
		image.texture=face(entry.name)
		image.custom_minimum_size=Vector2(144,150)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(image)
		for line in [[entry.name,17],[entry.role,13],[entry.district,12]]:
			var label := Label.new()
			label.text=line[0]
			label.add_theme_font_size_override("font_size",line[1])
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			content.add_child(label)
		count+=1
	count_label.text="%d of %d residents · Scroll through the faces"%[count,entries.size()] if bound else "Loading residents…"

func select(person: CharacterBody3D) -> void:
	selected=person
	large_face.texture=face(person.person_name)
	var story: Dictionary=stories.get(person.person_name,{})
	profile.text=person.person_name+"\n"+person.occupation+" · "+district_name(person)+"\n\n"+person.activity+"\n\n"+String(story.get("past",""))+"\n\nWhat matters to them\n"+String(story.get("want",""))
	profile.set_meta("activity",person.activity)
	talk.text="Talk to "+person.person_name if person.posture!="sleeping" else person.person_name+" is sleeping"
	talk.disabled=person.posture=="sleeping"

func open() -> void:
	if town.life.active:town.life.close_dialog()
	panel.show()
	layout()
	town.player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	search.grab_focus()
	refresh()

func hide_directory() -> void:
	panel.hide()
	town.player.enabled=town.view_mode!=1 and town.life.active==null
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func talk_selected() -> void:
	if not selected:return
	var person := selected
	hide_directory()
	town.life.open_dialog(person)

func is_open() -> bool:return panel!=null and panel.visible

func _process(delta: float) -> void:
	if not is_open():return
	clock+=delta
	if clock<1:return
	clock=0
	if selected and profile.get_meta("activity","")!=selected.activity:select(selected)

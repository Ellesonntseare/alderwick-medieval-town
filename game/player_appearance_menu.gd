extends CanvasLayer

var town: Node3D
var panel: PanelContainer
var search: LineEdit
var grid: GridContainer
var large_face: TextureRect
var details: RichTextLabel
var use_button: Button
var count_label: Label
var entries: Array[Dictionary]=[]
var portraits: Dictionary={}
var selected: Dictionary={}
var bound := false

func _ready() -> void:
	town=get_parent()
	layer=9
	var seen: Dictionary={}
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	for skin in catalog:
		if seen.has(skin.base) or not ResourceLoader.exists("res://characters/"+skin.id+".glb"):continue
		seen[skin.base]=true
		entries.append(skin)
	build()
	var button := Button.new()
	button.text="Player appearance · choose a face"
	button.pressed.connect(open)
	town.menu_body.add_child(button)
	bound=true
	refresh()
	print("PLAYER_APPEARANCE_MENU_READY unique_base_models=",entries.size())

func face(skin: Dictionary) -> Texture2D:
	if portraits.has(skin.id):return portraits[skin.id]
	var path := "res://portraits/"+String(skin.portrait)+".png"
	if not FileAccess.file_exists(path):return null
	var picture := Image.load_from_file(ProjectSettings.globalize_path(path))
	if picture.is_empty():return null
	portraits[skin.id]=ImageTexture.create_from_image(picture)
	return portraits[skin.id]

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
	title.text="Choose your appearance"
	title.add_theme_font_size_override("font_size",25)
	title.modulate=Color("efd7a8")
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text="Close [Esc]"
	close.pressed.connect(hide_directory)
	header.add_child(close)
	search=LineEdit.new()
	search.placeholder_text="Search player appearances…"
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
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x=275
	body.add_child(detail)
	large_face=TextureRect.new()
	large_face.custom_minimum_size=Vector2(180,220)
	large_face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	large_face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(large_face)
	details=RichTextLabel.new()
	details.custom_minimum_size=Vector2(275,100)
	details.size_flags_vertical=Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("normal_font_size",17)
	details.text="Choose a face for your player. Each distinct base model appears once."
	detail.add_child(details)
	use_button=Button.new()
	use_button.text="Use this appearance"
	use_button.disabled=true
	use_button.pressed.connect(apply_selected)
	detail.add_child(use_button)
	get_viewport().size_changed.connect(layout)
	layout()
	panel.hide()

func layout() -> void:
	var size := get_viewport().get_visible_rect().size
	panel.position=Vector2(24,24)
	panel.size=size-Vector2(48,48)
	grid.columns=5 if size.x>=1280 else 4 if size.x>=1100 else 3 if size.x>=930 else 2

func refresh() -> void:
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var query := search.text.strip_edges().to_lower()
	var count := 0
	for skin in entries:
		if not query.is_empty() and not (skin.name+" "+skin.description).to_lower().contains(query):continue
		var button := Button.new()
		button.custom_minimum_size=Vector2(160,230)
		button.tooltip_text=skin.name
		button.pressed.connect(select.bind(skin))
		grid.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=8
		content.offset_right= -8
		content.offset_top=8
		content.offset_bottom= -8
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var picture := TextureRect.new()
		picture.texture=face(skin)
		picture.custom_minimum_size=Vector2(144,175)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(picture)
		var label := Label.new()
		label.text=skin.name
		label.add_theme_font_size_override("font_size",16)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		count+=1
	count_label.text="%d appearances · One entry per base model"%count

func select(skin: Dictionary) -> void:
	selected=skin
	large_face.texture=face(skin)
	details.text=skin.name+"\nPlayer appearance\n\n"+skin.description+"\n\nWalking, running, jumping, sitting and sleeping use the player controls."
	use_button.text="Use "+skin.name
	use_button.disabled=false

func open() -> void:
	if town.life and town.life.active:town.life.close_dialog()
	panel.show()
	layout()
	town.player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	search.grab_focus()
	refresh()

func hide_directory() -> void:
	panel.hide()
	town.player.enabled=town.view_mode!=1 and (town.life==null or town.life.active==null)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func is_open() -> bool:return panel!=null and panel.visible

func apply_selected(persist := true) -> void:
	if selected.is_empty():return
	if not town.player.set_skin(selected.id,persist):return
	hide_directory()
	town.set_view(2)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

extends CanvasLayer

var town: Node
var opened:=false
var tracked:=""
var root: PanelContainer
var texture: TextureRect
var viewport: SubViewport
var camera: Camera3D
var overlay: Control
var hud: Control
var selector: OptionButton
var instruction: Label
var center:=Vector3.ZERO
var zoom:=260.0
var previous_enabled:=true
var previous_mouse:=Input.MOUSE_MODE_VISIBLE
var refresh_pending:=false
var mesh_ranges: Dictionary={}
var tracking_ids: Array[String]=[]
var clock:=0.0

func _ready() -> void:
	town=get_parent();layer=22
	root=PanelContainer.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style:=StyleBoxFlat.new();style.bg_color=Color("17251f");style.set_content_margin_all(12);root.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();root.add_child(column)
	var bar:=HBoxContainer.new();column.add_child(bar)
	for spec in [["Close",close],["You",focus_player],["Whole town",whole_town],["+",zoom_in],["−",zoom_out]]:
		var button:=Button.new();button.text=spec[0];button.custom_minimum_size=Vector2(90,48);bar.add_child(button);button.pressed.connect(spec[1])
	selector=OptionButton.new();selector.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(selector);selector.item_selected.connect(func(index: int):tracked=tracking_ids[index];refresh_objective())
	instruction=Label.new();instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;instruction.custom_minimum_size.y=45;column.add_child(instruction)
	texture=TextureRect.new();texture.size_flags_vertical=Control.SIZE_EXPAND_FILL;texture.size_flags_horizontal=Control.SIZE_EXPAND_FILL;texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;column.add_child(texture)
	texture.clip_contents=true
	viewport=SubViewport.new();viewport.world_3d=town.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.positional_shadow_atlas_size=0;add_child(viewport)
	camera=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.far=1500;camera.current=true;viewport.add_child(camera)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("24362b");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=1.0;camera.environment=environment
	texture.texture=viewport.get_texture()
	overlay=load("res://town_map_overlay.gd").new();overlay.map=self;overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;texture.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.gui_input.connect(map_input)
	texture.resized.connect(func():if opened:request_render())
	hud=load("res://town_map_overlay.gd").new();hud.map=self;hud.navigation_only=true;hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hud);hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.hide()
	var shortcut:=Button.new();shortcut.text="Detailed town map · K";town.menu_body.add_child(shortcut);shortcut.pressed.connect(open)

func objective() -> Dictionary:
	if tracked=="challenge":return town.challenges.objective()
	if tracked.is_empty() or not town.adventures.progress.has(tracked):return {}
	var state: Dictionary=town.adventures.progress[tracked]
	if state.status!="active":return {}
	var mission: Dictionary=town.adventures.find_mission(tracked)
	var step: Dictionary=mission.steps[int(state.step)]
	var point: Vector3=town.adventures.step_position(step)
	if step.has("person"):
		var people: Array=town.life.people.duplicate()
		if is_instance_valid(town.adventures.visitor):people.append(town.adventures.visitor)
		for person in people:
			if person.person_name==step.person:point=person.global_position;break
	return {"point":point,"text":String(step.get("text",mission.title))}

func refresh_objective() -> void:
	var task:=objective()
	instruction.text=task.text if not task.is_empty() else "Drag to pan · + / − to zoom · cyan is you · gold points toward your objective · N ↑"
	overlay.queue_redraw();hud.queue_redraw()

func open() -> void:
	if opened or not town.life.navigation_ready or town.life.active:return
	if town.builder.active:return
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	opened=true;root.show();tracking_ids.assign([""]);selector.clear();selector.add_item("Choose an objective")
	if not town.challenges.active.is_empty():tracking_ids.append("challenge");selector.add_item(town.challenges.DEFINITIONS[town.challenges.active].title)
	for mission in town.adventures.definitions:
		if town.adventures.progress[mission.id].status=="active":tracking_ids.append(mission.id);selector.add_item(mission.title)
	if tracked.is_empty() and tracking_ids.size()>1:tracked=tracking_ids[1]
	if tracking_ids.has(tracked):selector.select(tracking_ids.find(tracked))
	focus_player();refresh_objective()

func close() -> void:
	if not opened:return
	opened=false;root.hide();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse

func focus_player() -> void:
	center=town.home_district.porch if town.home_district.inside else town.player.global_position;center.y=0;zoom=180;request_render()
func whole_town() -> void:center=Vector3(0,0,170);zoom=900;request_render()
func zoom_in() -> void:zoom=maxf(35,zoom*.75);request_render()
func zoom_out() -> void:zoom=minf(1200,zoom/ .75);request_render()

func map_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT):
		center+=Vector3(-event.relative.x,0,-event.relative.y)*zoom/maxf(1,texture.size.y);request_render();texture.accept_event()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_in()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_out()

func request_render() -> void:
	if refresh_pending or not opened:return
	refresh_pending=true;render.call_deferred()

func render() -> void:
	await get_tree().process_frame
	if not opened:refresh_pending=false;return
	var district=town.find_child("NeighbouringIndustrialTown",true,false)
	var extent:=Vector2(zoom*texture.size.x/maxf(1,texture.size.y),zoom)
	var visible_area:=Rect2(Vector2(center.x,center.z)-extent/2,extent)
	if district and visible_area.intersects(district.bounds):
		district.set_meta("map_capture",true)
		district.update_stream(0,150)
		var deadline:=Time.get_ticks_msec()+20000
		while district.loading and opened and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame;district.update_stream(0,150)
	if not opened:
		if district:district.set_meta("map_capture",false)
		refresh_pending=false;return
	viewport.size=Vector2i(maxi(1,int(texture.size.x)),maxi(1,int(texture.size.y)))
	var rendered_center:=center
	var rendered_zoom:=zoom
	camera.size=zoom;camera.global_position=center+Vector3.UP*700;camera.look_at(center,Vector3.FORWARD)
	# Capture the real buildings and roads despite their normal distance culling.
	mesh_ranges.clear()
	for mesh: MeshInstance3D in town.find_children("*","MeshInstance3D",true,false):
		mesh_ranges[mesh]=mesh.visibility_range_end;mesh.visibility_range_end=0
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for frame in range(3):await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for mesh in mesh_ranges:
		if is_instance_valid(mesh):mesh.visibility_range_end=mesh_ranges[mesh]
	mesh_ranges.clear();refresh_pending=false;overlay.queue_redraw()
	if district:district.set_meta("map_capture",false)
	if opened and (center!=rendered_center or zoom!=rendered_zoom):request_render()

func _process(delta: float) -> void:
	clock+=delta
	if clock<.2:return
	clock=0
	if not tracked.is_empty() and objective().is_empty():tracked=""
	if tracked.is_empty():
		for mission in town.adventures.definitions:
			if town.adventures.progress[mission.id].status=="active":tracked=mission.id;break
	refresh_objective()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_K:
		if opened:close()
		else:open()
		get_viewport().set_input_as_handled()

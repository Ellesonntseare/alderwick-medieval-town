extends Control

var map: Node
var viewport: SubViewport
var camera: Camera3D
var map_material: ShaderMaterial
var anchor:=Vector3.ZERO
var captured:=false
var capturing:=false
var clock:=0.0
var picture: TextureRect
var tiles=preload("res://minimap_tile_cache.gd").new()
var active_cell:=Vector2i(2147483647,2147483647)
var active_version:=-1
var captures:=0
var navigation:=preload("res://hud_navigation.gd").new()
var task: Dictionary={}
var destination_label: Label
var direction_label: Label
var back_to_player: Button
var locator_mode:=false
var task_name:=""
var requested_cell:=Vector2i(2147483647,2147483647)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;size=Vector2(190,190)
	tooltip_text="Open your journal · map, life, activities and challenges"
	viewport=SubViewport.new();viewport.world_3d=map.viewport.world_3d;viewport.size=Vector2i(256,256);viewport.positional_shadow_atlas_size=0;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.size=180;camera.far=1000;camera.environment=map.camera.environment;viewport.add_child(camera);camera.current=true
	picture=TextureRect.new();picture.show_behind_parent=true;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.size=Vector2(190,190);picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(picture);picture.texture=viewport.get_texture()
	map_material=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform vec2 map_center=vec2(0.5);
uniform float heading=0.0;
void fragment(){
 vec2 local=UV-vec2(0.5);
 float edge=1.0-smoothstep(0.485,0.5,length(local));
 float c=cos(heading);float s=sin(heading);
 vec2 sample_uv=map_center+mat2(vec2(c,s),vec2(-s,c))*local*0.5;
 vec4 pixel=texture(TEXTURE,clamp(sample_uv,vec2(0.0),vec2(1.0)));
 COLOR=vec4(pixel.rgb,pixel.a*edge);
}"""
	map_material.shader=shader;picture.material=map_material
	move_child(picture,0)
	var captions:=PanelContainer.new()
	captions.position=Vector2(0,194);captions.custom_minimum_size.x=190
	captions.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(captions)
	var backdrop:=StyleBoxFlat.new();backdrop.bg_color=Color("18261fe0");backdrop.set_corner_radius_all(7);backdrop.set_content_margin_all(5)
	captions.add_theme_stylebox_override("panel",backdrop)
	var column:=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;captions.add_child(column)
	for color in [Color("ffe3a5"),Color("e5e6d6")]:
		var line:=Label.new();line.custom_minimum_size.x=180;line.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;line.add_theme_color_override("font_color",color);line.add_theme_font_size_override("font_size",14);column.add_child(line)
		if not destination_label:destination_label=line
		else:direction_label=line
	back_to_player=Button.new();back_to_player.text="Back to player";back_to_player.position=Vector2(0,250);back_to_player.custom_minimum_size=Vector2(190,34)
	back_to_player.focus_mode=Control.FOCUS_NONE;back_to_player.pressed.connect(recenter_overhead);add_child(back_to_player);back_to_player.hide()

func player_point() -> Vector3:
	return map.town.home_district.porch if map.town.home_district.inside else map.town.player.global_position

func map_point() -> Vector3:
	return map.town.overview_focus if locator_mode else player_point()

func recenter_overhead() -> void:
	if map.town.view_mode!=1:return
	var point:=player_point();point.y=0
	map.town.overview_focus=point;map.town.update_camera()
	queue_redraw()

func _process(delta: float) -> void:
	var journal: Node=map.town.get("interface_ui")
	visible=not map.opened and map.town.life.navigation_ready and not map.town.life.active and not (journal and journal.active) and not map.town.builder.active
	if not visible:return
	position=Vector2(get_viewport_rect().size.x-214,70)
	clock+=delta
	var overhead: bool=map.town.view_mode==1
	if overhead!=locator_mode:locator_mode=overhead;clock=.21
	var point:=map_point()
	map_material.set_shader_parameter("heading",0.0 if locator_mode else -map.town.player.rotation.y)
	map_material.set_shader_parameter("map_center",Vector2(.5+(point.x-anchor.x)/180,.5+(point.z-anchor.z)/180))
	if clock>.2:
		clock=0;refresh_directions();queue_redraw()
		map.scenery_cache.poll_changes()
		var cell: Vector2i=tiles.key(point)
		if not captured or cell!=active_cell or map.scenery_cache.area_revision(tiles.area(cell))!=active_version:
			if not capturing and not map.refresh_pending and (not locator_mode or cell==requested_cell):capture.call_deferred()
		requested_cell=cell

func refresh_directions() -> void:
	task=map.navigation_objective()
	back_to_player.visible=locator_mode
	destination_label.get_parent().get_parent().visible=locator_mode or not task.is_empty()
	if locator_mode:
		destination_label.text="Overhead locator"
		direction_label.text="You ●   ·   Camera □"
		return
	if task.is_empty():navigation.clear();task_name="";return
	var from:=player_point()
	var name: String=task.get("name","Tracked destination")
	var destination: Vector3=task.point
	if name!=task_name:navigation.clear();task_name=name
	var distance: float=navigation.flat_distance(from,destination)
	destination_label.text="%s · %d m"%[name,roundi(distance)]
	destination_label.tooltip_text=task.get("text",name)
	if map.town.home_district.inside:direction_label.text="Leave your home first";return
	if distance<=3:direction_label.text="Destination nearby";return
	navigation.update(map.town,from,destination)
	var index:=navigation.next_index(from)
	direction_label.text=navigation.turn_hint(index) if index>=0 else "Arrow shows direction"

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var journal: Node=map.town.get("interface_ui")
		if journal:journal.open_page("Map")
		else:map.open()
		accept_event()

func capture() -> void:
	if capturing or map.opened:return
	map.scenery_cache.poll_changes()
	var cell: Vector2i=tiles.key(map_point())
	var area: Rect2=tiles.area(cell)
	var version: int=map.scenery_cache.area_revision(area)
	var cached: Texture2D=tiles.find(cell,version)
	if cached:
		show_tile(cell,cached,version);return
	if DisplayServer.get_name()=="headless":return
	capturing=true
	var target: Vector3=tiles.anchor(cell)
	camera.global_position=target+Vector3.UP*300;camera.look_at(target,Vector3.FORWARD)
	map.refresh_scenery(area)
	version=map.scenery_cache.area_revision(area)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for frame in range(3):await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	map.scenery_cache.poll_changes()
	if version==map.scenery_cache.area_revision(area):
		var texture:=ImageTexture.create_from_image(viewport.get_texture().get_image())
		tiles.store(cell,texture,version);show_tile(cell,texture,version);captures+=1
	else:captured=false
	capturing=false

func show_tile(cell: Vector2i,texture: Texture2D,version: int) -> void:
	active_cell=cell;active_version=version;anchor=tiles.anchor(cell);picture.texture=texture;captured=true

func map_offset(point: Vector3) -> Vector2:
	var offset:=point-map_point()
	return Vector2(offset.x,offset.z).rotated(0 if locator_mode else map.town.player.rotation.y)*(190.0/90.0)

func _draw() -> void:
	var center:=Vector2(95,95)
	draw_arc(center,95,0,TAU,64,Color("e6ce99"),3,true)
	var north:=center+Vector2(0,-76).rotated(0 if locator_mode else map.town.player.rotation.y)
	draw_string_outline(ThemeDB.fallback_font,north+Vector2(-5,5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color("18241c"))
	draw_string(ThemeDB.fallback_font,north+Vector2(-5,5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	if locator_mode:
		var marker:=center+map_offset(player_point()).limit_length(71)
		if not task.is_empty():
			var destination:=center+map_offset(task.point).limit_length(74)
			draw_circle(destination,7,Color("57391a"));draw_circle(destination,4,Color("ffd582"))
		draw_rect(Rect2(center-Vector2(13,10),Vector2(26,20)),Color.WHITE,false,2)
		draw_circle(marker,8,Color("143340"));draw_circle(marker,5,Color("77e6ff"))
		return
	if not task.is_empty():draw_objective(center)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-10),center+Vector2(-7,8),center+Vector2(7,8)]),Color("77e6ff"))

func draw_objective(center: Vector2) -> void:
	var color:=Color("ffd582")
	var next:=navigation.next_index(player_point()) if not map.town.home_district.inside else -1
	if next>=0:
		var previous:=Vector2.ZERO
		for index in range(next,navigation.path.size()):
			var offset:=map_offset(navigation.path[index])
			if offset.length()>83:break
			draw_line(center+previous,center+offset,Color("4c371c"),6,true)
			draw_line(center+previous,center+offset,color,3,true)
			previous=offset
	var direction:=map_offset(task.point)
	if direction.length()>72 and next>=0:direction=map_offset(navigation.path[next]).normalized()*72
	var marker:=center+direction.limit_length(72)
	if direction.length()<68:
		draw_circle(marker,7,Color("57391a"));draw_circle(marker,4,color)
	else:
		var forward:=direction.normalized();var side:=forward.orthogonal()
		draw_colored_polygon(PackedVector2Array([marker+forward*9,marker-forward*6+side*6,marker-forward*6-side*6]),color)

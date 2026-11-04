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

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new();viewport.world_3d=map.town.get_world_3d();viewport.size=Vector2i(384,384);viewport.positional_shadow_atlas_size=0;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
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

func player_point() -> Vector3:
	return map.town.home_district.porch if map.town.home_district.inside else map.town.player.global_position

func _process(delta: float) -> void:
	visible=not map.opened and map.town.life.navigation_ready and not map.town.life.active
	if not visible:return
	position=Vector2(get_viewport_rect().size.x-214,70)
	clock+=delta
	var point:=player_point()
	map_material.set_shader_parameter("heading",-map.town.player.rotation.y)
	map_material.set_shader_parameter("map_center",Vector2(.5+(point.x-anchor.x)/180,.5+(point.z-anchor.z)/180))
	if clock>.2:
		clock=0;queue_redraw()
		if not captured or Vector2(point.x-anchor.x,point.z-anchor.z).length()>24:
			if not capturing and not map.refresh_pending:capture.call_deferred()

func capture() -> void:
	if capturing:return
	capturing=true;anchor=player_point();anchor.y=0
	camera.global_position=anchor+Vector3.UP*300;camera.look_at(anchor,Vector3.FORWARD)
	var ranges: Dictionary={}
	for mesh: MeshInstance3D in map.town.find_children("*","MeshInstance3D",true,false):
		ranges[mesh]=mesh.visibility_range_end;mesh.visibility_range_end=0
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for frame in range(3):await RenderingServer.frame_post_draw
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for mesh in ranges:
		if is_instance_valid(mesh):mesh.visibility_range_end=ranges[mesh]
	captured=true;capturing=false

func _draw() -> void:
	var center:=Vector2(95,95)
	draw_arc(center,95,0,TAU,64,Color("e6ce99"),3,true)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-10),center+Vector2(-7,8),center+Vector2(7,8)]),Color("77e6ff"))
	var north:=center+Vector2(0,-76).rotated(map.town.player.rotation.y)
	draw_string(ThemeDB.fallback_font,north+Vector2(-5,5),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	var task: Dictionary=map.objective()
	if not task.is_empty():
		var offset: Vector3=task.point-player_point()
		var direction:=Vector2(offset.x,offset.z).rotated(map.town.player.rotation.y)
		var marker:=center+direction.limit_length(38)*2
		var forward:=direction.normalized()
		draw_colored_polygon(PackedVector2Array([marker+forward*9,marker-forward*6+forward.orthogonal()*6,marker-forward*6-forward.orthogonal()*6]),Color("ffd582"))

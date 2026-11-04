extends Node3D

var town: Node3D
var district: Node3D
var doors: Array[Node3D]=[]
var entry := Vector3.ZERO
var layout: Dictionary
var bounds: Rect2
var visual: Node3D
var loading:=false
var stream_clock:=0.0
var door_visuals: Array[Node3D]=[]
const VISUAL_PATH="res://downloaded/neighbour_town/industrial_town.glb"

func _ready() -> void:
	name="NeighbouringIndustrialTown"
	town=get_parent()
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/neighbour_town/layout.json"))
	district=load("res://downloaded/neighbour_town/collision.scn").instantiate()
	district.name="ChickenShootGunTown"
	district.position=Vector3(layout.position[0],0,layout.position[2])
	add_child(district)
	entry=Vector3(layout.entry[0],layout.entry[1],layout.entry[2])
	bounds=Rect2(Vector2(-layout.width/2,410-layout.depth/2),Vector2(layout.width,layout.depth))
	for scenery in get_tree().get_nodes_in_group("backdrop_scenery"):
		if bounds.grow(8).has_point(Vector2(scenery.position.x,scenery.position.z)):
			scenery.get_parent().remove_child(scenery)
			scenery.queue_free()
	# Continue the same earth past the original southern edge.
	var ground: MeshInstance3D=town.box(self,Vector3(600,30,180),Vector3(0,-15.05,590),Color("667447"),true)
	ground.material_override=town.get_node("SharedGround").material_override
	for marker in district.get_children():
		if not marker.has_meta("door_size"):continue
		var size: Vector3=marker.get_meta("door_size")
		var door: Node3D=load("res://door.gd").new()
		door.door_name="industrial town door "+str(doors.size()+1)
		door.set_meta("source_leaf",String(marker.name));door.transform=marker.transform
		door.width=size.x;door.height=size.y;door.depth=size.z
		district.add_child(door);doors.append(door)
		marker.queue_free()
	town.expansion.road([Vector3(0,0,61),Vector3(0,0,entry.z+4)],6.0)
	signpost(Vector3(3,0,91),"Southern road\nIndustrial town ↓")
	signpost(entry+Vector3(5,0,-6),"Chicken Shoot Gun\nIndustrial Town")
	town.locations.append({"name":"Chicken Shoot Gun Industrial Town","position":[0,0,410],"entry":[entry.x,entry.y,entry.z]})
	print("NEIGHBOUR_TOWN_READY footprint=",bounds.size," source_scale=",layout.scale," human_door_m=",layout.reference_human_door_height," doors=",doors.size()," connected_road=true")

func distance_to_district(point: Vector3) -> float:
	var flat:=Vector2(point.x,point.z)
	return flat.distance_to(Vector2(clampf(flat.x,bounds.position.x,bounds.end.x),clampf(flat.y,bounds.position.y,bounds.end.y)))

func _process(delta: float) -> void:
	stream_clock+=delta
	if stream_clock<.5:return
	stream_clock=0
	if not is_instance_valid(town.player):return
	var distance:=distance_to_district(town.player.global_position)
	var camera:=get_viewport().get_camera_3d()
	if camera:distance=minf(distance,distance_to_district(camera.global_position))
	update_stream(distance,float(town.get_meta("district_load_distance",150.0)))

func update_stream(distance: float,radius: float) -> void:
	if loading:
		var status:=ResourceLoader.load_threaded_get_status(VISUAL_PATH)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var packed:=ResourceLoader.load_threaded_get(VISUAL_PATH) as PackedScene
			loading=false
			if distance<=radius+60:attach_visual(packed)
		elif status==ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(VISUAL_PATH);loading=false
			push_warning("Industrial scenery could not load; collision and routes remain available.")
	elif is_instance_valid(visual):
		if distance>radius+60:unload_visual()
	elif distance<radius:
		loading=ResourceLoader.load_threaded_request(VISUAL_PATH,"PackedScene")==OK

func attach_visual(packed: PackedScene) -> void:
	visual=packed.instantiate();district.add_child(visual)
	var leaves: Dictionary={}
	for door in doors:leaves[door.get_meta("source_leaf")]=door
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end=480;mesh.visibility_range_end_margin=30
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if leaves.has(String(mesh.name)):
			var door: Node3D=leaves[String(mesh.name)]
			var relative: Transform3D=district.global_transform.affine_inverse()*mesh.global_transform
			mesh.get_parent().remove_child(mesh)
			var closed: Transform3D=district.global_transform.affine_inverse()*door.get_closed_transform()
			mesh.transform=closed.affine_inverse()*relative;door.add_child(mesh);door_visuals.append(mesh)
	print("INDUSTRIAL_VISUALS_LOADED")

func unload_visual() -> void:
	for mesh in door_visuals:
		if is_instance_valid(mesh):mesh.queue_free()
	door_visuals.clear()
	if is_instance_valid(visual):visual.queue_free()
	visual=null
	print("INDUSTRIAL_VISUALS_UNLOADED")

func signpost(point: Vector3,text: String) -> void:
	town.box(self,Vector3(.14,2.2,.14),point+Vector3.UP*1.1,Color("59422e"),false)
	var label := Label3D.new()
	add_child(label)
	label.position=point+Vector3.UP*2.0
	label.text=text
	label.font_size=28
	label.pixel_size=.012
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size=8

extends Node3D

var town: Node3D
var district: Node3D
var doors: Array[Node3D]=[]
var entry := Vector3.ZERO
var layout: Dictionary
var bounds: Rect2

func _ready() -> void:
	name="NeighbouringIndustrialTown"
	town=get_parent()
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/neighbour_town/layout.json"))
	district=load("res://downloaded/neighbour_town/industrial_town.glb").instantiate()
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
	var leaves: Dictionary={}
	for data in layout.doors:leaves[data.name]=data
	for mesh: MeshInstance3D in district.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end=480
		mesh.visibility_range_end_margin=30
		if leaves.has(String(mesh.name)):
			make_door(mesh)
		else:mesh.create_trimesh_collision()
	town.expansion.road([Vector3(0,0,61),Vector3(0,0,entry.z+4)],6.0)
	signpost(Vector3(3,0,91),"Southern road\nIndustrial town ↓")
	signpost(entry+Vector3(5,0,-6),"Chicken Shoot Gun\nIndustrial Town")
	town.locations.append({"name":"Chicken Shoot Gun Industrial Town","position":[0,0,410],"entry":[entry.x,entry.y,entry.z]})
	print("NEIGHBOUR_TOWN_READY footprint=",bounds.size," source_scale=",layout.scale," human_door_m=",layout.reference_human_door_height," doors=",doors.size()," connected_road=true")

func make_door(mesh: MeshInstance3D) -> void:
	var box := mesh.get_aabb()
	var relative: Transform3D=district.global_transform.affine_inverse()*mesh.global_transform
	box=relative*box
	var across_x := box.size.x>=box.size.z
	var hinge := Vector3(box.position.x,box.position.y,box.get_center().z) if across_x else Vector3(box.get_center().x,box.position.y,box.position.z)
	var closed := Transform3D(Basis(Vector3.UP,0 if across_x else -PI/2),hinge)
	var door := Node3D.new()
	door.set_script(load("res://door.gd"))
	door.door_name="industrial town door"
	door.set_meta("source_leaf",String(mesh.name))
	door.width=maxf(box.size.x,box.size.z)
	door.height=box.size.y
	door.depth=clampf(minf(box.size.x,box.size.z),.08,.35)
	door.transform=closed
	mesh.get_parent().remove_child(mesh)
	mesh.transform=closed.affine_inverse()*relative
	door.add_child(mesh)
	district.add_child(door)
	doors.append(door)

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

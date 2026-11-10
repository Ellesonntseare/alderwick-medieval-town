extends Node3D

var town: Node3D
var rooms: Array[Node3D]=[]
var entrances: Array[Dictionary]=[]
var portals: Array[Dictionary]=[] # No separate-room transitions in this build.
var cache: Dictionary={}
var layout: Dictionary={}
var floors: Array[Dictionary]=[]
var western_center := Vector3(-170,0,95)
var western_scale := 1.45
var prepared := false

func _ready() -> void:
	town=get_parent()
	name="NativeDistricts"
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/native-interiors.json"))
	await build()
	prepared = true

func bounds_in(node: Node3D,reference: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var part: AABB=reference.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		result=part if first else result.merge(part)
		first=false
	return result

func asset(id: String,parent: Node3D,pos: Vector3,solid := false) -> Node3D:
	var path := "res://downloaded/"+id+".glb"
	if not cache.has(path):cache[path]=load(path)
	var node: Node3D=cache[path].instantiate()
	parent.add_child(node)
	node.position=pos
	if id.begins_with("feira_castle"):
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material:
					var copy := material.duplicate() as StandardMaterial3D
					copy.vertex_color_use_as_albedo=true
					copy.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
					mesh.set_surface_override_material(surface,copy)
	if solid:
		town.collisions(node,true)
	return node

func furniture(id: String,parent: Node3D,pos: Vector3,angle := 0.0,solid := true) -> Node3D:
	var sizes := {"Table_Large":Vector3(2.7,0.85,1.1),"Chair_1":Vector3(0.58,1.1,0.55),
		"Stool":Vector3(0.5,0.52,0.5),"Bed_Twin1":Vector3(1.2,0.65,2.1),
		"Bookcase_2":Vector3(1.4,2.2,0.4),"Chandelier":Vector3(0.8,0.7,0.8),
		"Cabinet":Vector3(1.2,1.0,0.4),"Chest_Wood":Vector3(1.0,0.6,0.6),
		"Barrel":Vector3(0.65,1.0,0.65),"Workbench_Drawers":Vector3(1.8,0.9,0.75),
		"Anvil_Log":Vector3(0.7,0.85,0.55),"WeaponStand":Vector3(1.3,1.5,0.6),
		"Mug":Vector3(0.18,0.18,0.15),"Table_Plate":Vector3(0.3,0.025,0.3),
		"Banner_1":Vector3(0.7,2.5,0.3)}
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position=pos
	holder.rotation.y=angle
	town.detailed_prop(id,holder,Vector3.ZERO,sizes.get(id,Vector3.ONE),solid)
	return holder

func masonry() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=Color("77776b")
	material.roughness=0.98
	return material

func box(parent: Node3D,size: Vector3,pos: Vector3,color: String,solid := true) -> MeshInstance3D:
	return town.box(parent,size,pos,Color(color),solid)

func road(points: Array,width := 3.5) -> void:
	var paving := ShaderMaterial.new()
	paving.shader=preload("res://district_path.gdshader")
	for index in range(1,points.size()):
		var a: Vector3=points[index-1]
		var b: Vector3=points[index]
		var mesh := box(self,Vector3(width,0.045,a.distance_to(b)+0.2),(a+b)*0.5+Vector3(0,-0.015,0),"91836a",false)
		mesh.rotation.y=atan2(b.x-a.x,b.z-a.z)
		mesh.material_override=paving
		mesh.set_meta("walking_lane",{"a":a,"b":b,"width":width})

func build() -> void:
	road([Vector3(44,0,0),Vector3(80,0,0),Vector3(80,0,-75),Vector3(155,0,-75)])
	road([Vector3(80,0,0),Vector3(80,0,90),Vector3(135,0,90)])
	road([Vector3(-44,0,0),Vector3(-82,0,0),Vector3(-82,0,95),Vector3(-170,0,95)])
	road([Vector3(0,0,-46),Vector3(0,0,-75),Vector3(-70,0,-75)])
	for spec in [
		["feira_castle","Feira Castle",Vector3(115,0,-30),"castle"],
		["castle_xix","Castle XIX",Vector3(115,0,65),"castle"],
		["viking_hall","Viking Great Hall",Vector3(-99,0,-15),"hall"],
		["viking_house","Viking Residence",Vector3(-100,0,15),"home"],
		["medieval_house","Northern Longhouse",Vector3(-33,0,-89),"home"],
		["boathouse","Veya Boathouse",Vector3(53,0,85),"workshop"],
		["watchtower","Eastern Watchtower",Vector3(80,0,-15),"tower"],
		["downloaded_forge","Outer Forge",Vector3(-67,0,-85),"smithy"],
		["fortress","Fortress Outpost",Vector3(80,0,-110),"barracks"],
		["arnstein_castle","Burg Arnstein",Vector3(182,0,-95),"ruin"]]:
		make_native_building(spec[0],spec[1],spec[2],spec[3])
		if town.loading_screen:await get_tree().process_frame
	var village := asset("satellite_village",self,western_center+Vector3(0,-1.1*western_scale,0))
	village.scale=Vector3.ONE*western_scale
	town.collisions(village)
	town.locations.append({"name":"Western Village","position":[-170,0,95],"scale":western_scale})
	for spec in [["West Croft",Vector3(-245,0,70)],["Orchard House",Vector3(-205,0,170)],
		["West Mill House",Vector3(-135,0,170)],["Western Gate House",Vector3(-100,0,125)]]:
		make_native_building("viking_house",spec[0],spec[1],"home")
		road([Vector3(-82,0,95),Vector3(-82,0,spec[1].z-9),Vector3(spec[1].x,0,spec[1].z-9)])
		if town.loading_screen:await get_tree().process_frame
	var cat := asset("resting_cat",self,Vector3(-14,0,9))
	cat.scale=Vector3.ONE*(0.30/0.55)
	asset("warrior_display",self,Vector3(48,0,49))
	var crossbow := asset("crossbow",self,Vector3(46,1,48))
	crossbow.scale=Vector3.ONE*0.7
	for index in range(8):box(self,Vector3(0.65,1.1,0.2),Vector3(-44+(index%4)*2,0.55,-46-floori(index/4.0)*3),"8c8b7e")
	decorate_market_hall()
	decorate_smithy_tools()
	var walls: Array[Node3D]=[]
	for room in rooms:
		if not room.get_meta("open_roof",false) and room.get_meta("width",0)>4.5:walls.append(room)
	for index in range(23):
		var room: Node3D=walls[index%walls.size()]
		var width: float=room.get_meta("width")
		var depth: float=room.get_meta("depth")
		var painting := asset("paintings/%02d"%index,room,Vector3(-width*0.24+(index/walls.size())*1.2,1.5,depth/2-0.22))
		painting.rotation.y=PI
		painting.add_to_group("paintings")
	var output := FileAccess.open("user://town_locations.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(town.locations,"\t"))
	print("NATIVE_DISTRICTS_READY buildings=",rooms.size()," separate_rooms=0 western_scale=",western_scale)

func make_native_building(id: String,title: String,position: Vector3,kind: String) -> void:
	var data: Dictionary=layout[id]
	var floor_y: float=data.floor
	var dimensions: Array=data.size
	var width: float=dimensions[0]
	var depth: float=dimensions[1]
	var height: float=dimensions[2]
	var center: Array=data.center
	position.y=float(data.get("offset_y",0))
	asset(id+"_walkable",self,position,true)
	var room := Node3D.new()
	room.name=title.replace(" ","")
	add_child(room)
	room.position=position+Vector3(center[0],floor_y,-center[1])
	room.set_meta("width",width)
	room.set_meta("depth",depth)
	room.set_meta("kind",kind)
	room.set_meta("open_roof",data.get("open_roof",false))
	room.add_to_group("native_interiors")
	room.set_meta("preserve_original",data.get("preserve_original",false))
	rooms.append(room)
	var ground := box(room,Vector3(width,0.22,depth),Vector3(0,-0.11,0),"746954")
	if data.get("preserve_original",false):ground.visible=false
	if kind in ["castle","ruin","smithy","barracks"]:ground.material_override=masonry()
	var open_roof: bool=data.get("open_roof",false)
	if not open_roof:
		box(room,Vector3(width+0.2,0.16,depth+0.2),Vector3(0,height,0),"564a3a")
		for side in [-1,1]:
			box(room,Vector3(0.18,height,depth),Vector3(side*width/2,height/2,0),"a39577")
		box(room,Vector3(width,height,0.18),Vector3(0,height/2,depth/2),"a39577")
		for side in [-1,1]:
			var piece_width := (width-1.5)/2
			box(room,Vector3(piece_width,height,0.18),Vector3(side*(0.75+piece_width/2),height/2,-depth/2),"a39577")
		if height>2.5:box(room,Vector3(1.5,height-2.5,0.18),Vector3(0,2.5+(height-2.5)/2,-depth/2),"a39577")
	var doorway: Array=data.door
	var direction: float=data.direction
	var outside_y: float=data.outside_y
	var inside_y: float=data.inner_y
	box(room,Vector3(1.8,0.20,absf(outside_y-inside_y)),Vector3(doorway[0]-center[0],-0.10,center[1]-(outside_y+inside_y)/2),"827a64")
	var door := Node3D.new()
	door.set_script(load("res://door.gd"))
	door.door_name=title
	door.width=1.3
	door.position=Vector3(doorway[0]-center[0]-direction*0.65,0,center[1]-doorway[1])
	door.rotation.y=0 if direction>0 else PI
	var leaf: Node3D=town.model(door,"Door_2_Round",Vector3.ZERO)
	leaf.scale.x=1.3/1.1
	room.add_child(door)
	var closed: Transform3D=door.get_closed_transform()
	var exterior: Vector3=closed*Vector3(0.65,0.05,-2)
	var interior: Vector3=closed*Vector3(0.65,0.05,1.5)
	entrances.append({"label":title,"door":door,"position":exterior,"inside":interior,"room":room})
	floors.append({"center":room.global_position,"width":width,"depth":depth,"height":room.global_position.y,
		"door":closed.origin+closed.basis*Vector3(0.65,0,0),"direction":direction,"corridor":absf(outside_y-inside_y)+2})
	var road_start := Vector3(-82,0,0) if position.x< -74 else Vector3(0,0,-75) if position.x<64 else Vector3(80,0,-75)
	if title=="Castle XIX":road_start=Vector3(140,0,90)
	road([road_start,Vector3(road_start.x,0,exterior.z),Vector3(exterior.x,0,exterior.z)])
	town.add_sign(title,exterior+Vector3(0,2.8,0),0,28)
	var light := OmniLight3D.new()
	light.position=Vector3(0,minf(height-0.25,2.9),0)
	light.light_color=Color("ffe0ad")
	light.light_energy=1.5
	light.omni_range=maxf(width,depth)
	light.add_to_group("interior_lamps")
	room.add_child(light)
	if not open_roof:furniture("Chandelier",room,Vector3(0,maxf(2.0,height-0.8),0),0,false)
	furnish(room,kind,width,depth)
	if bed_count(room)>0:room.add_to_group("enterable_houses")
	town.locations.append({"name":title,"position":[position.x,room.global_position.y,position.z],"native_interior":true})
	print("NATIVE_BUILDING_READY ",title," floor=",room.global_position.y," beds=",bed_count(room)," doorway=1.3x2.35")

func seat(room: Node3D,pos: Vector3,angle := 0.0) -> void:
	furniture("Stool",room,pos)
	var marker := Marker3D.new()
	room.add_child(marker)
	marker.position=pos+Vector3(0,0.52,0)
	marker.rotation.y=angle
	marker.add_to_group("seats")

func bed(room: Node3D,pos: Vector3) -> void:
	furniture("Bed_Twin1",room,pos)
	var marker := Marker3D.new()
	room.add_child(marker)
	marker.position=pos+Vector3(0,0.60,-0.75)
	marker.add_to_group("beds")

func bed_count(room: Node3D) -> int:
	var count := 0
	for child in room.get_children():
		if child.is_in_group("beds"):count+=1
	return count

func furnish(room: Node3D,kind: String,width: float,depth: float) -> void:
	if kind=="smithy":
		furnish_smithy(room,width,depth)
		return
	if kind=="tower":
		seat(room,Vector3(0.72,0,-0.15))
		furniture("Chest_Wood",room,Vector3(-0.45,0,0.6),0,false).scale=Vector3.ONE*0.55
		return
	if kind=="ruin":
		bed(room,Vector3(0.95,0,0.7))
		seat(room,Vector3(-0.7,0,-0.3))
		furniture("Chest_Wood",room,Vector3(-1.3,0,0.9))
		return
	if kind=="hall":
		bed(room,Vector3(-width/2+0.9,0,-depth/2+1.6))
		bed(room,Vector3(width/2-0.9,0,-depth/2+1.6))
	elif kind in ["barracks","workshop","castle"]:
		var rows := 4 if kind=="barracks" else 3 if width>8 else 2
		for side in [-1,1]:
			for row in range(rows):
				bed(room,Vector3(side*(width/2-1.0),0,(row-(rows-1)/2.0)*2.25))
	else:
		for x in [-1,1]:
			for z in [-1,1]:bed(room,Vector3(x*(width/2-1.0),0,z*(depth/2-1.55)))
	var front_storage := kind=="castle" and width<8
	var seat_z := -1.5 if front_storage else depth/2-2.0
	var table_z := -depth/2+0.9 if front_storage else depth/2-1.0
	var shelves_z := -depth/2+0.35 if front_storage else depth/2-0.35
	var storage_z := -depth/2+0.55 if front_storage else depth/2-0.55
	seat(room,Vector3(-0.75,0,seat_z))
	seat(room,Vector3(0.75,0,seat_z))
	if kind!="hall":
		var table := furniture("Table_Large",room,Vector3(0,0,table_z))
		if width<9:table.scale.x=0.65
		furniture("Mug",room,Vector3(0.25,0.86,table_z),0,false)
		furniture("Bookcase_2",room,Vector3(0,0,shelves_z))
	furniture("Barrel",room,Vector3(-width/2+0.55,0,storage_z))
	furniture("Chest_Wood",room,Vector3(width/2-0.65,0,storage_z))

func furnish_smithy(room: Node3D,width: float,depth: float) -> void:
	room.add_to_group("smithy_interiors")
	if room.get_meta("preserve_original",false):
		var fire := OmniLight3D.new()
		room.add_child(fire)
		fire.position=Vector3(-1.625,1.4,-5.0)
		fire.light_color=Color("ff893c")
		fire.light_energy=1.5
		fire.omni_range=5
		seat(room,Vector3(-0.9,0,0.0))
		return
	furniture("Anvil_Log",room,Vector3(-0.75,0,-0.2))
	furniture("Workbench_Drawers",room,Vector3(width/2-0.65,0,0.9),PI/2)
	furniture("WeaponStand",room,Vector3(width/2-0.8,0,-depth/2+0.8))
	furniture("Barrel",room,Vector3(-width/2+0.7,0,-depth/2+0.7))
	seat(room,Vector3(0.5,0,-depth/2+0.9))
	var hearth := Vector3(-1.0,0,depth/2-1.0)
	box(room,Vector3(2.0,0.55,1.6),hearth+Vector3(0,0.275,0),"4a4741")
	box(room,Vector3(2.0,1.4,0.25),hearth+Vector3(0,1.2,0.7),"5d5a51")
	for side in [-1,1]:box(room,Vector3(0.25,1.3,1.3),hearth+Vector3(side*0.9,1.2,0.15),"615d52")
	box(room,Vector3(2.0,0.35,1.5),hearth+Vector3(0,1.95,0.15),"373631")
	box(room,Vector3(0.85,0.55,0.85),hearth+Vector3(0,2.3,0.4),"3e3c36")
	for index in range(9):
		var coal := box(room,Vector3(0.18,0.12,0.22),hearth+Vector3(-0.55+(index%3)*0.4,0.62,-0.2+(index/3)*0.3),"c64d22",false)
		var glow := StandardMaterial3D.new()
		glow.albedo_color=Color("9b3117")
		glow.emission_enabled=true
		glow.emission=Color("ed641e")
		glow.emission_energy_multiplier=1.7
		coal.material_override=glow
	var fire := OmniLight3D.new()
	room.add_child(fire)
	fire.position=hearth+Vector3(0,1.0,-0.15)
	fire.light_color=Color("ff883e")
	fire.light_energy=2.2
	fire.omni_range=6
	for index in range(8):box(room,Vector3(0.35,0.12,0.17),Vector3(width/2-0.65,0.92+(index/4)*0.13,0.45+(index%4)*0.28),"747779",false)

func lay_on_surface(item: Node3D,parent: Node3D,target: Vector3,longest := 0.4) -> void:
	var original := bounds_in(item,parent)
	item.scale=Vector3.ONE*(longest/maxf(original.size.x,maxf(original.size.y,original.size.z)))
	item.rotation.x=PI/2
	var placed := bounds_in(item,parent)
	item.position+=target-Vector3(placed.get_center().x,placed.position.y,placed.get_center().z)
	item.set_meta("supported_surface_y",target.y)

func decorate_market_hall() -> void:
	var room: Node3D=rooms[2]
	for x in [-3.2,3.2]:
		for z in [0.6,2.25]:furniture("Table_Large",room,Vector3(x,0,z))
	for index in range(37):
		var table := index/10
		var x := -3.2 if table%2==0 else 3.2
		var z := 0.6 if table<2 else 2.25
		var slot := index%10
		var item := asset("trade_items/%02d"%index,room,Vector3.ZERO)
		lay_on_surface(item,room,Vector3(x+(slot%5-2)*0.49,0.86,z+(-0.25 if slot<5 else 0.25)))
		item.set_meta("future_trade_item",true)
		item.set_meta("trade_id","curio_%02d"%index)

func decorate_smithy_tools() -> void:
	var room: Node3D=rooms[7]
	var bench := Vector3(-2.6,0,4.8)
	furniture("Workbench_Drawers",room,bench)
	for index in range(17):
		var item := asset("tools/%02d"%index,room,Vector3.ZERO)
		var target := bench+Vector3(-0.65+(index%6)*0.26,0.91,-0.25+(index/6)*0.25)
		lay_on_surface(item,room,target,0.20)
		item.set_meta("smithy_tool",true)

func floor_hint(point: Vector3) -> float:
	for floor in floors:
		var center: Vector3=floor.center
		if absf(point.x-center.x)<floor.width/2 and absf(point.z-center.z)<floor.depth/2:return floor.height
		var door: Vector3=floor.door
		if absf(point.x-door.x)<0.95 and absf(point.z-door.z)<floor.corridor:return floor.height
	return NAN

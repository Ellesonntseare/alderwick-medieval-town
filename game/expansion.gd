extends Node3D

var town: Node3D
var cache: Dictionary={}
var portals: Array[Dictionary]=[]
var used_downloads: Dictionary={}
var travel_cooldown := 0.0
var rooms: Array[Node3D]=[]
var beds: Array[Node3D]=[]

func _ready() -> void:
	town=get_parent()
	name="DownloadedDistricts"
	build()

func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var relative: Transform3D=root.global_transform.affine_inverse()*mesh.global_transform
		var box: AABB=relative*mesh.get_aabb()
		result=box if first else result.merge(box)
		first=false
	return result

func asset(id: String,parent: Node3D,pos: Vector3,angle := 0.0,solid := false) -> Node3D:
	var path := "res://downloaded/"+id+".glb"
	if not ResourceLoader.exists(path):push_error("Missing downloaded asset: "+id);return null
	if not cache.has(path):cache[path]=load(path)
	var model: Node3D=cache[path].instantiate()
	parent.add_child(model)
	model.position=pos
	model.rotation.y=angle
	used_downloads[id]=true
	if id=="satellite_village":
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var shape: AABB=mesh.get_aabb()
			if shape.size.y<0.3 and maxf(shape.size.x,shape.size.z)>40:
				mesh.visible=false
	if id=="feira_castle":
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var mat := mesh.get_active_material(surface) as StandardMaterial3D
				if mat:
					var color_mat := mat.duplicate() as StandardMaterial3D
					color_mat.vertex_color_use_as_albedo=true
					color_mat.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
					mesh.set_surface_override_material(surface,color_mat)
	if solid:town.collisions(model)
	return model

func furniture(id: String,parent: Node3D,pos: Vector3,angle := 0.0,solid := true) -> Node3D:
	var sizes := {
		"Table_Large":Vector3(2.7,0.85,1.1),"Chair_1":Vector3(0.58,1.1,0.55),
		"Bed_Twin1":Vector3(1.4,0.75,2.3),"Bookcase_2":Vector3(1.5,2.4,0.45),
		"Chandelier":Vector3(0.95,0.85,0.95),"Cabinet":Vector3(1.4,1.0,0.4),
		"Chest_Wood":Vector3(1.2,0.7,0.7),"Barrel":Vector3(0.65,1.0,0.65),
		"Nightstand_Shelf":Vector3(0.6,0.7,0.4),"SmallBottles_1":Vector3(0.25,0.18,0.1),
		"Workbench_Drawers":Vector3(1.6,0.9,0.8),"Anvil_Log":Vector3(0.7,0.9,0.55),
		"WeaponStand":Vector3(1.5,1.7,0.7),"BookStand":Vector3(0.5,1.4,0.5),
		"Table_Plate":Vector3(0.3,0.025,0.3),"Mug":Vector3(0.18,0.18,0.15),
		"Banner_1":Vector3(0.7,2.7,0.4),"Banner_2":Vector3(0.7,2.7,0.4)}
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position=pos
	holder.rotation.y=angle
	town.detailed_prop(id,holder,Vector3.ZERO,sizes.get(id,Vector3.ONE),solid)
	return holder

func stone_material(floor_surface := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code="""shader_type spatial;
	varying vec3 wp;
	varying vec3 wn;
	void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(mat3(MODEL_MATRIX)*NORMAL);}
	float random(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
	void fragment(){
	 vec2 p=abs(wn.y)>0.5?wp.xz:(abs(wn.x)>0.5?wp.zy:wp.xy);
	 float row=floor(p.y*2.3);p.x+=mod(row,2.0)*0.43;p*=vec2(1.25,2.3);
	 vec2 cell=floor(p);vec2 f=fract(p);float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	 float mortar=smoothstep(0.018,0.055,edge);float shade=random(cell);
	 vec3 stone=mix(vec3(0.29,0.30,0.28),vec3(0.45,0.44,0.38),shade);
	 ALBEDO=mix(vec3(0.16,0.17,0.15),stone,mortar);ROUGHNESS=0.96;
	}"""
	material.shader=shader
	return material

func road(points: Array,width := 4.0) -> void:
	for i in range(1,points.size()):
		var a: Vector3=points[i-1]
		var b: Vector3=points[i]
		var length := a.distance_to(b)
		var slab: MeshInstance3D=town.box(self,Vector3(width,0.05,length+0.3),(a+b)/2+Vector3(0,-0.01,0),Color("91836a"),false)
		slab.rotation.y=atan2(b.x-a.x,b.z-a.z)

func build() -> void:
	# Main city, castle grounds and the western settlement share one walkable terrain.
	road([Vector3(80,0,-70),Vector3(150,0,-70)])
	road([Vector3(44,0,0),Vector3(80,0,0),Vector3(80,0,-68),Vector3(115,0,-68)])
	road([Vector3(80,0,0),Vector3(80,0,40),Vector3(115,0,40)])
	road([Vector3(-44,0,0),Vector3(-78,0,0),Vector3(-78,0,64),Vector3(-120,0,64)])
	road([Vector3(0,0,-46),Vector3(0,0,-92),Vector3(80,0,-92),Vector3(80,0,-110)])
	for spec in [
		["feira_castle","Feira Castle",Vector3(115,0,-30),"castle"],
		["castle_xix","Castle XIX",Vector3(115,0,65),"castle"],
		["viking_hall","Viking Great Hall",Vector3(-99,0,-15),"hall"],
		["viking_house","Viking Residence",Vector3(-100,0,15),"home"],
		["medieval_house","Northern Longhouse",Vector3(-33,0,-89),"home"],
		["boathouse","Veya Boathouse",Vector3(53,0,85),"workshop"],
		["watchtower","Eastern Watchtower",Vector3(80,0,-15),"guard"],
		["downloaded_forge","Outer Forge",Vector3(-67,0,-85),"smithy"],
		["fortress","Fortress Outpost",Vector3(80,0,-110),"guard"],
		["arnstein_castle","Burg Arnstein",Vector3(182,0,-95),"castle"]
	]:
		make_building(spec[0],spec[1],spec[2],spec[3])
	asset("satellite_village",self,Vector3(-128,0,80),0,true)
	asset("wildlife_collection",self,Vector3(155,0,120))
	asset("resting_cat",self,Vector3(-14,0.03,9),PI/2)
	asset("warrior_display",self,Vector3(48,0,49),PI)
	asset("crossbow",self,Vector3(46,1.0,48),PI/2)
	asset("grave_display",self,Vector3(-38,0,-43))
	for i in range(8):
		town.box(self,Vector3(0.65,1.1,0.2),Vector3(-44+(i%4)*2,0.55,-46-floori(i/4.0)*3),Color("8c8b7e"),true)
	# Reuse the actual castle corridor as an accessible covered gallery.
	var corridor := asset("castle_hallway",self,Vector3(115,0,-80),0,false)
	if corridor:
		corridor.scale=Vector3(1.5,3.3,1)
		town.collisions(corridor)
	for i in range(17):
		asset("tools/%02d"%i,self,Vector3(-13+(i%6)*0.4,0.95,-8-floori(i/6.0)*0.45),0)
	# Four counters support the future trade items instead of floating displays.
	for row in range(4):
		furniture("Table_Large",rooms[2],Vector3(-2.7,0,1.7+row*1.1),0,true)
		furniture("Table_Large",rooms[2],Vector3(2.7,0,1.7+row*1.1),0,true)
	for i in range(37):
		var room: Node3D=rooms[2]
		var item := asset("trade_items/%02d"%i,room,Vector3(-3.8+(i%10)*0.84,0.875,1.7+floori(i/10.0)*1.1))
		if item:
			item.scale=Vector3.ONE*0.45
			item.set_meta("future_trade_item",true)
			item.set_meta("trade_id","curio_%02d"%i)
	for i in range(23):
		var room: Node3D=rooms[i%rooms.size()]
		var painting := asset("paintings/%02d"%i,room,Vector3(-3.8+(i/rooms.size())*2.5,1.6,6.75),PI)
		if painting:painting.add_to_group("paintings")
	# A furnished copied room is available within the village expansion as well.
	town.locations.append({"name":"Western Village","position":[-128,0,80]})
	var saved_locations := FileAccess.open("user://town_locations.json",FileAccess.WRITE)
	saved_locations.store_string(JSON.stringify(town.locations,"\t"))
	print("EXPANSION_READY buildings=",rooms.size()," paintings=23 trade_items=37")

func make_building(id: String,title: String,pos: Vector3,kind: String) -> void:
	print("EXPANSION_LOADING ",title)
	var model := asset(id,self,pos,0,true)
	if not model:return
	var dimensions := bounds(model).size
	var entrance := pos+Vector3(0,0,-dimensions.z/2-1.6)
	# The entry porch creates a full-height, consistent interactive doorway.
	var porch := Node3D.new()
	add_child(porch)
	porch.position=entrance
	for side in [-1,1]:town.box(porch,Vector3(0.5,3,2),Vector3(side*1.2,1.5,0.7),Color("7c776b"),true)
	town.box(porch,Vector3(2.8,0.35,2),Vector3(0,3,0.7),Color("746850"),true)
	var door := Node3D.new()
	add_door(door,porch,Vector3(-0.55,0,0),title)
	print("EXPANSION_SHELL_READY ",title)
	var room := make_room(title,kind,rooms.size())
	rooms.append(room)
	print("EXPANSION_ROOM_READY ",title)
	var exit_door := Node3D.new()
	add_door(exit_door,room,Vector3(-0.55,0,-7),"Exit "+title)
	portals.append({"position":entrance+Vector3(0,0,0.65),"door":door,"to":room.to_global(Vector3(0,0.1,-5.5)),"yaw":PI,"label":title})
	portals.append({"position":room.to_global(Vector3(0,0,-6.6)),"door":exit_door,"to":entrance+Vector3(0,0.1,-1.5),"yaw":PI,"label":"Alderwick"})
	var junction: Vector3=Vector3(-78,0,0) if pos.x< -74 else Vector3(0,0,-72) if pos.z< -74 and pos.x<64 else Vector3(80,0,48) if pos.z>0 else Vector3(80,0,-70)
	if id=="arnstein_castle":junction=Vector3(150,0,-70)
	var approach := entrance-Vector3(0,0,2.2)
	if absf(junction.x-pos.x)<dimensions.x/2+2.0:
		var side_x := pos.x+dimensions.x/2+5.0
		road([junction,Vector3(side_x,0,junction.z),Vector3(side_x,0,approach.z),approach,entrance],3.5)
	else:road([junction,Vector3(junction.x,0,approach.z),approach,entrance],3.5)
	town.add_sign(title,entrance+Vector3(0,3.5,0),0,36)
	town.locations.append({"name":title,"position":[pos.x,pos.y,pos.z],"connected_interior":true})

func add_door(door: Node3D,parent: Node3D,pos: Vector3,title: String) -> void:
	door.set_script(load("res://door.gd"))
	door.door_name=title
	door.position=pos
	town.model(door,"Door_2_Round",Vector3.ZERO)
	parent.add_child(door)

func make_room(title: String,kind: String,index: int) -> Node3D:
	var root := Node3D.new()
	root.name=title.replace(" ","")+"Interior"
	add_child(root)
	root.position=Vector3(index*25,-60,0)
	root.add_to_group("connected_interiors")
	town.box(root,Vector3(12,0.3,14),Vector3(0,-0.15,0),Color("66513d"),true)
	town.box(root,Vector3(12,0.3,14),Vector3(0,4.2,0),Color("514233"),true)
	for side in [-1,1]:
		town.box(root,Vector3(0.3,4.2,14),Vector3(side*6,2.1,0),Color("a69b80"),true)
		town.box(root,Vector3(5.3,4.2,0.3),Vector3(side*3.4,2.1,-7),Color("a69b80"),true)
	town.box(root,Vector3(12,4.2,0.3),Vector3(0,2.1,7),Color("a69b80"),true)
	town.box(root,Vector3(1.5,1.6,0.3),Vector3(0,3.4,-7),Color("a69b80"),true)
	for z in [-5.0,0.0,5.0]:
		var light := OmniLight3D.new()
		light.position=Vector3(0,3.4,z)
		light.light_color=Color("ffdfa4")
		light.light_energy=2.1
		light.omni_range=11
		root.add_child(light)
		furniture("Chandelier",root,Vector3(0,3.2,z),0,false)
	for x in [-3.2,3.2]:
		furniture("Table_Large",root,Vector3(x,0,-1.3))
		for z in [-2.4,-0.1]:
			furniture("Chair_1",root,Vector3(x,0,z),0 if z< -1 else PI)
			var seat := Marker3D.new()
			seat.position=Vector3(x,0.53,z)
			seat.rotation.y=0 if z< -1 else PI
			seat.add_to_group("seats")
			root.add_child(seat)
		furniture("Table_Plate",root,Vector3(x,0.875,-1.3),0,false)
		furniture("Mug",root,Vector3(x+0.4,0.875,-1.2),0,false)
	for x in [-4.9,4.9]:
		furniture("Bookcase_2",root,Vector3(x,0,4.8),PI/2 if x<0 else -PI/2)
		furniture("Chest_Wood",root,Vector3(x,0,-4.8))
		furniture("Barrel",root,Vector3(x,0,1.7))
	for x in [-2.0,2.0]:
		furniture("Bed_Twin1",root,Vector3(x,0,5.3),PI)
		furniture("Nightstand_Shelf",root,Vector3(x+0.9,0,5.4))
		furniture("SmallBottles_1",root,Vector3(x+0.9,0.72,5.4),0,false)
		var bed := Marker3D.new()
		bed.position=Vector3(x,0.65,4.4)
		bed.add_to_group("beds")
		root.add_child(bed)
	if kind in ["smithy","workshop","guard"]:
		furniture("Workbench_Drawers",root,Vector3(0,0,2.4))
		furniture("Anvil_Log",root,Vector3(-2,0,2.8))
		furniture("WeaponStand",root,Vector3(4.7,0,-3.3))
	else:
		furniture("Cabinet",root,Vector3(0,0,6.3))
		furniture("BookStand",root,Vector3(-4.8,0,-3.2))
	if kind in ["castle","guard"]:
		var masonry := stone_material()
		for piece in root.get_children():
			if piece is MeshInstance3D:piece.material_override=masonry
		# Stone supports frame the room without blocking the central aisle.
		for x in [-5.65,5.65]:
			for z in [-4.5,0.0,4.5]:
				var pillar: MeshInstance3D=town.box(root,Vector3(0.55,4.2,0.55),Vector3(x,2.1,z),Color("797c71"),true)
				pillar.material_override=masonry
	if kind=="castle":
		furniture("Banner_1",root,Vector3(-4.7,0,5.7),PI)
		furniture("Banner_2",root,Vector3(4.7,0,5.7),PI)
	return root

func _physics_process(delta: float) -> void:
	travel_cooldown=maxf(0,travel_cooldown-delta)
	if travel_cooldown>0 or not town.player or not town.player.resting.is_empty():return
	for portal in portals:
		if not portal.door.is_open:continue
		var difference: Vector3=town.player.global_position-portal.position
		if absf(difference.x)<0.85 and absf(difference.y)<1 and absf(difference.z)<0.28:
			town.player.global_position=portal.to
			town.player.rotation.y=portal.yaw
			town.player.velocity=Vector3.ZERO
			travel_cooldown=0.8
			break

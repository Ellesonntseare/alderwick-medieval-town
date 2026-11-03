extends Node3D

var town: Node3D
var sites: Array[Dictionary]=[]
var entrances: Array[Dictionary]=[]

func _ready() -> void:
	town=get_parent()
	name="ChateauDistricts"
	var layouts=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/chateaux/layout.json"))
	for data in layouts:build_site(data)
	adapt_shared_ground()
	connect_paths()
	fill_scan_edge_gaps.call_deferred()
	print("CHATEAU_DISTRICTS_READY sites=",sites.size()," shared_earth=true")

func fill_scan_edge_gaps() -> void:
	# Test the detailed visible surface: simplified collision triangles can
	# bridge small openings along the irregular photographed perimeter.
	var surface_probe:=StaticBody3D.new()
	surface_probe.collision_layer=1<<20;surface_probe.collision_mask=0
	add_child(surface_probe)
	for site in sites:
		for mesh in site.root.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree():continue
			var shape:=CollisionShape3D.new()
			shape.shape=mesh.mesh.create_trimesh_shape()
			surface_probe.add_child(shape)
			shape.global_transform=mesh.global_transform
	await get_tree().physics_frame
	var space:=get_world_3d().direct_space_state
	var ground:=town.get_node("SharedGround") as MeshInstance3D
	for site in sites:
		var rectangle: Rect2=site.rect
		var columns:=ceili(rectangle.size.x/2)
		var rows:=ceili(rectangle.size.y/2)
		var cells: Dictionary={}
		var queue: Array[Vector2i]=[]
		for x in range(columns):
			for z in range(rows):
				var point:=rectangle.position+Vector2((x+.5)*2,(z+.5)*2)
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(point.x,35,point.y),Vector3(point.x,-19,point.y),1<<20)
				if space.intersect_ray(ray).is_empty():
					var cell:=Vector2i(x,z)
					cells[cell]=true
					if x==0 or z==0 or x==columns-1 or z==rows-1:queue.append(cell)
		var filled: Dictionary={}
		var cursor:=0
		while cursor<queue.size():
			var cell:=queue[cursor];cursor+=1
			if filled.has(cell):continue
			filled[cell]=true
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if cells.has(cell+delta) and not filled.has(cell+delta):queue.append(cell+delta)
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for cell in filled:
			var a: Vector2=rectangle.position+Vector2(cell.x*2,cell.y*2)
			var b:=Vector2(minf(a.x+2,rectangle.end.x),minf(a.y+2,rectangle.end.y))
			for corner: Vector2 in [a,b,Vector2(a.x,b.y),a,Vector2(b.x,a.y),b]:
				surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(corner.x,-.055,corner.y))
		if not filled.is_empty():
			var apron:=MeshInstance3D.new();apron.mesh=surface.commit()
			apron.material_override=ground.material_override
			add_child(apron);apron.create_trimesh_collision()
		print("CHATEAU_EDGE_GAPS_FILLED id=",site.id," cells=",filled.size())
	surface_probe.queue_free()

func build_site(data: Dictionary) -> void:
	var root := Node3D.new()
	root.name=data.id
	add_child(root)
	root.position=Vector3(data.position[0],0,data.position[2])
	var visual: Node3D=load("res://downloaded/chateaux/"+data.id+".glb").instantiate()
	root.add_child(visual)
	# Light the photographed surfaces in the town rather than retaining the
	# scan's unlit material, which renders incorrectly on this Intel driver.
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		for index in range(mesh.mesh.get_surface_count()):
			var material=mesh.get_active_material(index)
			if material is StandardMaterial3D:
				var lit:=ShaderMaterial.new()
				lit.shader=preload("res://chateau_surface.gdshader")
				lit.set_shader_parameter("scan_texture",material.albedo_texture)
				mesh.set_surface_override_material(index,lit)
	var collision: Node3D=load("res://downloaded/chateaux/"+data.id+"_collision.glb").instantiate()
	root.add_child(collision)
	for mesh: MeshInstance3D in collision.find_children("*","MeshInstance3D",true,false):
		mesh.create_trimesh_collision()
		mesh.visible=false
		for shape: CollisionShape3D in mesh.find_children("*","CollisionShape3D",true,false):
			if shape.shape is ConcavePolygonShape3D:shape.shape.backface_collision=true
	var width: float=data.size[0]
	var depth: float=data.size[2]
	var rectangle := Rect2(root.position.x-width/2,root.position.z-depth/2,width,depth)
	var entry := root.position+Vector3(data.entry_local[0],data.entry_local[1],data.entry_local[2])
	var inside := root.position+Vector3(data.inside_local[0],data.inside_local[1],data.inside_local[2])
	var outside := Vector3(rectangle.position.x-8,0.02,entry.z)
	var sign_point := outside+Vector3(0,0,3)
	town.box(self,Vector3(0.16,2.5,0.16),sign_point+Vector3.UP*1.25,Color("614b33"),false)
	town.box(self,Vector3(3.8,0.65,0.15),sign_point+Vector3.UP*2.1,Color("725b3d"),false)
	town.add_sign(data.title+" →",sign_point+Vector3(0,2.1,0.1),0,22)
	road([outside,Vector3(entry.x,0.03,entry.z)],3.2)
	# A shallow supported path meets the scanned entrance at the same place.
	town.box(self,Vector3(entry.x-outside.x,0.12,2.6),Vector3((entry.x+outside.x)/2,-0.06,entry.z),Color("827a66"),true)
	var run: float=inside.x-entry.x
	var rise: float=inside.y-entry.y
	var passage: MeshInstance3D=town.box(self,Vector3(sqrt(run*run+rise*rise)+2.0,.12,2.4),(entry+inside)*.5-Vector3.UP*.06,Color("827a66"),true)
	passage.rotation.z=atan2(rise,run)
	var paving:=ShaderMaterial.new();paving.shader=preload("res://district_path.gdshader");passage.material_override=paving
	var site := {"id":data.id,"title":data.title,"root":root,"rect":rectangle,"outside":outside,"entry":entry,"inside":inside,"size":data.size,"terrain_min_y":data.terrain_min_y}
	sites.append(site)
	entrances.append({"label":data.title+" ruins","position":outside+Vector3.UP*0.2,"inside":inside})
	town.locations.append({"name":data.title+" ruins","position":[root.position.x,0,root.position.z],"actual_scanned_terrain":true})

func road(points: Array,width := 4.0) -> void:
	var material := ShaderMaterial.new()
	material.shader=preload("res://district_path.gdshader")
	for index in range(1,points.size()):
		var a: Vector3=points[index-1]
		var b: Vector3=points[index]
		var part: MeshInstance3D=town.box(self,Vector3(width,0.045,a.distance_to(b)+0.15),(a+b)/2+Vector3(0,-0.015,0),Color("91836a"),false)
		part.rotation.y=atan2(b.x-a.x,b.z-a.z)
		part.material_override=material

func connect_paths() -> void:
	road([Vector3(80,0,90),Vector3(155,0,90),Vector3(155,0,sites[0].outside.z),sites[0].outside])
	road([Vector3(155,0,-75),Vector3(198,0,-75),Vector3(198,0,sites[1].outside.z),sites[1].outside])
	road([sites[0].outside,Vector3(159,0,sites[0].outside.z),Vector3(159,0,-75)])

func subtract_rect(region: Rect2,hole: Rect2) -> Array[Rect2]:
	if not region.intersects(hole):return [region]
	var cut := region.intersection(hole)
	var pieces: Array[Rect2]=[]
	if cut.position.y>region.position.y:pieces.append(Rect2(region.position,Vector2(region.size.x,cut.position.y-region.position.y)))
	if cut.end.y<region.end.y:pieces.append(Rect2(Vector2(region.position.x,cut.end.y),Vector2(region.size.x,region.end.y-cut.end.y)))
	if cut.position.x>region.position.x:pieces.append(Rect2(Vector2(region.position.x,cut.position.y),Vector2(cut.position.x-region.position.x,cut.size.y)))
	if cut.end.x<region.end.x:pieces.append(Rect2(Vector2(cut.end.x,cut.position.y),Vector2(region.end.x-cut.end.x,cut.size.y)))
	return pieces

func adapt_shared_ground() -> void:
	var original := town.get_node_or_null("SharedGround") as MeshInstance3D
	if not original:return
	var material := original.material_override
	var regions: Array[Rect2]=[Rect2(-500,-500,1000,1000)]
	for site in sites:
		var next: Array[Rect2]=[]
		for region in regions:next.append_array(subtract_rect(region,site.rect))
		regions=next
	original.visible=false
	for body in original.get_children():
		if body is StaticBody3D:body.collision_layer=0;body.collision_mask=0
	# A deep continuous base remains below the town and both excavated sites.
	var base: MeshInstance3D=town.box(self,Vector3(1000,10,1000),Vector3(0,-25.05,0),Color("635b43"),true)
	base.visible=false
	for region in regions:
		var point := region.get_center()
		var slab: MeshInstance3D=town.box(self,Vector3(region.size.x,20,region.size.y),Vector3(point.x,-10.05,point.y),Color("667447"),true)
		slab.material_override=material
	print("SHARED_EARTH_FITTED terrain_cutouts=",sites.size()," ground_regions=",regions.size())

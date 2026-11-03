extends Node

const CATALOG={
	"house":{"title":"Timber house · furnished","category":"Buildings","size":[8,5,8]},
	"cottage":{"title":"Small cottage · furnished","category":"Buildings","size":[6,5,6]},
	"table":{"title":"Dining table","category":"Furniture","asset":"Table_Large","size":[1.8,.88,1.1]},
	"chair":{"title":"Stool · usable","category":"Furniture","asset":"Stool","size":[.48,.48,.48]},
	"bed":{"title":"Bed · usable","category":"Furniture","asset":"Bed_Twin1","size":[1.25,.6,2.15]},
	"cabinet":{"title":"Tall cupboard","category":"Furniture","asset":"Cabinet","size":[.8,1.8,.5]},
	"books":{"title":"Bookcase","category":"Furniture","asset":"Bookcase_2","size":[2.0,2.0,.5]},
	"workbench":{"title":"Workbench","category":"Furniture","asset":"Workbench_Drawers","size":[1.8,.9,.75]},
	"chest":{"title":"Wooden chest","category":"Furniture","asset":"Chest_Wood","size":[1.0,.65,.6]},
	"barrel":{"title":"Barrel","category":"Outdoor","asset":"Barrel","size":[.65,.9,.65]},
	"crate":{"title":"Crate","category":"Outdoor","asset":"Crate_Wooden","size":[.8,.7,.7]},
	"wagon":{"title":"Supply wagon","category":"Outdoor","model":"Prop_Wagon","size":[2.4,2,4]},
	"fence":{"title":"Wooden fence","category":"Outdoor","model":"Prop_WoodenFence_Single","size":[2,1,.3]},
	"tree":{"title":"Tree","category":"Outdoor","size":[4,7,4]},
	"well":{"title":"Stone well with water","category":"Outdoor","size":[3.4,3.3,3]},
	"lamp":{"title":"Street lamp","category":"Outdoor","size":[.5,3.3,.5]}
	,"path":{"title":"Cobblestone path section","category":"Outdoor","size":[4,.05,4]}
}
var town: Node3D
var active:=false
var records: Dictionary={}
var nodes: Dictionary={}
var originals: Dictionary={}
var undo_stack: Array=[]
var redo_stack: Array=[]
var selected:=""
var dragging:=false
var drag_before: Dictionary={}
var drag_offset:=Vector3.ZERO
var camera: Camera3D
var panel: PanelContainer
var hint: Label
var selection_label: Label
var palette: VBoxContainer
var height_input: SpinBox
var scale_input: SpinBox
var snap: CheckBox
var roof_check: CheckBox
var hidden_roofs: Array[Node]=[]
var outline: MeshInstance3D
var saved_view:=1
var saved_process_mode:=0
var dirty:=false
var busy:=false
var next_id:=1
var save_path:="user://town-layout.json"
var camera_target:=Vector3.ZERO
var camera_zoom:=70.0
var category:="Buildings"
var drop_surface: Control
var frozen_collision_modes: Dictionary={}
var hidden_layers: Array[CanvasLayer]=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	town=get_parent()
	if town.economy.testing():save_path="user://review-town-layout.json"
	camera=Camera3D.new();camera.far=1200;camera.fov=52;add_child(camera)
	make_interface()
	var button:=Button.new();button.text="Design town · drag & drop [B]"
	button.pressed.connect(toggle);town.menu_body.add_child(button)
	register_originals()
	load_layout()

func register_originals() -> void:
	for house in get_tree().get_nodes_in_group("enterable_houses"):
		if not house.get_meta("modular_house",false):continue
		var id:="existing:"+String(town.get_path_to(house))
		originals[id]={"node":house,"transform":house.transform}
		nodes[id]=house;house.set_meta("build_id",id)
		for sign in town.find_children("*","Label3D",false,false):
			if String(sign.text).replace("'","").replace(" ","").begins_with(String(house.name).replace("'","").replace(" ","")):sign.reparent(house,true)

func serialize(node: Node3D,asset: String) -> Dictionary:
	return {"asset":asset,"position":[node.position.x,node.position.y,node.position.z],"rotation":node.rotation.y,"scale":node.scale.x}

func transform_record(node: Node3D,record: Dictionary) -> void:
	var p: Array=record.position
	node.position=Vector3(p[0],p[1],p[2]);node.rotation.y=float(record.rotation);node.scale=Vector3.ONE*float(record.get("scale",1))
	update_lane(node,record.get("asset",""))

func update_lane(node: Node3D,asset: String) -> void:
	if asset!="path":return
	var part: Node3D=node.get_child(0)
	part.set_meta("walking_lane",{"a":node.to_global(Vector3(-2,0,0)),"b":node.to_global(Vector3(2,0,0)),"width":4*node.scale.x})

func create_prefab(id: String,asset: String) -> Node3D:
	if not CATALOG.has(asset):return null
	var root:=Node3D.new();root.name="TownEdit_"+id;town.add_child(root)
	root.set_meta("build_id",id)
	var data: Dictionary=CATALOG[asset]
	if asset=="path":
		var part: MeshInstance3D=town.box(root,Vector3(4,.05,4),Vector3(0,-.015,0),Color("91836a"),false)
		var material:=ShaderMaterial.new();material.shader=preload("res://district_path.gdshader");part.material_override=material
	elif asset in ["house","cottage"]:
		var previous:=town.get_child_count()
		var width:=8 if asset=="house" else 6
		town.building("Custom "+asset+" "+id,Vector3.ZERO,width,width,1,0)
		town.locations.pop_back()
		var additions: Array=[]
		for index in range(previous,town.get_child_count()):additions.append(town.get_child(index))
		for child in additions:child.reparent(root,true)
	elif data.has("asset"):
		var size: Array=data.size
		town.detailed_prop(data.asset,root,Vector3.ZERO,Vector3(size[0],size[1],size[2]),true)
		if asset in ["chair","bed"]:
			var anchor:=Marker3D.new();root.add_child(anchor)
			anchor.position=Vector3(0,.48,0) if asset=="chair" else Vector3(0,.6,-.85)
			anchor.add_to_group("seats" if asset=="chair" else "beds")
	elif data.has("model"):town.model(root,data.model,Vector3.ZERO,0,true)
	else:
		var previous:=town.get_child_count()
		if asset=="tree":town.tree(Vector3.ZERO,1)
		elif asset=="well":town.well(Vector3.ZERO)
		elif asset=="lamp":town.lamp(Vector3.ZERO)
		var additions: Array=[]
		for index in range(previous,town.get_child_count()):additions.append(town.get_child(index))
		for child in additions:child.reparent(root,true)
	nodes[id]=root
	var selection_body:=StaticBody3D.new();selection_body.collision_layer=1<<22;selection_body.collision_mask=0
	root.add_child(selection_body)
	var selection_shape:=CollisionShape3D.new();var footprint:=BoxShape3D.new()
	footprint.size=Vector3(data.size[0],maxf(.15,data.size[1]),data.size[2])
	selection_shape.shape=footprint;selection_shape.position.y=footprint.size.y/2;selection_body.add_child(selection_shape)
	if active:
		for body in root.find_children("*","CollisionObject3D",true,false):body.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	return root

func world_point(mouse: Vector2) -> Variant:
	var plane:=Plane(Vector3.UP,float(height_input.value) if height_input else 0)
	var hit=plane.intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if hit==null:return null
	if absf(hit.x)>470 or absf(hit.z)>470:return null
	if snap and snap.button_pressed:hit.x=snappedf(hit.x,.5);hit.z=snappedf(hit.z,.5)
	return hit

func collisions_of(node: Node) -> Array[RID]:
	var ids: Array[RID]=[]
	if node is CollisionObject3D:ids.append(node.get_rid())
	for body in node.find_children("*","CollisionObject3D",true,false):ids.append(body.get_rid())
	return ids

func placement_valid(node: Node3D,asset: String) -> bool:
	# Thin floors and loose furnishings can be placed inside existing rooms.
	# Check the usable footprint above the floor, not the room's roof.
	var size: Array=CATALOG.get(asset,{"size":[node.get_meta("width",6),3,node.get_meta("depth",6)]}).size
	if asset in ["house","cottage","existing"]:
		for door in get_tree().get_nodes_in_group("doors"):
			if node.is_ancestor_of(door):continue
			var approach: Vector3=node.to_local(door.get_closed_transform()*Vector3(door.width/2,0,-1.5))
			if absf(approach.x)<float(size[0])/2+.7 and absf(approach.z)<float(size[2])/2+.7:return false
		var routing=town.life.get("walking_routes")
		if routing:
			var blocked_paving:=0
			for cell: Vector2i in routing.paved:
				var point: Vector3=node.to_local(Vector3(cell.x,node.position.y,cell.y))
				if absf(point.x)<float(size[0])/2+.2 and absf(point.z)<float(size[2])/2+.2:blocked_paving+=1
				if blocked_paving>6:return false
	var shape:=BoxShape3D.new()
	shape.size=Vector3(maxf(.12,size[0]*node.scale.x-.12),minf(float(size[1])*.65,1.6)*node.scale.x,maxf(.12,size[2]*node.scale.z-.12))
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.exclude=collisions_of(node)
	query.transform=Transform3D(Basis(Vector3.UP,node.rotation.y),node.position+Vector3.UP*(shape.size.y/2+.15))
	var overlaps:=town.get_world_3d().direct_space_state.intersect_shape(query,8)
	if not overlaps.is_empty():
		if town.economy.testing():print("BUILDER_OVERLAP asset=",asset," point=",node.position," ignored=",query.exclude," hits=",overlaps)
		return false
	var ray:=PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*.15,node.position-Vector3.UP*.35,1)
	ray.exclude=query.exclude
	var support:=town.get_world_3d().direct_space_state.intersect_ray(ray)
	if support.is_empty() and town.economy.testing():print("BUILDER_NO_SUPPORT asset=",asset," point=",node.position)
	return not support.is_empty()

func push_undo() -> void:
	undo_stack.append(records.duplicate(true));redo_stack.clear()
	if undo_stack.size()>60:undo_stack.pop_front()

func place(asset: String,point: Vector3) -> bool:
	if not CATALOG.has(asset) or busy:return false
	var id:="placed_"+str(next_id);next_id+=1
	var node:=create_prefab(id,asset)
	node.position=point
	update_lane(node,asset)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not placement_valid(node,asset):
		nodes.erase(id);node.queue_free();hint.text="That overlaps a wall or another object. Choose a clearer spot.";return false
	push_undo();records[id]=serialize(node,asset);selected=id;dirty=true
	save_layout();show_selection();hint.text="Placed "+CATALOG[asset].title
	return true

func pick(mouse: Vector2) -> String:
	var origin:=camera.project_ray_origin(mouse)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(mouse)*1000,1|(1<<22))
	var hit:=town.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return ""
	var node: Node=hit.collider
	while node and node!=town:
		if node.has_meta("build_id"):return node.get_meta("build_id")
		node=node.get_parent()
	return ""

func apply_records(snapshot: Dictionary) -> void:
	var old_transforms: Dictionary={}
	for id in originals:old_transforms[id]=nodes[id].global_transform
	for id in nodes.keys():
		if originals.has(id):nodes[id].transform=originals[id].transform
		else:nodes[id].free();nodes.erase(id)
	records=snapshot.duplicate(true)
	for id in records:
		var node: Node3D=nodes.get(id)
		if not node:node=create_prefab(id,records[id].asset)
		if node:transform_record(node,records[id])
	for id in originals:relocate_residents(nodes[id],old_transforms[id],nodes[id].global_transform)
	dirty=true;selected="";show_selection();save_layout()

func undo() -> void:
	if undo_stack.is_empty():return
	redo_stack.append(records.duplicate(true));apply_records(undo_stack.pop_back())

func redo() -> void:
	if redo_stack.is_empty():return
	undo_stack.append(records.duplicate(true));apply_records(redo_stack.pop_back())

func delete_selected() -> void:
	if selected.is_empty():return
	if originals.has(selected):hint.text="This is a resident's original building. Move it, or remove a building you placed.";return
	if town.families:
		for family in town.families.membership.values():
			if nodes[selected].is_ancestor_of(family.home):hint.text="A family lives here. You can move their home.";return
	push_undo();records.erase(selected)
	nodes[selected].queue_free();nodes.erase(selected);selected="";dirty=true
	show_selection();save_layout()

func change_rotation() -> void:
	if selected.is_empty():return
	var old_transform: Transform3D=nodes[selected].global_transform
	var before: float=nodes[selected].rotation.y
	nodes[selected].rotation.y+=PI/12
	await get_tree().physics_frame
	if not placement_valid(nodes[selected],records.get(selected,{}).get("asset","existing")):nodes[selected].rotation.y=before;return
	push_undo()
	if originals.has(selected):relocate_residents(nodes[selected],old_transform,nodes[selected].global_transform)
	update_lane(nodes[selected],records.get(selected,{}).get("asset","existing"))
	records[selected]=serialize(nodes[selected],records.get(selected,{}).get("asset","existing"));dirty=true;show_selection();save_layout()

func change_scale(value: float) -> void:
	if selected.is_empty() or originals.has(selected):return
	var before: Vector3=nodes[selected].scale
	nodes[selected].scale=Vector3.ONE*value
	await get_tree().physics_frame
	if not placement_valid(nodes[selected],records[selected].asset):nodes[selected].scale=before;show_selection();return
	push_undo()
	update_lane(nodes[selected],records[selected].asset)
	records[selected]=serialize(nodes[selected],records[selected].asset);dirty=true;show_selection();save_layout()

func save_layout() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":1,"next_id":next_id,"objects":records}))

func load_layout() -> void:
	if not FileAccess.file_exists(save_path):return
	var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if saved is Dictionary and saved.get("objects") is Dictionary:
		next_id=maxi(1,int(saved.get("next_id",1)))
		apply_records(saved.objects)
		dirty=false

func toggle() -> void:
	if busy:return
	if active:finish.call_deferred();return
	if town.life.active:town.life.close_dialog()
	if town.character_directory and town.character_directory.is_open():town.character_directory.hide_directory()
	town.adventures.stop_work()
	if town.player.get("resting")!=null and not town.player.resting.is_empty():town.player.stand_from_furniture(true)
	if town.adventures.journal.visible:town.adventures.toggle_journal()
	saved_view=town.view_mode
	saved_process_mode=town.process_mode
	frozen_collision_modes.clear()
	for body in town.find_children("*","CollisionObject3D",true,false):
		frozen_collision_modes[body]=body.disable_mode
		body.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	town.process_mode=Node.PROCESS_MODE_DISABLED
	active=true;panel.show();drop_surface.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for layer in town.find_children("*","CanvasLayer",true,false):
		if is_ancestor_of(layer) or not layer.visible:continue
		hidden_layers.append(layer);layer.hide()
	camera_target=town.player.position
	camera.current=true;update_camera()
	for person in town.life.people:
		if town.speech:town.speech.stop(person)
	town.music.stream_paused=true
	hint.text="Drag an item from the list into the world. Drag placed objects to move them."

func finish() -> void:
	busy=true;dragging=false;restore_roofs()
	hint.text="Updating walking routes…"
	if dirty and town.life.navigation_ready:await refresh_navigation()
	active=false;panel.hide();drop_surface.hide();outline.hide();camera.current=false
	for layer in hidden_layers:
		if is_instance_valid(layer):layer.show()
	hidden_layers.clear()
	town.process_mode=saved_process_mode
	for body in frozen_collision_modes:
		if is_instance_valid(body):body.disable_mode=frozen_collision_modes[body]
	frozen_collision_modes.clear()
	town.music.stream_paused=false
	town.set_view(saved_view)
	busy=false;dirty=false

func refresh_navigation() -> void:
	# The same capsule and ground rules as initial street sampling; never spawn
	# residents again when a layout changes.
	var life: Node=town.life
	await get_tree().physics_frame
	life.interior_grids.clear();life.street_cells.clear()
	var shape:=CapsuleShape3D.new();shape.radius=.44;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=[town.player.get_rid()]
	var space:=town.get_world_3d().direct_space_state
	for x in range(life.grid.region.position.x,life.grid.region.end.x):
		for z in range(life.grid.region.position.y,life.grid.region.end.y):
			var cell:=Vector2i(x,z)
			var height: float=life.navigation_floor(Vector3(x,0,z),space)
			life.floor_heights[cell]=height;query.transform.origin=Vector3(x,height+.86,z)
			var blocked:=height>2 or not space.intersect_shape(query,1).is_empty()
			if absf(x-64)<4 and abs(z)<74 and abs(z)>1.5 and abs(z-48)>1.5:blocked=true
			life.grid.set_point_solid(cell,blocked)
		if x%20==0:await get_tree().process_frame
	var edges: Array[Vector2i]=[]
	for cell in life.floor_heights:
		if life.grid.is_point_solid(cell):continue
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			if not life.grid.is_in_boundsv(next) or life.grid.is_point_solid(next):continue
			query.transform.origin=Vector3(cell.x+offset.x*.5,(life.floor_heights[cell]+life.floor_heights[next])*.5+.86,cell.y+offset.y*.5)
			if absf(life.floor_heights[cell]-life.floor_heights[next])>.38 or not space.intersect_shape(query,1).is_empty():edges.append(cell);edges.append(next)
	for cell in edges:life.grid.set_point_solid(cell,true)
	var queue: Array[Vector2i]=[life.free_cell(Vector3(0,0,10))]
	life.street_cells[queue[0]]=true
	var index:=0
	while index<queue.size():
		var cell:=queue[index];index+=1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=cell+offset
			if life.grid.is_in_boundsv(next) and not life.grid.is_point_solid(next) and not life.street_cells.has(next):
				life.street_cells[next]=true;queue.append(next)
		if index%10000==0:await get_tree().process_frame
	life.walking_routes.paved.clear();life.walking_routes.build(life)
	for person in life.people:
		person.path=PackedVector3Array();person.path_index=0
		if not person.night_schedule and not person.indoor_house:person.plan()
	if town.day_night.night:life.set_night_routine(true)
	print("BUILDER_NAVIGATION_UPDATED residents=",life.people.size()," connected_cells=",life.street_cells.size())

func update_camera() -> void:
	camera.position=camera_target+Vector3(0,camera_zoom,camera_zoom*.55)
	camera.look_at(camera_target)

func _process(delta: float) -> void:
	if not active or busy:return
	var direction:=Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):direction.z-=1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):direction.z+=1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):direction.x-=1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):direction.x+=1
	camera_target+=direction*delta*camera_zoom*.6;update_camera()
	if dragging and nodes.has(selected):
		var point=world_point(get_viewport().get_mouse_position())
		if point!=null:
			nodes[selected].position=point+drag_offset
			update_lane(nodes[selected],records.get(selected,{}).get("asset",""))
			show_selection()

func _input(event: InputEvent) -> void:
	if not active:
		var focus:=get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B and not town.life.active:
			toggle();get_viewport().set_input_as_handled()
		return
	if busy:return
	if get_viewport().gui_is_dragging():return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE,KEY_B:finish.call_deferred()
			KEY_R:change_rotation()
			KEY_DELETE:delete_selected()
			KEY_Z:
				if event.ctrl_pressed:undo()
			KEY_Y:
				if event.ctrl_pressed:redo()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not panel.get_global_rect().has_point(event.position):
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_zoom=clampf(camera_zoom*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),8,400);update_camera()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected=pick(event.position);show_selection()
				if not selected.is_empty():
					dragging=true;drag_before=records.duplicate(true)
					var point=world_point(event.position)
					drag_offset=nodes[selected].position-point if point!=null else Vector3.ZERO
			else:
				if dragging and nodes.has(selected):
					commit_drag.call_deferred(selected)
				dragging=false
		get_viewport().set_input_as_handled()

func commit_drag(id: String) -> void:
	if not nodes.has(id):return
	var node: Node3D=nodes[id]
	var asset: String=records.get(id,{}).get("asset","existing")
	var old: Transform3D=originals[id].transform if originals.has(id) else Transform3D.IDENTITY
	if drag_before.has(id):
		var record: Dictionary=drag_before[id]
		old=Transform3D(Basis(Vector3.UP,float(record.rotation)).scaled(Vector3.ONE*float(record.scale)),Vector3(record.position[0],record.position[1],record.position[2]))
	await get_tree().physics_frame
	if not placement_valid(node,asset):node.transform=old;hint.text="That position overlaps another object or has no supporting floor.";show_selection();return
	undo_stack.append(drag_before.duplicate(true));redo_stack.clear()
	if originals.has(id):relocate_residents(node,old,node.global_transform)
	records[id]=serialize(node,asset);dirty=true;save_layout()

func relocate_residents(house: Node3D,old: Transform3D,updated: Transform3D) -> void:
	if old.is_equal_approx(updated) or not town.life:return
	for person in town.life.people:
		var local: Vector3=old.affine_inverse()*person.position
		if absf(local.x)<float(house.get_meta("width",6))/2 and absf(local.z)<float(house.get_meta("depth",6))/2:
			person.position=updated*local
		if person.indoor_house==house:
			for index in range(person.indoor_points.size()):person.indoor_points[index]=updated*(old.affine_inverse()*person.indoor_points[index])
			person.route.assign(person.indoor_points)
		if person.home_door and person.home_door.get_parent()==house:person.home_transform=person.home_door.get_closed_transform()

func show_selection() -> void:
	outline.visible=active and nodes.has(selected)
	if not nodes.has(selected):selection_label.text="Nothing selected";return
	var node: Node3D=nodes[selected]
	selection_label.text=String(node.name)+"\nX %.1f · Y %.1f · Z %.1f\nR rotates · Delete removes"%[node.position.x,node.position.y,node.position.z]
	scale_input.set_value_no_signal(node.scale.x)
	scale_input.editable=not originals.has(selected)
	var bounds:=AABB();var first:=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var box: AABB=node.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var mesh:=BoxMesh.new();mesh.size=bounds.size+Vector3.ONE*.08
	outline.mesh=mesh;outline.global_transform=node.global_transform;outline.position=node.to_global(bounds.get_center())

func restore_roofs() -> void:
	for node in hidden_roofs:
		if is_instance_valid(node):node.show()
	hidden_roofs.clear()

func roofs(value: bool) -> void:
	restore_roofs()
	if not value:return
	for mesh in town.find_children("*","MeshInstance3D",true,false):
		var box: AABB=mesh.global_transform*mesh.get_aabb()
		if (String(mesh.name).contains("Roof") or (box.size.y<.3 and box.position.y>2.7 and box.size.x>4 and box.size.z>4)) and mesh.visible:hidden_roofs.append(mesh);mesh.hide()

func make_interface() -> void:
	var layer:=CanvasLayer.new();layer.layer=30;add_child(layer)
	var drop=load("res://build_drop_surface.gd").new();drop.editor=self
	drop_surface=drop
	layer.add_child(drop);drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drop.mouse_filter=Control.MOUSE_FILTER_PASS;drop.hide()
	panel=PanelContainer.new();panel.position=Vector2(20,20);panel.size=Vector2(330,710);layer.add_child(panel);panel.hide()
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.055,.045,.97)
	style.border_color=Color("8c7850");style.set_border_width_all(1)
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=14;style.content_margin_bottom=14
	style.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",style)
	var outer_scroll:=ScrollContainer.new();outer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(outer_scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;outer_scroll.add_child(column)
	var title:=Label.new();title.text="Design Alderwick";column.add_child(title)
	var close:=Button.new();close.text="Save & return to town [B]";close.pressed.connect(toggle);column.add_child(close)
	var categories:=OptionButton.new()
	for value in ["Buildings","Furniture","Outdoor"]:categories.add_item(value)
	categories.item_selected.connect(func(index: int):category=categories.get_item_text(index);fill_palette())
	column.add_child(categories)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=180;column.add_child(scroll)
	palette=VBoxContainer.new();palette.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(palette)
	snap=CheckBox.new();snap.text="Snap to half-metre grid";snap.button_pressed=true;column.add_child(snap)
	roof_check=CheckBox.new();roof_check.text="Hide roofs for furnishing";roof_check.toggled.connect(roofs);column.add_child(roof_check)
	var label:=Label.new();label.text="Floor height (metres)";column.add_child(label)
	height_input=SpinBox.new();height_input.min_value=-18;height_input.max_value=20;height_input.step=.1;column.add_child(height_input)
	label=Label.new();label.text="Selected object scale";column.add_child(label)
	scale_input=SpinBox.new();scale_input.min_value=.5;scale_input.max_value=2;scale_input.step=.1;scale_input.value=1
	scale_input.value_changed.connect(change_scale);column.add_child(scale_input)
	var row:=HBoxContainer.new();column.add_child(row)
	for spec in [["Undo",undo],["Redo",redo],["Rotate",change_rotation],["Remove",delete_selected]]:
		var button:=Button.new();button.text=spec[0];button.pressed.connect(spec[1]);row.add_child(button)
	selection_label=Label.new();selection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(selection_label)
	hint=Label.new();hint.custom_minimum_size.x=280;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
	label=Label.new();label.text="WASD / arrows: pan\nMouse wheel: zoom · R: rotate\nCtrl+Z / Ctrl+Y: undo / redo";column.add_child(label)
	outline=MeshInstance3D.new();outline.visible=false;add_child(outline)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.3,1,.6,.15);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.material_override=material
	fill_palette()

func fill_palette() -> void:
	for child in palette.get_children():palette.remove_child(child);child.queue_free()
	for id in CATALOG:
		if CATALOG[id].category!=category:continue
		var button=load("res://build_palette_item.gd").new()
		button.editor=self;button.asset_id=id;button.text=CATALOG[id].title
		button.tooltip_text="Drag into the world"
		palette.add_child(button)

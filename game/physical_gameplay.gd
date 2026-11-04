extends Node3D

var town: Node3D
var objects: Array[Node3D]=[]
var carried: Node3D
var cart: CharacterBody3D
var pushing:=false
var leading: CharacterBody3D
var mounted: CharacterBody3D
var stamina:=100.0
var crouching:=false
var busy:=0.0
var work: Node3D
var panel: AcceptDialog
var choices: VBoxContainer
var previous_enabled:=true
var previous_mouse:=Input.MOUSE_MODE_VISIBLE
var status: Label
var score:=0
var bolts: Array[Dictionary]=[]
var lamps: Array[OmniLight3D]=[]
var elapsed:=0.0
var tool: Node3D
var gesture:=0.0

func _ready() -> void:
	town=get_parent()
	panel=AcceptDialog.new();panel.title="Hands-on activities";town.add_child(panel)
	choices=VBoxContainer.new();choices.custom_minimum_size.x=450;panel.add_child(choices)
	panel.visibility_changed.connect(func():
		if not panel.visible:town.player.enabled=previous_enabled;Input.mouse_mode=previous_mouse)
	var layer:=CanvasLayer.new();add_child(layer);status=Label.new();layer.add_child(status);status.position=Vector2(24,90)
	setup.call_deferred()

func prop(title: String,asset: String,point: Vector3,kind: String) -> Node3D:
	var object:=StaticBody3D.new();object.name=title;add_child(object);object.position=point
	object.set_meta("activity",kind);object.set_meta("stock",3)
	if not asset.is_empty():town.detailed_prop(asset,object,Vector3.ZERO,Vector3(.65,.65,.65),false)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.6,.6,.6);collision.shape=shape;collision.position.y=.3;object.add_child(collision)
	objects.append(object)
	return object

func setup() -> void:
	while not town.home_district.ready_for_spawn:await get_tree().process_frame
	prop("Vegetable delivery crate","Crate_Wooden",Vector3(-32,.03,37),"carry").set_meta("vegetables",4)
	prop("Timber chopping block","Barrel",Vector3(-27,.03,39),"chop")
	prop("Repair workbench","Workbench_Drawers",Vector3(-24,.03,39),"repair")
	prop("Training dummy","WeaponStand",Vector3(30,.03,38),"training")
	for index in range(3):
		var target_node:=prop("Archery target "+str(index+1),"Barrel",Vector3(30+index*3,.03,47),"target")
		target_node.set_meta("archery_target",true)
	var home: Node3D=town.home_district.interior
	var stool:=prop("Movable home stool","Stool",home.to_global(Vector3(3.5,0,-1)),"carry")
	var seat:=Marker3D.new();stool.add_child(seat);seat.position.y=.52;seat.add_to_group("seats");stool.set_meta("seat",seat)
	var chest:=prop("Home cupboard","Chest_Wood",home.to_global(Vector3(4.5,0,-1)),"cupboard")
	var lid: MeshInstance3D=town.box(chest,Vector3(.65,.07,.65),Vector3(0,.65,0),Color("775437"),false)
	chest.set_meta("lid",lid)
	var lamp:=prop("Home lamp","Mug",home.to_global(Vector3(4.5,0,-2)),"lamp")
	var light:=OmniLight3D.new();lamp.add_child(light);light.position.y=1.0;light.omni_range=6;light.light_color=Color("ffd492");light.light_energy=1.2;lamp.set_meta("light",light);lamps.append(light)
	var ladder:=prop("Loft ladder","",home.to_global(Vector3(5.8,0,0)),"ladder")
	for x in [-.3,.3]:town.box(ladder,Vector3(.08,2.7,.08),Vector3(x,1.35,0),Color("82603d"),false)
	for rung in range(9):town.box(ladder,Vector3(.65,.06,.08),Vector3(0,.2+rung*.29,0),Color("a57a4d"),false)
	cart=CharacterBody3D.new();cart.name="Supply cart";add_child(cart);cart.position=Vector3(-29,.1,34)
	town.box(cart,Vector3(1.2,.2,1.6),Vector3(0,.6,0),Color("785636"),false)
	for x in [-.7,.7]:
		for z in [-.55,.55]:
			var wheel:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.3;mesh.bottom_radius=.3;mesh.height=.12;wheel.mesh=mesh;wheel.rotation.z=PI/2;wheel.position=Vector3(x,.3,z);cart.add_child(wheel)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.35,1,1.7);collider.shape=shape;collider.position.y=.5;cart.add_child(collider)
	cart.set_meta("activity","cart");objects.append(cart)
	load_layout()
	update_cargo()
	town.add_sign("TOOLS & DELIVERIES",Vector3(-28,2.2,39),0,22)
	town.add_sign("TRAINING GROUND",Vector3(30,2.2,37),0,22)

func target() -> Dictionary:
	if carried:return {"kind":"physical","verb":"Place","label":"Place "+String(carried.name),"object":carried}
	if mounted:return {"kind":"physical","verb":"Dismount","label":"Dismount horse","object":mounted}
	if pushing:return {"kind":"physical","verb":"Stop cart","label":"Stop pushing the cart","object":cart}
	var nearest: Node3D
	var distance:=2.3
	for object in objects+get_tree().get_nodes_in_group("animals"):
		if not is_instance_valid(object):continue
		var d: float=object.global_position.distance_to(town.player.global_position)
		if d>=distance:continue
		var ray:=PhysicsRayQueryParameters3D.create(town.player.global_position+Vector3.UP*1.4,object.global_position+Vector3.UP*.6,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=object:continue
		nearest=object;distance=d
	if not nearest:return {}
	return {"kind":"physical","verb":"Activities","label":String(nearest.species) if nearest.is_in_group("animals") else String(nearest.name),"object":nearest}

func option(title: String,callback: Callable) -> void:
	var button:=Button.new();button.text=title;button.custom_minimum_size.y=48;choices.add_child(button)
	button.pressed.connect(func():panel.hide();callback.call())

func interact(data: Dictionary) -> void:
	if busy>0:return
	if carried:place();return
	if mounted:dismount();return
	if pushing:pushing=false;return
	var object: Node3D=data.object
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	if town.cooking and town.cooking.near_garden():
		option("Plant vegetables",func():town.cooking.plant())
		option("Water growing crops",func():
			if town.cooking.crop_state=="growing" and not town.cooking.garden.get_meta("watered",false):
				town.cooking.growth_ready=maxf(town.cooking.clock+1,town.cooking.growth_ready-8);town.cooking.garden.set_meta("watered",true);town.cooking.save_state())
		option("Harvest vegetables",func():
			if town.cooking.harvest():town.cooking.garden.remove_meta("watered"))
	if object.is_in_group("animals"):
		option("Feed · uses one vegetable",func():
			if town.economy.player_food<1:town.economy.announce("Buy vegetables at the market first.");return
			town.economy.player_food-=1;town.economy.refresh();town.economy.announce("You fed the "+object.species.to_lower()+"."))
		option("Pet",func():gesture=1.2;town.character_life.feel("You","Happy",20);town.economy.announce("You gently pet the "+object.species.to_lower()+".");if town.player.animator.has_animation("WorkHarvest"):town.player.animator.play("WorkHarvest"))
		option("Lead / stop leading",func():leading=null if leading==object else object)
		if object.species=="Horse":option("Ride",func():mounted=object;object.set_physics_process(false);town.player.add_collision_exception_with(object);object.add_collision_exception_with(town.player);town.player.global_position=object.global_position)
	else:
		match String(object.get_meta("activity")):
			"carry":
				option("Pick up",func():
					if object.has_meta("seat") and object.get_meta("seat").has_meta("occupant"):return
					carried=object;carried.set_meta("pickup_position",carried.global_position);carried.collision_layer=0;carried.reparent(town.player);carried.position=Vector3(0,1,-.8))
				if object.has_meta("seat"):option("Sit on stool",func():town.player.use_furniture(object.get_meta("seat"),"sitting"))
			"chop","repair","furniture_repair":option("Use tool · 4 seconds",func():start_work(object))
			"cart":
				option("Push cart",func():pushing=true)
				option("Load vegetables · 1 portion",func():
					if town.economy.player_food>0:town.economy.player_food-=1;cart.set_meta("cargo",int(cart.get_meta("cargo",0))+1);update_cargo();town.economy.refresh())
				option("Unload vegetables",func():town.economy.player_food+=int(cart.get_meta("cargo",0));cart.set_meta("cargo",0);update_cargo();town.economy.refresh())
			"training","target":
				option("Shoot arrow · aim with your view",shoot)
				option("Practise shield block",func():start_work(object))
			"cupboard":
				option("Open / close cupboard",func():var lid: Node3D=object.get_meta("lid");lid.rotation.x=0 if absf(lid.rotation.x)>.1 else -1.2)
				option("Store or take belongings",town.player_home.show_home)
			"lamp":option("Light / extinguish",func():var light: OmniLight3D=object.get_meta("light");light.visible=not light.visible)
			"ladder":option("Climb to loft / return",func():
				var destination: Vector3=town.home_district.room_origin+Vector3(5.5,2.72,.3) if town.player.position.y< -78 else town.home_district.room_origin+Vector3(4.8,.12,1)
				if town.home_district.clear_capsule(destination):town.player.position=destination;town.player.velocity=Vector3.ZERO)
	option("Crouch / stand",func():toggle_crouch())
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;panel.popup_centered()

func update_cargo() -> void:
	var old:=cart.get_node_or_null("Cargo")
	if old:cart.remove_child(old);old.queue_free()
	var cargo:=Node3D.new();cargo.name="Cargo";cart.add_child(cargo)
	for index in range(mini(6,int(cart.get_meta("cargo",0)))):town.detailed_prop("Crate_Wooden",cargo,Vector3((index%2-.5)*.5,.7,(index/2-1)*.45),Vector3(.45,.4,.4),false)
	save_layout()

func place() -> void:
	var origin: Vector3=town.player.global_position-town.player.global_basis.z*1.7
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP*2,origin-Vector3.UP*2,1))
	if hit.is_empty():return
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.65,.65,.65);query.shape=shape;query.transform.origin=hit.position+Vector3.UP*.36;query.collision_mask=1
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
	carried.reparent(self);carried.global_position=hit.position+Vector3.UP*.03;carried.collision_layer=1
	if carried.has_meta("vegetables") and carried.global_position.distance_to(Vector3(8,0,4))<5:
		town.jobs.markets.city.stock+=int(carried.get_meta("vegetables"));carried.remove_meta("vegetables");town.economy.award_story("physical_delivery",8);town.economy.refresh();town.economy.announce("Delivery received · 8 coins.")
	carried=null;save_layout()

func start_work(object: Node3D) -> void:
	if int(object.get_meta("stock",0))<=0:town.economy.announce("This station's work is finished.");return
	busy=4;work=object
	tool=Node3D.new();town.player.add_child(tool);tool.position=Vector3(.4,1,-.8)
	var kind: String=String(object.get_meta("activity"))
	if kind=="chop":town.detailed_prop("Axe_Bronze",tool,Vector3.ZERO,Vector3(.25,.65,.2),false)
	elif kind in ["training","target"]:town.detailed_prop("Shield_Wooden",tool,Vector3.ZERO,Vector3(.6,.7,.12),false)
	else:
		town.box(tool,Vector3(.06,.5,.06),Vector3.ZERO,Color("795834"),false)
		town.box(tool,Vector3(.3,.12,.12),Vector3(0,.25,0),Color("878787"),false)
	if town.player.animator.has_animation("WorkTable"):town.player.animator.play("WorkTable")

func shoot() -> void:
	var camera: Camera3D=town.player.camera if town.view_mode==0 else town.player.third_camera
	var bolt: MeshInstance3D=town.box(self,Vector3(.025,.025,.65),camera.global_position-camera.global_basis.z*.6,Color("d4b589"),false)
	bolt.global_basis=camera.global_basis;bolts.append({"node":bolt,"velocity":-camera.global_basis.z*24,"life":3.0})

func dismount() -> void:
	if not mounted:return
	var destination: Vector3=town.player.global_position+town.player.global_basis.x*1.5
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
	query.shape=shape;query.transform.origin=destination+Vector3.UP*.9;query.collision_mask=1;query.exclude=[town.player.get_rid(),mounted.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
	town.player.global_position=destination;town.player.remove_collision_exception_with(mounted);mounted.remove_collision_exception_with(town.player);mounted.set_physics_process(true);mounted=null

func _physics_process(delta: float) -> void:
	if not town.player or not town.character_life or not town.character_life.bound:return
	elapsed+=delta
	gesture=maxf(0,gesture-delta)
	var sprinting: bool=town.player.velocity.length()>4 and town.player.enabled
	stamina=clampf(stamina+(-16 if sprinting else 10)*delta,0,100)
	if busy>0:
		busy-=delta
		if tool:tool.rotation.x=sin(busy*8)*.7
		if busy<=0:
			impact(work.global_position)
			if tool:tool.queue_free();tool=null
			work.set_meta("stock",int(work.get_meta("stock"))-1)
			save_layout()
			var item: String="Timber" if work.get_meta("activity")=="chop" else "Wagon fittings" if work.get_meta("activity")=="repair" else "Repaired furniture" if work.get_meta("activity")=="furniture_repair" else "Training practice"
			if item=="Repaired furniture":
				for child in work.get_children():
					if child is Node3D and not child is CollisionShape3D:child.rotation.z=0
			if item!="Training practice":town.adventures.inventory[item]=int(town.adventures.inventory.get(item,0))+1;town.adventures.save_state()
			if item!="Training practice":town.box(work,Vector3(.5,.1,.15),Vector3(.6,.1+int(work.get_meta("stock"))*.12,0),Color("b38d5c"),false)
			town.character_life.gain_skill("You","Carpentry" if item!="Training practice" else "Archery",8)
			town.economy.announce("Completed · "+item)
	if pushing:
		var goal: Vector3=town.player.global_position-town.player.global_basis.z*1.6
		var offset:=goal-cart.global_position;offset.y=0
		if offset.length()>3:pushing=false
		else:cart.velocity=offset.limit_length(1)*2.5+Vector3.DOWN*2;cart.move_and_slide();cart.rotation.y=town.player.rotation.y
	if leading and elapsed>2:
		elapsed=0
		if leading.global_position.distance_to(town.player.global_position)<12:leading.route_to(town.player.global_position+town.player.global_basis.z*2)
	if mounted:
		if mounted.test_move(mounted.global_transform,town.player.global_position-mounted.global_position):dismount()
		else:mounted.global_position=town.player.global_position;mounted.rotation.y=town.player.rotation.y
	for index in range(bolts.size()-1,-1,-1):
		var bolt: Dictionary=bolts[index];var from: Vector3=bolt.node.global_position;var to: Vector3=from+bolt.velocity*delta
		var query:=PhysicsRayQueryParameters3D.create(from,to,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		bolt.life-=delta;bolt.node.global_position=to
		if not hit.is_empty() or bolt.life<=0:
			if not hit.is_empty() and hit.collider.has_meta("archery_target"):score+=1;town.character_life.gain_skill("You","Archery",4);town.economy.announce("Target hit · score "+str(score))
			bolt.node.queue_free();bolts.remove_at(index)
	status.text="Stamina %d · %s"%[int(stamina),"Carrying "+String(carried.name) if carried else "Pushing cart" if pushing else "Riding" if mounted else "Crouching" if crouching else ""]

func save_layout() -> void:
	if town.economy.has_method("testing") and town.economy.testing():return
	var saved: Dictionary={}
	for object in objects:
		var point: Vector3=object.get_meta("pickup_position",object.global_position) if object==carried else object.global_position
		saved[String(object.name)]={"position":[point.x,point.y,point.z],"rotation":object.global_rotation.y,"stock":object.get_meta("stock",3),"cargo":object.get_meta("cargo",0),"vegetables":object.get_meta("vegetables",0)}
	var file:=FileAccess.open("user://physical-objects.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(saved))

func load_layout() -> void:
	if town.economy.has_method("testing") and town.economy.testing():return
	if not FileAccess.file_exists("user://physical-objects.json"):return
	var saved=JSON.parse_string(FileAccess.get_file_as_string("user://physical-objects.json"))
	if not saved is Dictionary:return
	for object in objects:
		var data=saved.get(String(object.name),{})
		var point=data.get("position",[])
		if not point is Array or point.size()!=3:continue
		object.global_position=Vector3(float(point[0]),float(point[1]),float(point[2]));object.global_rotation.y=float(data.get("rotation",0))
		object.set_meta("stock",int(data.get("stock",3)))
		if object.has_meta("vegetables"):object.set_meta("vegetables",int(data.get("vegetables",0)))
		if object==cart:cart.set_meta("cargo",int(data.get("cargo",0)))

func impact(point: Vector3) -> void:
	var audio:=AudioStreamPlayer3D.new();add_child(audio);audio.global_position=point;audio.volume_db=-20;audio.max_distance=18
	var sound:=AudioStreamWAV.new();sound.format=AudioStreamWAV.FORMAT_8_BITS;sound.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(2205)
	for index in range(bytes.size()):bytes[index]=int(128+sin(index*.22)*55*exp(-float(index)/350))
	sound.data=bytes;audio.stream=sound;audio.finished.connect(audio.queue_free);audio.play()


func toggle_crouch() -> void:
	for child in town.player.get_children():
		if not child is CollisionShape3D or not child.shape is CapsuleShape3D:continue
		if crouching:
			var query:=PhysicsShapeQueryParameters3D.new()
			var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
			query.shape=shape;query.transform.origin=town.player.global_position+Vector3.UP*.9;query.collision_mask=1;query.exclude=[town.player.get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
		crouching=not crouching
		child.shape.height=1.2 if crouching else 1.8
		child.position.y=child.shape.height/2
		return

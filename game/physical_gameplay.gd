extends Node3D

const SPRINT_DRAIN := 5.5
const WINDED_AT := 8.0
const SPRINT_RECOVERY := 30.0

var town: Node3D
var objects: Array[Node3D]=[]
var carried: Node3D
var cart: CharacterBody3D
var pushing:=false
var leading: CharacterBody3D
var mounted: CharacterBody3D
var stamina:=100.0
var winded := false
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
var arrow_release:=-1.0
var bow: Node3D
var climbing:=false
var climb_goal:=Vector3.ZERO
var climb_stuck:=0.0
var climb_previous:=Vector3.ZERO
var object_action:=preload("res://prop_action.gd").new()
var action_object: Node3D
var action_recipient: CharacterBody3D
var action_player: Node3D
var action_destination:=Vector3.INF
var grip_start:=Vector3.ZERO
var player_hand_error:=0.0
var player_carry_pose_updates:=0
var player_grip: SkeletonModifier3D
var inventory_parcel: Node3D

func holding_payload() -> Node3D:
	return carried if is_instance_valid(carried) else inventory_parcel

func animate_inventory_handover(person: CharacterBody3D,item: String,commit: Callable) -> bool:
	if object_action.active or crafting_busy() or carried or busy>0 or climbing or item.is_empty() or not commit.is_valid():return false
	if not inventory_recipient_valid(person):return false
	inventory_parcel=Node3D.new();town.player.add_child(inventory_parcel);inventory_parcel.name="MissionParcel"
	town.detailed_prop("Crate_Wooden",inventory_parcel,Vector3.ZERO,Vector3(.38,.24,.28),false)
	action_object=inventory_parcel;action_player=town.player;action_recipient=person
	var started:=object_action.begin(town.player.animator,"handover",func():
		if crafting_busy() or not inventory_recipient_valid(person) or not commit.is_valid():return false
		if commit.call()!=true:return false
		if is_instance_valid(inventory_parcel):inventory_parcel.hide()
		return true,finish_object_action)
	if not started:inventory_parcel.queue_free();inventory_parcel=null;return false
	gesture=object_action.duration+.1;ensure_player_grip();update_carried_transform()
	if person.has_method("begin_prop_gesture"):person.begin_prop_gesture()
	return true

func inventory_recipient_valid(person: CharacterBody3D) -> bool:
	if not is_instance_valid(person) or person.posture=="sleeping" or person.global_position.distance_to(town.player.global_position)>2.5:return false
	var life: Node=town.get("life")
	if not is_instance_valid(life) or life.get("active")!=person:return false
	var dialog: Control=life.get("dialog")
	if not is_instance_valid(dialog) or not dialog.is_visible_in_tree():return false
	return clear_exchange_path(person)

func crafting_busy() -> bool:
	var crafting: Node=town.get("crafting")
	return is_instance_valid(crafting) and not crafting.job.is_empty()

func object_id(object: Node3D) -> String:
	if not is_instance_valid(object):return ""
	if not object.has_meta("physical_id"):object.set_meta("physical_id","physical/"+String(object.name).to_snake_case())
	return String(object.get_meta("physical_id"))

func find_object(id: String) -> Node3D:
	for object in objects:
		if is_instance_valid(object) and object_id(object)==id:return object
	return null

func clear_holder(object: Node3D) -> void:
	if not is_instance_valid(object):return
	if object.has_meta("held_by"):
		var previous:=object.get_parent()
		if is_instance_valid(previous) and previous.get("received_object")==object:previous.received_object=null
		object.remove_meta("held_by")
	object.show()

func restore_held_by(object: Node3D,person_name: String) -> bool:
	if not is_instance_valid(object) or not objects.has(object) or object.get_meta("activity","")!="carry":return false
	for person in get_tree().get_nodes_in_group("villagers"):
		if person.person_name!=person_name:continue
		if is_instance_valid(person.received_object) and person.received_object!=object:return false
		cancel_object_action();clear_holder(object)
		if carried==object:carried=null
		if object.get_parent()!=person:object.reparent(person)
		object.collision_layer=0;object.set_meta("held_by",person_name);person.received_object=object;person.ensure_carry_modifier()
		return true
	return false

func ensure_player_grip() -> void:
	var model: Node3D=town.player.get("avatar")
	if not is_instance_valid(model):return
	if is_instance_valid(player_grip) and player_grip.model==model:return
	var rigs:=model.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty():return
	player_grip=rigs[0].get_node_or_null("PhysicalCarryHands")
	if not player_grip:
		player_grip=preload("res://carry_pose.gd").new();player_grip.name="PhysicalCarryHands";rigs[0].add_child(player_grip)
	player_grip.carrier=town.player;player_grip.model=model;player_grip.physical=self

func restore_carried(object: Node3D=null) -> bool:
	cancel_object_action()
	if object and (not objects.has(object) or object.get_meta("activity","")!="carry"):return false
	if is_instance_valid(object) and carried==object:return true
	if is_instance_valid(carried) and carried!=object:
		var old:=carried;old.reparent(self);old.global_position=old.get_meta("pickup_position",old.global_position);old.collision_layer=int(old.get_meta("pickup_collision_layer",1));carried=null
	if not object:return true
	clear_holder(object)
	object.set_meta("pickup_position",object.global_position)
	object.set_meta("pickup_collision_layer",object.collision_layer if object.collision_layer!=0 else 1)
	object.collision_layer=0
	if object.get_parent()!=town.player:object.reparent(town.player)
	object.show()
	carried=object;ensure_player_grip();update_carried_transform()
	return true

func cancel_object_action() -> void:
	object_action.cancel();gesture=0
	action_object=null;action_recipient=null
	if is_instance_valid(carried):update_carried_transform()

func finish_object_action() -> void:
	gesture=0
	if is_instance_valid(inventory_parcel):inventory_parcel.queue_free();inventory_parcel=null
	if is_instance_valid(action_player) and is_instance_valid(action_player.get("animator")):
		var animator: AnimationPlayer=action_player.animator
		var idle: String="PlayerIdle" if animator.has_animation("PlayerIdle") else "Idle"
		if animator.has_animation(idle):animator.speed_scale=1;animator.play(idle,.18)
	if is_instance_valid(carried):update_carried_transform()

func hand_grip_weight() -> float:
	if not object_action.active:return 1
	if object_action.kind=="handover":return clampf(1-object_action.ratio()/object_action.contact,0,1)
	return 1

func update_carried_transform() -> void:
	var payload:=holding_payload()
	if not is_instance_valid(payload):return
	var model: Node3D=town.player.get("avatar")
	var hold: Vector3=town.player.to_local(model.to_global(Vector3(0,.96,.4))) if is_instance_valid(model) else Vector3(0,1,-.8)
	if object_action.active and object_action.kind=="pickup":hold=grip_start.lerp(hold,clampf((object_action.ratio()-object_action.contact)/(1-object_action.contact),0,1))
	elif object_action.active and object_action.kind=="place" and action_destination.is_finite():hold=hold.lerp(town.player.to_local(action_destination),clampf(object_action.ratio()/object_action.contact,0,1))
	payload.position=hold
	if is_instance_valid(model):payload.global_basis=model.global_basis.orthonormalized()

func pickup(object: Node3D) -> bool:
	if object_action.active or carried or busy>0 or climbing or crafting_busy() or not valid_pickup(object):return false
	action_object=object;action_player=town.player;action_recipient=null
	if not object_action.begin(town.player.animator,"pickup",func():
		if not valid_pickup(object) or carried:return false
		object.set_meta("pickup_position",object.global_position);object.set_meta("pickup_collision_layer",object.collision_layer if object.collision_layer!=0 else int(object.get_meta("pickup_collision_layer",1)))
		if crafting_busy():return false
		clear_holder(object);object.show();object.collision_layer=0;object.reparent(town.player);carried=object;grip_start=object.position;ensure_player_grip();save_layout();return true,finish_object_action):return false
	gesture=object_action.duration+.1
	return true

func valid_pickup(object: Node3D) -> bool:
	if not is_instance_valid(object) or not objects.has(object) or object.get_meta("activity","")!="carry":return false
	if object.has_meta("seat") and object.get_meta("seat").has_meta("occupant"):return false
	if object.global_position.distance_to(town.player.global_position)>2.6:return false
	var ray:=PhysicsRayQueryParameters3D.create(town.player.global_position+Vector3.UP*1.4,object.global_position+Vector3.UP*.3,1)
	ray.exclude=[town.player.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==object

func handover_target() -> CharacterBody3D:
	var best: CharacterBody3D;var distance:=2.5
	for person in get_tree().get_nodes_in_group("villagers"):
		if not can_receive(person):continue
		var gap: float=person.global_position.distance_to(town.player.global_position)
		if gap<distance:distance=gap;best=person
	return best

func can_receive(person: CharacterBody3D) -> bool:
	if not is_instance_valid(person) or person.posture!="standing" or person.night_schedule or person.talking or not person.carry_kind.is_empty() or is_instance_valid(person.received_object):return false
	if person.has_method("prop_action_busy") and person.prop_action_busy():return false
	if person.global_position.distance_to(town.player.global_position)>2.5:return false
	return clear_exchange_path(person)

func clear_exchange_path(person: CharacterBody3D) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(town.player.global_position+Vector3.UP*1.2,person.global_position+Vector3.UP*1.2,1)
	ray.exclude=[town.player.get_rid(),person.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func hand_over(person: CharacterBody3D) -> bool:
	if object_action.active or crafting_busy() or not is_instance_valid(carried) or not can_receive(person):return false
	var object:=carried;action_object=object;action_player=town.player;action_recipient=person
	var started:=object_action.begin(town.player.animator,"handover",func():
		# The receiver's acknowledgement is allowed, other changes invalidate it.
		if crafting_busy() or not is_instance_valid(person) or not is_instance_valid(object) or carried!=object or person.night_schedule or person.talking or person.posture!="standing" or not person.carry_kind.is_empty() or is_instance_valid(person.received_object):return false
		if person.global_position.distance_to(town.player.global_position)>2.5:return false
		if not clear_exchange_path(person):return false
		clear_holder(object);object.reparent(person);object.collision_layer=0;object.set_meta("held_by",person.person_name);person.received_object=object;person.ensure_carry_modifier();carried=null;save_layout();return true,finish_object_action)
	if started:
		gesture=object_action.duration+.1
		if person.has_method("begin_prop_gesture"):person.begin_prop_gesture()
	return started

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
	object_id(object)
	return object

func setup() -> void:
	while not town.home_district.ready_for_spawn:await get_tree().process_frame
	prop("Vegetable delivery crate","Crate_Wooden",Vector3(-32,.03,37),"carry").set_meta("vegetables",4)
	prop("Timber chopping block","Barrel",Vector3(-27,.03,39),"chop")
	prop("Repair workbench","Workbench_Drawers",Vector3(-24,.03,39),"repair")
	prop("Training dummy","WeaponStand",Vector3(20,.03,38),"training")
	for index in range(3):
		var target_node:=prop("Archery target "+str(index+1),"Barrel",Vector3(52+index*3,.03,51),"target")
		target_node.set_meta("archery_target",true)
	var home: Node3D=town.home_district.interior
	var stool:=prop("Movable home stool","Stool",home.to_global(Vector3(3.5,0,-1)),"carry")
	var seat:=Marker3D.new();stool.add_child(seat);seat.position.y=.52;seat.add_to_group("seats");stool.set_meta("seat",seat)
	var chest:=prop("Home cupboard","Chest_Wood",home.to_global(Vector3(4.5,0,-1)),"cupboard")
	var lid: MeshInstance3D=town.box(chest,Vector3(.65,.07,.65),Vector3(0,.65,0),Color("775437"),false)
	chest.set_meta("lid",lid)
	var lamp:=prop("Home lamp","Mug",home.to_global(Vector3(4.5,0,-2)),"lamp")
	var light:=OmniLight3D.new();lamp.add_child(light);light.position.y=1.0;light.omni_range=6;light.light_color=Color("ffd492");light.light_energy=1.2;lamp.set_meta("light",light);lamps.append(light)
	var ladder:=prop("Loft ladder","",home.to_global(Vector3(6.7,0,4.55)),"ladder")
	ladder.collision_layer=0
	var ladder_visual:=Node3D.new();ladder.add_child(ladder_visual);ladder_visual.rotation.x=-atan2(4.2,2.59)
	for x in [-.3,.3]:town.box(ladder_visual,Vector3(.08,4.95,.08),Vector3(x,2.475,0),Color("82603d"),false)
	for rung in range(16):town.box(ladder_visual,Vector3(.65,.06,.08),Vector3(0,.2+rung*.3,0),Color("a57a4d"),false)
	var top:=Marker3D.new();add_child(top);top.name="Loft ladder top";top.position=home.to_global(Vector3(6.7,2.72,.3));top.set_meta("activity","ladder");objects.append(top)
	cart=CharacterBody3D.new();cart.name="Supply cart";add_child(cart);cart.position=Vector3(-29,.1,34)
	town.box(cart,Vector3(1.2,.2,1.6),Vector3(0,.6,0),Color("785636"),false)
	for x in [-.7,.7]:
		for z in [-.55,.55]:
			var wheel:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.3;mesh.bottom_radius=.3;mesh.height=.12;wheel.mesh=mesh;wheel.rotation.z=PI/2;wheel.position=Vector3(x,.3,z);cart.add_child(wheel)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.35,1,1.7);collider.shape=shape;collider.position.y=.5;cart.add_child(collider)
	cart.set_meta("activity","cart");objects.append(cart)
	for object in objects:object_id(object)
	load_layout()
	update_cargo()
	town.add_sign("TOOLS & DELIVERIES",Vector3(-28,2.2,39),0,22)
	town.add_sign("TRAINING GROUND",Vector3(30,2.2,37),0,22)

func target() -> Dictionary:
	if object_action.active:return {"kind":"physical","verb":"Handling","label":"Handling "+String(action_object.name) if is_instance_valid(action_object) else "Handling an item","object":self}
	if climbing:return {"kind":"physical","verb":"Climbing","label":"Climbing the ladder","object":self}
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
	if busy>0 or climbing or object_action.active:return
	if carried:
		var recipient:=handover_target()
		if not recipient:place();return
		for child in choices.get_children():choices.remove_child(child);child.queue_free()
		option("Place on ground",place)
		option("Hand to "+recipient.person_name,func():hand_over(recipient))
		show_choices();return
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
				option("Pick up",func():pickup(object))
				if object.has_meta("seat"):option("Sit on stool",func():town.player.use_furniture(object.get_meta("seat"),"sitting"))
			"chop","repair","furniture_repair":
				var activity := String(object.get_meta("activity"))
				var action := "Chop timber" if activity == "chop" else "Use tool"
				option("%s · %s seconds" % [action, str(work_seconds(activity))],func():start_work(object))
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
			"ladder":option("Climb ladder",begin_climb)
	option("Crouch / stand",func():toggle_crouch())
	show_choices()

func show_choices() -> void:
	previous_enabled=town.player.enabled;previous_mouse=Input.mouse_mode;town.player.enabled=false;town.player.velocity=Vector3.ZERO;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;panel.popup_centered()

func update_cargo() -> void:
	var old:=cart.get_node_or_null("Cargo")
	if old:cart.remove_child(old);old.queue_free()
	var cargo:=Node3D.new();cargo.name="Cargo";cart.add_child(cargo)
	for index in range(mini(6,int(cart.get_meta("cargo",0)))):town.detailed_prop("Crate_Wooden",cargo,Vector3((index%2-.5)*.5,.7,(index/2-1)*.45),Vector3(.45,.4,.4),false)
	save_layout()

func place() -> void:
	if object_action.active or crafting_busy() or not is_instance_valid(carried):return
	var destination:=place_destination()
	if not destination.is_finite():
		town.economy.announce("Move to clear ground before putting the item down.")
		return
	var object:=carried;action_object=object;action_player=town.player;action_destination=destination;action_recipient=null
	if object_action.begin(town.player.animator,"place",func():
		if crafting_busy() or not is_instance_valid(object) or carried!=object:return false
		var point:=place_destination()
		if not point.is_finite() or point.distance_to(destination)>.4:
			town.economy.announce("The spot is blocked. You still have the item.")
			return false
		commit_place(object,point);return true,finish_object_action):gesture=object_action.duration+.1

func place_destination() -> Vector3:
	var origin: Vector3=town.player.global_position-town.player.global_basis.z*.95
	var ray:=PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.65,origin-Vector3.UP*.75,1)
	ray.exclude=[town.player.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():return Vector3.INF
	if hit.normal.y<.65:return Vector3.INF
	var reach:=PhysicsRayQueryParameters3D.create(town.player.global_position+Vector3.UP*.55,hit.position+Vector3.UP*.35,1)
	reach.exclude=[town.player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(reach).is_empty():return Vector3.INF
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.65,.65,.65);query.shape=shape;query.transform.origin=hit.position+Vector3.UP*.36;query.collision_mask=7
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return Vector3.INF
	return hit.position+Vector3.UP*.03

func commit_place(object: Node3D,point: Vector3) -> void:
	object.reparent(self);object.global_position=point;object.collision_layer=int(object.get_meta("pickup_collision_layer",1));clear_holder(object)
	var portions := int(object.get_meta("vegetables",0))
	if portions > 0 and point.distance_to(Vector3(8,0,4)) < 5:
		object.remove_meta("vegetables")
		if town.economy.award_story("physical_delivery",8):
			var market: Dictionary = town.jobs.markets.city
			market.stock += portions
			market.received = int(market.get("received",0)) + portions
			town.jobs.update_market("city")
			town.economy.announce("Delivery received · 8 coins.")
	carried=null;save_layout()

func work_seconds(activity: String) -> float:
	return 2.5 if activity == "chop" and is_instance_valid(town.inventory_ui) and town.inventory_ui.amount("Work axe") > 0 else 4.0

func start_work(object: Node3D) -> void:
	if object_action.active or carried:return
	if int(object.get_meta("stock",0))<=0:town.economy.announce("This station's work is finished.");return
	var kind: String=String(object.get_meta("activity"))
	busy=work_seconds(kind);work=object
	tool=Node3D.new();town.player.add_child(tool);tool.position=Vector3(.4,1,-.8)
	if kind=="chop":town.detailed_prop("Axe_Bronze",tool,Vector3.ZERO,Vector3(.25,.65,.2),false)
	elif kind in ["training","target"]:town.detailed_prop("Shield_Wooden",tool,Vector3.ZERO,Vector3(.6,.7,.12),false)
	else:
		town.box(tool,Vector3(.06,.5,.06),Vector3.ZERO,Color("795834"),false)
		town.box(tool,Vector3(.3,.12,.12),Vector3(0,.25,0),Color("878787"),false)
	var clip: String="RunnerWorking" if kind in ["repair","furniture_repair"] else "WorkTable"
	if kind in ["training","target"] and town.player.animator.has_animation("ShieldIdle"):clip="ShieldIdle"
	if not town.player.animator.has_animation(clip):clip="WorkTable"
	if town.player.animator.has_animation(clip):town.player.animator.play(clip)

func shoot() -> void:
	if arrow_release>=0 or busy>0 or climbing or object_action.active:return
	show_bow()
	if town.player.animator.has_animation("DrawArrow"):
		var length: float=town.player.animator.get_animation("DrawArrow").length
		arrow_release=minf(4.0,length)
		town.player.animator.play("DrawArrow",.1,length/maxf(.01,arrow_release))
		gesture=arrow_release+.25
	else:release_arrow()

func release_arrow() -> void:
	var camera: Camera3D=town.player.camera if town.view_mode==0 else town.player.third_camera
	var bolt: MeshInstance3D=town.box(self,Vector3(.025,.025,.65),camera.global_position-camera.global_basis.z*.6,Color("d4b589"),false)
	bolt.global_basis=camera.global_basis;bolts.append({"node":bolt,"velocity":-camera.global_basis.z*24,"life":3.0})
	if is_instance_valid(bow):bow.hide()

func show_bow() -> void:
	if not is_instance_valid(bow):
		bow=Node3D.new();town.player.add_child(bow)
		var points: Array[Vector3]=[Vector3(0,-.55,.18),Vector3(0,-.3,.05),Vector3.ZERO,Vector3(0,.3,.05),Vector3(0,.55,.18)]
		for index in range(points.size()-1):
			var a: Vector3=points[index];var b: Vector3=points[index+1]
			var piece:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.02;mesh.bottom_radius=.02;mesh.height=a.distance_to(b);mesh.radial_segments=8;piece.mesh=mesh;bow.add_child(piece)
			piece.position=(a+b)/2;piece.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
			var wood:=StandardMaterial3D.new();wood.albedo_color=Color("8b6342");piece.material_override=wood
		town.box(bow,Vector3(.008,1.1,.008),Vector3(0,0,.18),Color("d0c4a4"),false)
	bow.show()

func dismount() -> void:
	if not mounted:return
	var destination: Vector3=town.player.global_position+town.player.global_basis.x*1.5
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
	query.shape=shape;query.transform.origin=destination+Vector3.UP*.9;query.collision_mask=1;query.exclude=[town.player.get_rid(),mounted.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
	town.player.global_position=destination;town.player.remove_collision_exception_with(mounted);mounted.remove_collision_exception_with(town.player);mounted.set_physics_process(true);mounted=null

func _physics_process(delta: float) -> void:
	if not town.player or not town.character_life or not town.character_life.bound:return
	if object_action.active:
		var allowed: bool=inventory_recipient_valid(action_recipient) if is_instance_valid(inventory_parcel) else town.player.enabled
		if town.player!=action_player or town.player.animator!=object_action.animator or not allowed or not is_instance_valid(action_object) or not String(town.player.get("resting")).is_empty():cancel_object_action()
		else:
			object_action.tick(delta)
			if object_action.active:gesture=maxf(gesture,object_action.duration-object_action.elapsed+.05)
	if is_instance_valid(holding_payload()):ensure_player_grip();update_carried_transform()
	for object in objects:
		if not is_instance_valid(object) or not object.has_meta("held_by"):continue
		var holder:=object.get_parent()
		if holder is CharacterBody3D and is_instance_valid(holder.get("visual")):
			object.global_transform=holder.visual.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,.96,.4))
			object.visible=holder.posture=="standing" and holder.carry_kind.is_empty()
	elapsed+=delta
	gesture=maxf(0,gesture-delta)
	if arrow_release>=0:
		if not town.player.enabled:
			arrow_release=-1;gesture=0
			if is_instance_valid(bow):bow.hide()
		else:
			if is_instance_valid(bow):
				if town.view_mode==0:bow.global_transform=town.player.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(.32,-.25,-.8))
				else:
					var rig: Skeleton3D=town.player.avatar.find_children("*","Skeleton3D",true,false)[0]
					var hand:=rig.find_bone("Wrist.L")
					if hand>=0:bow.global_transform=rig.global_transform*rig.get_bone_global_pose(hand)
			arrow_release-=delta
			if arrow_release<=0:arrow_release=-1;release_arrow()
	update_stamina(delta)
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
			if item!="Training practice":show_work_result(work)
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
	var activity := "Carrying "+String(carried.name) if carried else "Pushing cart" if pushing else "Riding" if mounted else "Crouching" if crouching else ""
	status.text = "Stamina %d" % int(stamina)
	if winded:status.text += " · Catching your breath"
	if not activity.is_empty():status.text += " · " + activity

func update_stamina(delta: float) -> void:
	var player: CharacterBody3D = town.player
	if not player.enabled or climbing:return
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var recovery := 18.0 if not player.resting.is_empty() else 12.0 if horizontal_speed < .25 else 7.0
	stamina = clampf(stamina + (-SPRINT_DRAIN if player.sprinting else recovery) * delta, 0.0, 100.0)
	if winded:winded = stamina < SPRINT_RECOVERY
	else:winded = stamina <= WINDED_AT

func show_work_result(station: Node3D) -> void:
	# Repeat orders must not leave another mesh behind on every completed cut.
	var results: Array[Node3D]=[]
	for child in station.get_children():
		if child is Node3D and child.get_meta("work_result_visual",false):results.append(child)
	if results.size()<3:
		var result: MeshInstance3D=town.box(station,Vector3(.5,.1,.15),Vector3(.6,.1+results.size()*.12,0),Color("b38d5c"),false)
		result.set_meta("work_result_visual",true)
	else:
		var slot:=int(station.get_meta("work_result_turn",0))%3
		results[slot].rotation=Vector3.ZERO
		station.set_meta("work_result_turn",slot+1)

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


func begin_climb() -> void:
	if mounted or carried or pushing or crouching or stamina<15:
		town.economy.announce("Free your hands, stand up, and recover stamina to climb.");return
	climb_goal=town.home_district.room_origin+(Vector3(6.7,2.72,.3) if town.player.position.y< -78 else Vector3(6.7,.12,4.55))
	if not town.home_district.clear_capsule(climb_goal):
		town.economy.announce("The ladder landing is blocked.");return
	climbing=true;climb_stuck=0;climb_previous=town.player.global_position

func move_climber(delta: float) -> void:
	var offset: Vector3=climb_goal-town.player.global_position
	if offset.length()<.2:
		climbing=false;town.player.velocity=Vector3.ZERO;return
	if stamina<1:
		climbing=false;return
	town.player.velocity=offset.normalized()*1.8
	town.player.move_with_steps(delta)
	stamina=maxf(0,stamina-delta*5)
	if town.player.global_position.distance_to(climb_previous)<.004:climb_stuck+=delta
	else:climb_stuck=0
	climb_previous=town.player.global_position
	if climb_stuck>1:
		climbing=false;town.economy.announce("The ladder is obstructed. Clear the way and try again.")

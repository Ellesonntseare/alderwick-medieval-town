extends Node3D

var town: Node3D
var exterior: Node3D
var interior: Node3D
var inside:=false
var porch:=Vector3(-85,.08,-71)
var room_origin:=Vector3(0,-80,0)
var spawn:=Vector3(2.6,-79.9,3.8)
var exit_point:=Vector3(2.6,-79.95,5.4)
var prompt: Label
var ready_for_spawn:=false
var seats: Array[Marker3D]=[]
var bed: Marker3D
var cooking_anchor: Marker3D
var visitors: Dictionary={}
var transferred_at:=0

func _ready() -> void:
	town=get_parent()
	name="PlayerHomeDistrict"
	exterior=Node3D.new();exterior.name="Your potter's house"
	exterior.set_meta("player_owned",true);exterior.set_meta("family_excluded",true)
	add_child(exterior);exterior.position=Vector3(-85,0,-80)
	exterior.add_to_group("enterable_houses")
	var shell: Node3D=load("res://downloaded/player-home/exterior.glb").instantiate();exterior.add_child(shell)
	town.collisions(shell)
	interior=Node3D.new();interior.name="Your spacious interior"
	interior.set_meta("player_owned",true);interior.set_meta("family_excluded",true)
	add_child(interior);interior.position=room_origin
	interior.add_to_group("enterable_houses")
	var room: Node3D=load("res://downloaded/player-home/interior.glb").instantiate();interior.add_child(room)
	town.collisions(room,true)
	# Back the supplied single-sided floor without replacing its appearance.
	town.box(interior,Vector3(11.2,.15,12.3),Vector3(2.25,-.09,0),Color("6d655a"),true)
	for spec in [[Vector3(11.2,5,.2),Vector3(2.25,2.5,-6.15)],[Vector3(11.2,5,.2),Vector3(2.25,2.5,6.15)],[Vector3(.2,5,12.3),Vector3(-3.35,2.5,0)],[Vector3(.2,5,12.3),Vector3(7.85,2.5,0)]]:
		var guard:=StaticBody3D.new();interior.add_child(guard)
		var collider:=CollisionShape3D.new();guard.add_child(collider)
		var shape:=BoxShape3D.new();shape.size=spec[0];collider.shape=shape;collider.position=spec[1]
	var light:=OmniLight3D.new();interior.add_child(light);light.position=Vector3(2,3.8,0);light.omni_range=19;light.light_energy=1.6;light.light_color=Color("fff0d9")
	for spec in [[Vector3(-1.9,.37,2.2),PI/2],[Vector3(-.3,.37,4.0),0.0],[Vector3(1.6,2.94,.3),PI/2]]:
		var seat:=Marker3D.new();seat.name="Your sofa seat";seat.position=spec[0];seat.rotation.y=spec[1]
		seat.set_meta("player_owned",true);interior.add_child(seat);seat.add_to_group("seats");seats.append(seat)
	var bed_frame:=Node3D.new();interior.add_child(bed_frame);bed_frame.position=Vector3(-.4,2.59,-4.6)
	town.detailed_prop("Bed_Twin1",bed_frame,Vector3.ZERO,Vector3(1.3,.6,2.1),true)
	bed=Marker3D.new();bed.name="Your bed";interior.add_child(bed);bed.position=Vector3(-.4,3.19,-5.25)
	bed.set_meta("resident_owner","PLAYER");bed.set_meta("player_owned",true);bed.add_to_group("beds")
	cooking_anchor=Marker3D.new();cooking_anchor.name="CookingAnchor";interior.add_child(cooking_anchor);cooking_anchor.position=Vector3(1.4,0,1.5)
	cooking_anchor.add_to_group("cooking_anchors");cooking_anchor.set_meta("player_owned",true)
	# A compact stair flight gives the player a physical route to the upper gallery.
	for step in range(15):
		var height: float=(step+1)*2.59/15
		town.box(interior,Vector3(1.05,height,.32),Vector3(6.7,height/2,4.55-step*.3),Color("a79e90"),true)
	var layer:=CanvasLayer.new();add_child(layer);prompt=Label.new();layer.add_child(prompt)
	prompt.position=Vector2(24,650);prompt.add_theme_font_size_override("font_size",20)
	var sign:=Label3D.new();exterior.add_child(sign);sign.position=porch-exterior.position+Vector3.UP*2
	sign.text="Your home";sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.font_size=24;sign.pixel_size=.005
	var exit_sign:=Label3D.new();interior.add_child(exit_sign);exit_sign.position=exit_point-room_origin+Vector3.UP*1.8
	exit_sign.text="Outside · E";exit_sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;exit_sign.font_size=20;exit_sign.pixel_size=.004
	town.locations.append({"name":"Your potter's house","position":[porch.x,porch.y,porch.z]})
	start.call_deferred()

func start() -> void:
	while not town.player_home:await get_tree().process_frame
	town.player_home.register_house(interior)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ready_for_spawn=true
	if not town.economy.testing():enter_home()

func clear_capsule(point: Vector3) -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=.34;shape.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.exclude=[town.player.get_rid()]
	query.transform.origin=point+Vector3.UP*.92
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func safe_spawn() -> Vector3:
	for candidate: Vector3 in [spawn,room_origin+Vector3(4,.12,2),room_origin+Vector3(3,.12,0),room_origin+Vector3(5,.12,3)]:
		if clear_capsule(candidate):return candidate
	push_error("No clear player-home starting position")
	return spawn

func enter_home() -> void:
	town.adventures.stop_work()
	if town.life.active:town.life.close_dialog()
	if not town.player.resting.is_empty():town.player.stand_from_furniture(true)
	set_inside(true)
	town.player.position=safe_spawn();town.player.velocity=Vector3.ZERO
	town.player.rotation=Vector3.ZERO;town.player.camera.rotation=Vector3.ZERO
	town.player.reset_physics_interpolation()
	town.set_view(0)

func leave_home() -> void:
	if not clear_capsule(porch):return
	set_inside(false)
	town.player.position=porch;town.player.velocity=Vector3.ZERO;town.player.rotation.y=PI

func set_inside(value: bool) -> void:
	inside=value;interior.visible=value;exterior.visible=not value
	transferred_at=Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if not prompt or not town.player:return
	prompt.text=""
	if town.life.active or not town.player.enabled or not town.player.resting.is_empty():return
	var point:=exit_point if inside else porch
	if not preload("res://interaction_target.gd").uses_focus(town) and town.player.position.distance_to(point)<2.5:prompt.text="[E] Leave your home" if inside else "[E] Enter your home"
	if inside and town.player.position.y<room_origin.y-4:town.player.position=safe_spawn();town.player.velocity=Vector3.ZERO

func enter_visitor(person: CharacterBody3D) -> bool:
	if visitors.has(person) or visitors.size()>=2 or person.talking or person.night_schedule:return false
	if person.position.distance_to(porch)>4:return false
	visitors[person]={"position":person.position,"indoor_house":person.indoor_house,"role":person.indoor_role}
	person.position=room_origin+Vector3(4,.12,4);person.velocity=Vector3.ZERO
	person.indoor_house=interior;person.indoor_role="visiting your home"
	person.path=PackedVector3Array();person.path_index=0;person.wait_time=8
	return true

func exit_visitor(person: CharacterBody3D) -> bool:
	if not visitors.has(person):return false
	var previous: Dictionary=visitors[person]
	if person.social_partner:person.end_social()
	person.position=previous.position;person.indoor_house=previous.indoor_house;person.indoor_role=previous.role
	person.velocity=Vector3.ZERO;person.routine={};visitors.erase(person);person.plan()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and not prompt.text.is_empty() and Time.get_ticks_msec()-transferred_at>700:
		if inside:leave_home()
		else:enter_home()
		get_viewport().set_input_as_handled()

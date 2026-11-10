extends Node3D

# Ten residents share the existing navigation, household and conversation systems.
# Equipment is temporary and never changes the player's skin or shared animations.
const CAPACITY := 10
var town: Node3D
var actions: Node3D
var pupils: Array[CharacterBody3D] = []
var bows: Dictionary = {}
var shots := 0
var sessions := 0
var wood: StandardMaterial3D
var string_material: StandardMaterial3D

func _ready() -> void:
	actions=get_parent();town=actions.town
	wood=StandardMaterial3D.new();wood.albedo_color=Color("80512c")
	string_material=StandardMaterial3D.new();string_material.albedo_color=Color("eee1b9")
	name="ArcherySchool"
	for slot in range(CAPACITY):
		var marker:=Node3D.new();add_child(marker);marker.name="ArcheryLane"+str(slot+1)
		marker.position=lane(slot)
		town.box(marker,Vector3(1.2,.025,.15),Vector3(0,0,0),Color("dbc798"),false)
		var target:=StaticBody3D.new();add_child(target);target.name="SchoolTarget"+str(slot+1)
		target.position=target_point(slot);target.set_meta("archery_target",true)
		for x in [-.38,.38]:town.box(target,Vector3(.07,1.5,.09),Vector3(x,.75,.12),Color("705138"),false)
		for ring in range(4):
			var disk:=MeshInstance3D.new();var mesh:=CylinderMesh.new()
			mesh.top_radius=.62-ring*.14;mesh.bottom_radius=mesh.top_radius;mesh.height=.045;mesh.radial_segments=24
			disk.mesh=mesh;disk.rotation.x=PI/2;disk.position=Vector3(0,1.32,-.03-ring*.03);target.add_child(disk)
			var mat:=StandardMaterial3D.new();mat.albedo_color=[Color("d5bf82"),Color("693d29"),Color("c4a163"),Color("98412e")][ring];disk.material_override=mat
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.3,1.5,.3)
		collision.shape=shape;collision.position.y=1;target.add_child(collision)
		var sign:=Label3D.new();target.add_child(sign);sign.text=str(slot+1);sign.position=Vector3(0,2.1,0);sign.font_size=22;sign.pixel_size=.009

func lane(slot: int) -> Vector3:
	return Vector3(24+slot*2.5,.06,38)

func target_point(slot: int) -> Vector3:
	return Vector3(24+slot*2.5,.03,51)

func bind() -> void:
	var preferred: Array=["Fenn","Theo","Ollie","Roslin","Elowen","Agnes","Alden","Ivor","Lysa","Mina"]
	for person in town.life.people:
		if person.person_name not in preferred:preferred.append(person.person_name)
	for candidate in preferred:
		for person: CharacterBody3D in town.life.people:
			if person.person_name!=candidate or pupils.has(person):continue
			if person.indoor_house or not person.guard_label.is_empty() or not person.stall_name.is_empty():continue
			if not person.animator or not person.animator.has_animation("DrawArrow") or not person.animator.has_animation("AimOverdraw"):continue
			pupils.append(person);person.set_meta("archery_slot",pupils.size()-1)
			if pupils.size()==CAPACITY:break
		if pupils.size()==CAPACITY:break
	# The initial day/night assignment cancels routines; start after it finishes.
	start_class.call_deferred()

func start_class() -> void:
	for person in pupils:
		if not town.day_night.night:begin(person,true)

func begin(person: CharacterBody3D,initial := false) -> bool:
	if not pupils.has(person) or town.day_night.night or not town.routines.available(person):return false
	if not person.carry_kind.is_empty():return false
	if not initial and not person.job.is_empty() and person.job.get("stage","") not in ["start","break"]:return false
	var slot: int=person.get_meta("archery_slot")
	var key: String="training:lane:"+str(slot)
	if actions.reservations.has(key):return false
	var point:=lane(slot)
	var route: PackedVector3Array=town.life.route_to_point(person,point)
	if not initial and (route.is_empty() or route[-1].distance_to(point)>1.25):return false
	actions.reservations[key]=person
	person.routine={"kind":"resident_action","action":"training","stage":"walking","timer":0.0,"timeout":110.0,"key":key,"target":point,"animal":null,"props":null}
	person.path=route;person.path_index=0
	if initial:
		person.position=point;person.reset_physics_interpolation();person.path=PackedVector3Array([point])
	person.set_meta("next_archery",town.routines.elapsed+65+slot*2)
	person.activity="Walking to archery practice, lane "+str(slot+1)
	actions.clear_work(person)
	return true

func equip(person: CharacterBody3D) -> void:
	if bows.has(person):return
	var rigs: Array=person.visual.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty():return
	var rig: Skeleton3D=rigs[0]
	var left:=rig.find_bone("Wrist.L");var right:=rig.find_bone("Wrist.R")
	if left<0 or right<0:return
	var equipment:=Node3D.new();add_child(equipment);equipment.name=person.person_name+"PracticeBow"
	var segments: Array[Node3D]=[]
	# One instanced draw for all twelve pieces, instead of twelve draw calls per bow.
	var batch:=MultiMeshInstance3D.new();equipment.add_child(batch)
	batch.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mesh:=CylinderMesh.new();mesh.top_radius=.014;mesh.bottom_radius=.014;mesh.height=1;mesh.radial_segments=5
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;mesh.material=material
	batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_colors=true
	batch.multimesh.mesh=mesh;batch.multimesh.instance_count=12
	batch.custom_aabb=AABB(Vector3(-60,-5,-60),Vector3(120,20,120))
	for index in range(12):
		var part:=Node3D.new();equipment.add_child(part);segments.append(part)
		batch.multimesh.set_instance_color(index,Color("80512c") if index<8 else Color("eee1b9"))
	var hidden: Array[Node3D]=[]
	for node in person.equipment_nodes:
		if is_instance_valid(node) and node.visible:hidden.append(node);node.hide()
	bows[person]={"node":equipment,"rig":rig,"left":left,"right":right,"parts":segments,"batch":batch,"hidden":hidden,"last_shot":-1}

func tick(person: CharacterBody3D,delta: float) -> void:
	equip(person)
	var action: Dictionary=person.routine
	var slot: int=person.get_meta("archery_slot")
	person.visual.rotation.y=lerp_angle(person.visual.rotation.y,0,delta*8)
	var phase:=fmod(float(action.timer)+slot*.29,6.0)
	var desired: String="DrawArrow" if phase<1.1 else "AimOverdraw" if phase<4.5 else "Idle"
	person.animate(desired)
	if person.animator and not person.animator.is_playing():person.animator.play(desired,.15)
	person.activity="Archery practice - lane "+str(slot+1)
	if bows.has(person):
		var state: Dictionary=bows[person]
		var cycle:=int((float(action.timer)+slot*.29)/6.0)
		if phase>=4.5 and state.last_shot!=cycle:
			state.last_shot=cycle;shots+=1
		update_bow(person,state,phase)

func segment(part: Node3D,a: Vector3,b: Vector3,radius_scale := 1.0) -> void:
	var offset:=b-a
	part.global_position=(a+b)*.5
	part.global_basis=Basis(Quaternion(Vector3.UP,offset.normalized())).scaled(Vector3(radius_scale,offset.length(),radius_scale))

func update_bow(person: CharacterBody3D,state: Dictionary,phase: float) -> void:
	var rig: Skeleton3D=state.rig
	var hand: Vector3=rig.global_transform*rig.get_bone_global_pose(state.left).origin
	var draw: Vector3=rig.global_transform*rig.get_bone_global_pose(state.right).origin
	var size: float=person.appearance_height
	var tip_top:=hand+Vector3(0,.48*size,0)
	var tip_bottom:=hand-Vector3(0,.48*size,0)
	var last:=tip_bottom
	for index in range(8):
		var t:=float(index+1)/8
		var next:=hand+Vector3(0,(t-.5)*.96*size,sin(t*PI)*.19*size)
		segment(state.parts[index],last,next);last=next
	var nock:=draw if phase<4.5 else hand
	segment(state.parts[8],tip_top,nock,.22);segment(state.parts[9],nock,tip_bottom,.22)
	state.parts[10].visible=phase<4.5
	if phase<4.5:segment(state.parts[10],nock,nock+Vector3(0,0,.72*size),.32)
	var flight: float=(phase-4.5)/.65
	state.parts[11].visible=flight>=0 and flight<=1
	if state.parts[11].visible:
		var destination:=target_point(int(person.get_meta("archery_slot")))+Vector3(0,1.32,-.18)
		var arrow:=hand.lerp(destination,flight)
		segment(state.parts[11],arrow-Vector3(0,0,.65*size),arrow,.32)
	for index in range(12):
		var part: Node3D=state.parts[index]
		var pose: Transform3D=part.transform
		if not part.visible:pose.basis=Basis.from_scale(Vector3.ZERO)
		state.batch.multimesh.set_instance_transform(index,pose)

func cleanup(person: CharacterBody3D) -> void:
	if not bows.has(person):return
	var state: Dictionary=bows[person]
	for node in state.hidden:
		if is_instance_valid(node) and person.posture!="sleeping":node.show()
	state.node.queue_free();bows.erase(person)
	sessions+=1

func _process(_delta: float) -> void:
	# Keep the bow attached while AnimationPlayer interpolates between clips.
	for person in bows:
		if not is_instance_valid(person):continue
		var phase:=fmod(float(person.routine.get("timer",0))+int(person.get_meta("archery_slot",0))*.29,6.0)
		update_bow(person,bows[person],phase)


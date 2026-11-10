extends Node3D

const CAPACITY:=6
const CENTRE:=Vector3(-29,0,24)
const TRACK:="res://audio/festival/minstrel_dance.ogg"
var town: Node3D
var members: Dictionary={}
var slots: Dictionary={}
var hidden_equipment: Dictionary={}
var clock:=0.0
var invitation_clock:=0.0
var bound:=false
var music: AudioStreamPlayer3D
var enabled:=true
var music_enabled:=true
var music_level:=-16.0
var completed:=0
var sign: Label3D

func _ready() -> void:
	town=get_parent();name="VillageDance"
	build()
	setup.call_deferred()

func build() -> void:
	position=CENTRE
	# An open dance green leaves the surrounding roads and house doors clear.
	for side in [-1,1]:
		for z in [-4.2,4.2]:town.box(self,Vector3(.08,3.6,.08),Vector3(side*4.2,1.8,z),Color("765335"),false)
	for colour in range(3):
		var poses: Array[Transform3D]=[]
		for side in [-1,1]:
			for index in range(13):
				if index%3!=colour:continue
				var t:=float(index)/12
				poses.append(Transform3D(Basis(Vector3.FORWARD,PI),Vector3(lerpf(-4.2,4.2,t),3.35-sin(t*PI)*.45,side*4.2)))
		var flags:=MultiMeshInstance3D.new();var mesh:=PrismMesh.new();mesh.size=Vector3(.3,.42,.025)
		var mat:=StandardMaterial3D.new();mat.albedo_color=[Color("9c4036"),Color("d0ac58"),Color("4a776d")][colour];mesh.material=mat
		flags.multimesh=MultiMesh.new();flags.multimesh.transform_format=MultiMesh.TRANSFORM_3D;flags.multimesh.mesh=mesh;flags.multimesh.instance_count=poses.size();add_child(flags)
		for index in range(poses.size()):flags.multimesh.set_instance_transform(index,poses[index])
	for x in [-3.9,3.9]:
		for z in [-3.8,3.8]:
			var lamp: MeshInstance3D=town.box(self,Vector3(.22,.3,.22),Vector3(x,2.55,z),Color("efc46a"),false)
			var material:=lamp.material_override as StandardMaterial3D
			if material:material.emission_enabled=true;material.emission=Color("e7a94e");material.emission_energy_multiplier=1.0
	# Two unshadowed lamps keep the gathering warm without a light per flag.
	for x in [-3.5,3.5]:
		var lamp:=OmniLight3D.new();add_child(lamp);lamp.position=Vector3(x,2.4,0);lamp.light_color=Color("ffce87");lamp.light_energy=.65;lamp.omni_range=7;lamp.shadow_enabled=false
	sign=Label3D.new();add_child(sign);sign.text="The Copper Stag\nVillage Dance";sign.position=Vector3(0,2,-4.6);sign.font_size=30;sign.pixel_size=.009;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	music=AudioStreamPlayer3D.new();add_child(music);music.name="MinstrelMusic";music.position=Vector3(0,1.2,0)
	music.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED
	# Explicit player/focus distance keeps overhead camera height from muting it.
	music.max_distance=0;music.volume_db=-80;music.max_db=-12;music.attenuation_filter_cutoff_hz=6500
	if ResourceLoader.exists(TRACK):
		var stream:=load(TRACK) as AudioStreamOggVorbis
		if stream:stream.loop=true;music.stream=stream

func setup() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	bound=true
	town.locations.append({"name":"Village Dance · Copper Stag Green","position":[CENTRE.x,0,CENTRE.z],"entry":[CENTRE.x,0,CENTRE.z-5]})
	invite(true)

func open_for_dancing() -> bool:
	return enabled and not town.day_night.night and not (town.day_night.enabled and town.day_night.phase>=.70)

func spot(slot: int) -> Vector3:
	var angle:=float(slot)*TAU/CAPACITY
	return CENTRE+Vector3(sin(angle)*2.5,.03,cos(angle)*2.5)

func eligible(person: CharacterBody3D) -> bool:
	if members.has(person) or not town.routines.available(person):return false
	if person.indoor_house or person.is_child or not person.guard_label.is_empty() or not person.stall_name.is_empty():return false
	if not person.carry_kind.is_empty():return false
	if person.routine.get("action","")=="training" or person.talking:return false
	return person.animator!=null and person.animator.has_animation("RunnerDance")

func invite(initial:=false) -> void:
	if not open_for_dancing():return
	var candidates: Array=town.life.people.duplicate()
	candidates.sort_custom(func(a: CharacterBody3D,b: CharacterBody3D):return a.position.distance_squared_to(CENTRE)<b.position.distance_squared_to(CENTRE))
	for person: CharacterBody3D in candidates:
		if members.size()>=CAPACITY:break
		if not eligible(person):continue
		if not initial and clock<float(person.get_meta("next_village_dance",0)):continue
		# A routine pauses the existing job without clearing its progress.
		# Carrying residents are excluded above, so goods are never abandoned.
		var slot:=0
		while slots.has(slot):slot+=1
		var destination:=spot(slot)
		var route: PackedVector3Array=town.life.route_to_point(person,destination)
		if route.is_empty() or route[-1].distance_to(destination)>1.25:continue
		if person.position.distance_to(destination)>130:continue
		slots[slot]=person;members[person]=slot
		person.routine={"kind":"village_dance","stage":"walking","target":destination,"timer":0.0,"timeout":350.0,"dance_seconds":180.0+slot*4}
		person.path=route;person.path_index=0
		person.activity="Walking to the village dance"
		town.routines.actions.clear_work(person)

func tick(person: CharacterBody3D,delta: float) -> bool:
	if person.routine.get("kind","")!="village_dance":return false
	if not open_for_dancing() or person.night_schedule:
		town.routines.cancel(person);person.plan();return false
	if person.routine.stage=="walking":
		if not person.follow_path(delta,1.45):return true
		if person.position.distance_to(person.routine.target)>1.1:
			town.routines.cancel(person);person.plan();return false
		person.routine.stage="dancing"
		var hidden: Array[Node3D]=[]
		for item in person.equipment_nodes:
			if is_instance_valid(item) and item.visible:hidden.append(item);item.hide()
		hidden_equipment[person]=hidden
		person.animate(dance_clip(person))
		person.animator.seek(float(members[person])*.31,true)
	person.rest(delta)
	var facing:=CENTRE-person.position
	person.visual.rotation.y=lerp_angle(person.visual.rotation.y,atan2(facing.x,facing.z),delta*4)
	person.animate(dance_clip(person))
	person.activity="Dancing with the neighbours at the Copper Stag green"
	person.routine.timer+=delta
	if person.routine.timer>=person.routine.dance_seconds:
		completed+=1
		if town.character_life:town.character_life.feel(person.person_name,"Happy",40)
		town.jobs.record(person,"village_dance","I joined the neighbours for a dance by the Copper Stag. The minstrels played a lively tune.")
		town.routines.cancel(person);person.plan()
	return true

func dance_clip(person: CharacterBody3D) -> String:
	return "JazzDance" if int(members.get(person,0))%2==0 and person.animator.has_animation("JazzDance") else "RunnerDance"

func cleanup(person: CharacterBody3D) -> void:
	if not members.has(person):return
	var slot: int=members[person]
	if slots.get(slot)==person:slots.erase(slot)
	members.erase(person)
	for item in hidden_equipment.get(person,[]):
		if is_instance_valid(item) and person.posture!="sleeping":item.show()
	hidden_equipment.erase(person)
	person.set_meta("next_village_dance",clock+50)
	if person.animator and person.routine.get("kind")=="village_dance":person.animate("Idle")

func set_enabled(value: bool) -> void:
	enabled=value
	if not enabled:
		for person in members.keys():town.routines.cancel(person);person.plan()

func listening_point() -> Vector3:
	if town.view_mode==1:return town.overview_focus
	return town.player.global_position

func audible_gain(point: Vector3) -> float:
	var distance:=Vector2(point.x-CENTRE.x,point.z-CENTRE.z).length()
	return 1.0-smoothstep(3.0,32.0,distance)

func update_music(delta: float) -> void:
	var dancing:=0
	for person in members:
		if person.routine.get("stage")=="dancing":dancing+=1
	var gain:=audible_gain(listening_point()) if music_enabled and open_for_dancing() and dancing>=2 and not town.routines.paused else 0.0
	if town.life.active:gain*=.3
	var desired:=music_level+linear_to_db(maxf(.0001,gain))
	music.volume_db=lerpf(music.volume_db,maxf(-80,desired),1.0-exp(-delta*4))
	if gain>.001 and music.stream and not music.playing:music.play()
	elif gain<.001 and music.volume_db< -65 and music.playing:music.stop()

func _process(delta: float) -> void:
	if not bound:return
	# Other systems may claim a resident between invitation and arrival.
	# Release only our reservation; never cancel the replacement job/routine.
	for person in members.keys():
		if not is_instance_valid(person):
			var slot: int=members[person];slots.erase(slot);members.erase(person)
		elif person.routine.get("kind")!="village_dance":cleanup(person)
	clock+=delta
	update_music(delta)
	if town.routines.paused:return
	if not open_for_dancing():
		for person in members.keys():town.routines.cancel(person)
		return
	invitation_clock+=delta
	if invitation_clock>=5:
		invitation_clock=0;invite()

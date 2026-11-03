extends Node3D

var town: Node3D
var current:="Clear"
var automatic:=false
var elapsed:=0.0
var check_clock:=0.0
var sequence:=0
var rain: CPUParticles3D
var selector: OptionButton
var shelter_cache: Dictionary={}
var strength:=0.0

func _ready() -> void:
	town=get_parent()
	selector=OptionButton.new()
	for label in ["Weather · clear","Weather · overcast","Weather · rain","Weather · mist","Weather · changing"]:selector.add_item(label)
	selector.item_selected.connect(func(index: int):automatic=index==4;elapsed=0;set_weather(["Clear","Overcast","Rain","Mist","Clear"][index]))
	town.menu_body.add_child(selector)
	rain=CPUParticles3D.new();add_child(rain)
	rain.amount=320;rain.lifetime=1.1;rain.emitting=false
	rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;rain.emission_box_extents=Vector3(14,.3,14)
	rain.direction=Vector3(.08,-1,.03);rain.spread=4;rain.initial_velocity_min=16;rain.initial_velocity_max=20
	rain.gravity=Vector3(0,-6,0)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.012,.28,.012)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.65,.77,.86,.5);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material=material;rain.mesh=mesh

func set_weather(value: String) -> void:
	if value not in ["Clear","Overcast","Rain","Mist"]:return
	if current==value:return
	current=value;shelter_cache.clear()
	if town.events:town.events.publish("weather_"+str(Time.get_unix_time_from_system()),"The weather turned "+value.to_lower()+".",[],town.player.position)
	if value!="Rain":
		for person in town.life.people:
			if person.routine.get("kind","")=="rain_shelter":town.routines.cancel(person);person.plan()

func covered(point: Vector3) -> bool:
	return not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.85,point+Vector3.UP*15,1)).is_empty()

func find_cover(person: Node) -> PackedVector3Array:
	# Search actual roofed, reachable floor positions, including doorway overhangs.
	for radius in [3.0,6.0,10.0,15.0]:
		for index in range(12):
			var angle: float=index*TAU/12
			var point: Vector3=person.position+Vector3(cos(angle),0,sin(angle))*radius
			if not covered(point):continue
			var route: PackedVector3Array=town.life.route_to_point(person,point)
			if not route.is_empty() and covered(route[-1]):return route
	return PackedVector3Array()

func _process(delta: float) -> void:
	elapsed+=delta;check_clock+=delta
	if automatic and elapsed>75:
		elapsed=0;sequence+=1;set_weather(["Clear","Overcast","Rain","Overcast","Mist","Clear"][sequence%6])
	strength=move_toward(strength,1.0 if current=="Rain" else 0.0,delta*.25)
	var camera:=get_viewport().get_camera_3d()
	if camera:rain.global_position=camera.global_position+Vector3.UP*11
	rain.emitting=current=="Rain" and camera!=null and not covered(camera.global_position-Vector3.UP*1.7)
	# Run after the clock so weather and night lighting remain compatible.
	if town.day_night and town.day_night.environment:
		town.day_night.apply_time()
		var env: Environment=town.day_night.environment
		env.fog_density=lerpf(env.fog_density,.012 if current=="Mist" else .004 if current=="Rain" else .0018,minf(delta,1))
		if current in ["Rain","Overcast"]:
			town.day_night.sun.light_energy=minf(town.day_night.sun.light_energy,.36 if current=="Overcast" else .22)
	if check_clock<6 or not town.life.navigation_ready:return
	check_clock=0
	if current!="Rain":return
	var attempted:=0
	for person in town.life.people:
		if attempted>=3:break
		if not town.events.eligible(person) or covered(person.position):continue
		if int(shelter_cache.get(person.person_name,0))>Time.get_ticks_msec():continue
		shelter_cache[person.person_name]=Time.get_ticks_msec()+24000
		attempted+=1
		var route:=find_cover(person)
		if route.is_empty():continue
		person.path=route;person.path_index=0
		person.routine={"kind":"rain_shelter","timeout":65.0}
		person.activity="Looking for shelter from the rain"

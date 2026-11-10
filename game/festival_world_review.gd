extends SceneTree

const FrameCosts = preload("res://frame_costs.gd")
var town: Node3D
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready or not town.festival.bound:await process_frame
	while not town.interface_ui.ready_for_use or not town.home_district.ready_for_spawn:await process_frame
	town.interface_ui.close();paused=false
	if town.home_district.inside:town.home_district.leave_home()
	if town.day_night.enabled:town.day_night.set_enabled(false)
	town.speech.enabled=false
	town.player.position=Vector3(-24,.1,20);town.player.enabled=false
	town.set_process(false);town.set_process_input(false);town.set_process_unhandled_input(false)
	town.set_view(1);town.overview_focus=Vector3(-29,0,24);town.distance=18;town.orbit=.5;town.update_camera()
	Engine.time_scale=2.0
	var maximum:=0;var seconds:=0.0
	while seconds<180:
		await create_timer(1).timeout;seconds+=1
		var dancing:=0;var names: Array=[]
		for person in town.festival.members:
			names.append(person.person_name+":"+String(person.routine.get("stage",""))+":"+str(person.position))
			if person.routine.get("stage")=="dancing":dancing+=1
		maximum=maxi(maximum,dancing)
		if int(seconds)%10==0:print("FESTIVAL_REAL_ROUTES seconds=",seconds," members=",town.festival.members.size()," dancing=",dancing," residents=",names)
		if dancing==6:break
	if maximum<3:failures.append("A group of residents must physically reach the green and dance")
	if not town.festival.music.playing:failures.append("Local music must play near the dancers")
	if "--profile-party" in OS.get_cmdline_user_args():
		Engine.time_scale=1.0
		await create_timer(4).timeout
		await profile_party()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../review/village-dance-in-town.png")
	print("FESTIVAL_WORLD_REVIEW_COMPLETE failures=",failures," dancers=",maximum," population=",town.life.people.size()," music_playing=",town.festival.music.playing)
	town.festival.set_enabled(false)
	if not town.festival.members.is_empty():failures.append("Gathering toggle must release all residents")
	quit(0 if failures.is_empty() else 1)

func profile_party() -> void:
	var samples: Array[Dictionary]=[]
	var physics_sum:=0.0
	var previous:=Time.get_ticks_usec()
	var deadline:=previous+30_000_000
	FrameCosts.reset()
	while previous<deadline:
		await process_frame
		var now:=Time.get_ticks_usec()
		var physics_ms:=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		physics_sum+=physics_ms
		samples.append({"ms":float(now-previous)/1000.0,"frame":Engine.get_process_frames(),"physics_ms":physics_ms})
		previous=now
	FrameCosts.enabled=false
	var total:=0.0
	var over_50:=0
	for sample in samples:
		total+=sample.ms
		if sample.ms>50.0:over_50+=1
	samples.sort_custom(func(a: Dictionary,b: Dictionary):return a.ms>b.ms)
	var result: Dictionary={
		"fps":1000.0*samples.size()/total,
		"p95_ms":samples[samples.size()-1-int((samples.size()-1)*.95)].ms,
		"max_ms":samples[0].ms,
		"over_50ms":over_50,
		"physics_ms":physics_sum/samples.size(),
		"slow_frames":samples.slice(0,12),
		"tasks":FrameCosts.report(),
	}
	var file:=FileAccess.open("res://../review/festival-performance.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(result,"\t"))
	print("FESTIVAL_PERFORMANCE fps=",result.fps," p95_ms=",result.p95_ms," max_ms=",result.max_ms," over_50ms=",result.over_50ms)

extends SceneTree

func _initialize() -> void:run.call_deferred()

func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var ground:=StaticBody3D.new()
	stage.add_child(ground)
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(20,1,20)
	collider.shape=shape
	collider.position.y= -0.5
	ground.add_child(collider)
	var player: CharacterBody3D=load("res://player.gd").new()
	stage.add_child(player)
	player.set_view(2)
	var failures:Array[String]=[]
	var seen:Dictionary={}
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://player_skins.json"))
	for skin in catalog:
		if seen.has(skin.base):failures.append("Duplicate base model "+skin.base)
		seen[skin.base]=true
		if not ResourceLoader.exists("res://characters/"+skin.id+".glb"):continue
		if not player.set_skin(skin.id,false):failures.append("Skin cannot load "+skin.id);continue
		for clip in ["PlayerIdle","Walk","RunnerRun","RunnerJump","SitEnter","SitIdle","SleepExit"]:
			if not player.animator.has_animation(clip):failures.append(skin.id+" missing "+clip)
		player.position=Vector3(0,0.1,0)
		player.velocity=Vector3.ZERO
		for frame in range(15):await physics_frame
		player.jump_requested=true
		var base:float=player.position.y
		var highest:=base
		for frame in range(90):
			await physics_frame
			highest=maxf(highest,player.position.y)
		if highest-base<0.5 or not player.is_on_floor():failures.append(skin.id+" jump/landing failed")
		print("PLAYER_SKIN_CHECK id=",skin.id," clips=",player.animator.get_animation_list().size()," jump_rise=",highest-base," landed=",player.is_on_floor())
	print("PLAYER_SKINS_REVIEW_COMPLETE failures=",failures," unique_bases=",seen.size())
	quit(0 if failures.is_empty() else 1)

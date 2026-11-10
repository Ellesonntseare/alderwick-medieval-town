extends SceneTree

var town: Node3D
var failures: Array[String]=[]
class ForestTown extends Node3D:
	var player: CharacterBody3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func floor_at(point: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*10,point-Vector3.UP*3,1)
	ray.exclude=[town.player.get_rid()]
	return town.get_world_3d().direct_space_state.intersect_ray(ray)

func run() -> void:
	if "--forest-only" in OS.get_cmdline_user_args():
		await forest_only()
		return
	town=load("res://town.tscn").instantiate();root.add_child(town)
	while not town.life.navigation_ready:await physics_frame
	town.day_night.set_enabled(false)
	town.speech.set_enabled(false)
	town.player.enabled=false;town.player.set_physics_process(false)
	var woods: Node3D=town.get_node("WalkableWoodlands")
	check(woods.patches.size()>=25 and woods.tree_count>2000,"Downloaded forest is spread around city and castles")
	check(town.life.people.size()==53,"Map additions preserve the 53-resident cast")
	var space := town.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8
	var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.exclude=[town.player.get_rid()]
	var blocked: Array[Vector3]=[]
	for z in range(64,121):
		var point := Vector3(0,0,z)
		var floor := floor_at(point)
		if floor.is_empty():blocked.append(point);continue
		point.y=floor.position.y
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.93)
		if not space.intersect_shape(query,1).is_empty():blocked.append(point)
	check(blocked.is_empty(),"The southern road to the woodland trail must be clear")
	print("SOUTHERN_ROAD_CHECK blocked=",blocked)
	await walk_woods(woods,query)
	if DisplayServer.get_name()!="headless":
		town.player.hide();town.set_view(1)
		town.menu_body.hide();town.life.hint.hide();town.life.talk_button.hide()
		town.overview.position=Vector3(155,140,100);town.overview.look_at(Vector3(25,0,90))
		await capture("forest-city-preview.png")
	print("WORLD_DISTRICTS_REVIEW_COMPLETE failures=",failures," patches=",woods.patches.size()," trees=",woods.tree_count)
	quit(0 if failures.is_empty() else 1)

func capture(path: String) -> void:
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../"+path)

func walk_woods(woods: Node3D,query: PhysicsShapeQueryParameters3D) -> void:
	var patch: Node3D=woods.patches[0]
	for candidate in woods.patches:
		if candidate.position.distance_to(Vector3(20,0,120))<1:patch=candidate;break
	var nav := AStarGrid2D.new();nav.region=Rect2i(-28,-28,57,57);nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;nav.update()
	var heights: Dictionary={}
	var space := town.get_world_3d().direct_space_state
	query.shape.radius=.38
	for x in range(-28,29):
		for z in range(-28,29):
			var cell := Vector2i(x,z)
			var point: Vector3=patch.to_global(Vector3(x*.5,0,z*.5))
			var floor := floor_at(point)
			var blocked := floor.is_empty()
			if not blocked:
				point.y=floor.position.y
				heights[cell]=point.y
				query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.93)
				blocked=not space.intersect_shape(query,1).is_empty() or floor.normal.y<.7
			nav.set_point_solid(cell,blocked)
	var route: Array[Vector2i]=[]
	for z in range(-24,25,2):
		var a := Vector2i(-24,z);var b := Vector2i(24,z)
		if nav.is_point_solid(a) or nav.is_point_solid(b):continue
		route=nav.get_id_path(a,b,false)
		if not route.is_empty():break
	check(not route.is_empty(),"A person-sized path crosses the actual woodland terrain")
	if route.is_empty():return
	var points := PackedVector3Array()
	for cell in route:
		var point: Vector3=patch.to_global(Vector3(cell.x*.5,0,cell.y*.5));point.y=heights[cell]
		points.append(point)
	town.player.position=points[0]+Vector3.UP*.02
	town.player.collision_mask=1
	var index := 1
	var travelled := 0.0
	for frame in range(2400):
		await physics_frame
		if index>=points.size():break
		var difference: Vector3=points[index]-town.player.position;difference.y=0
		if difference.length()<.10:index+=1;continue
		var before: Vector3=town.player.position
		town.player.velocity=difference.normalized()*minf(3.5,difference.length()*60)
		town.player.velocity.y= -2
		town.player.move_with_steps(1.0/60.0)
		travelled+=town.player.position.distance_to(before)
	check(index>=points.size(),"The actual player can walk through the woods")
	print("WOODLAND_PLAYER_WALK completed=",index>=points.size()," distance=",travelled," path_points=",points.size()," at=",town.player.position," next=",points[index] if index<points.size() else Vector3.ZERO)

func forest_only() -> void:
	town=ForestTown.new();root.add_child(town)
	var ground := StaticBody3D.new();town.add_child(ground)
	var floor_shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(1000,2,1000);floor_shape.shape=box;floor_shape.position.y= -1.05;ground.add_child(floor_shape)
	town.player=load("res://player.gd").new();town.add_child(town.player);town.player.enabled=false;town.player.set_physics_process(false)
	var woods: Node3D=load("res://forest_districts.gd").new();town.add_child(woods)
	var light := DirectionalLight3D.new();town.add_child(light);light.rotation_degrees=Vector3(-40,-20,0)
	await physics_frame;await physics_frame
	var capsule := CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.8
	var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.exclude=[town.player.get_rid()]
	await walk_woods(woods,query)
	if DisplayServer.get_name()!="headless":
		var camera := Camera3D.new();town.add_child(camera);camera.current=true;camera.position=Vector3(23,2.0,132);camera.look_at(Vector3(20,2.0,118));await capture("forest-walking-preview.png")
	print("FOREST_WALK_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)

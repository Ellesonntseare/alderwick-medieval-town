extends SceneTree

class Town extends Node3D:
	var locations: Array[Dictionary]=[]
	var factory: Node3D
	func box(parent: Node3D,size: Vector3,pos: Vector3,color: Color,solid := false) -> MeshInstance3D:return factory.box(parent,size,pos,color,solid)
	func add_sign(title: String,pos: Vector3,angle: float,font_size: int) -> void:
		var label:=Label3D.new()
		label.text=title;label.position=pos;label.rotation.y=angle+PI;label.font_size=font_size;label.pixel_size=.009
		add_child(label)

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,800)
	root.title="Checking new château districts"
	var town:=Town.new()
	town.factory=load("res://town.gd").new()
	root.add_child(town)
	var ground: MeshInstance3D=town.box(town,Vector3(1000,30,1000),Vector3(0,-15.05,0),Color("667447"),true)
	ground.name="SharedGround"
	var sun:=DirectionalLight3D.new()
	town.add_child(sun)
	sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("b8c6bf")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.7
	environment.environment=settings;town.add_child(environment)
	var camera:=Camera3D.new()
	town.add_child(camera);camera.current=true;camera.far=900
	var districts: Node3D=load("res://chateau_districts.gd").new()
	town.add_child(districts)
	for frame in range(3):await physics_frame
	var failures: Array[String]=[]
	if districts.sites.size()!=2:failures.append("Both château districts must load")
	for site in districts.sites:
		var nav:=AStarGrid2D.new()
		var bounds: Rect2=site.rect.grow(10)
		nav.region=Rect2i(floori(bounds.position.x),floori(bounds.position.y),ceili(bounds.size.x)+1,ceili(bounds.size.y)+1)
		nav.cell_size=Vector2.ONE;nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;nav.update()
		var heights: Dictionary={}
		var space:=town.get_world_3d().direct_space_state
		var shape:=CapsuleShape3D.new();shape.height=1.8;shape.radius=.34
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
		for x in range(nav.region.position.x,nav.region.end.x):
			for z in range(nav.region.position.y,nav.region.end.y):
				var cell:=Vector2i(x,z)
				var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,35,z),Vector3(x,-22,z),1)
				if x>=site.outside.x-1 and x<=site.inside.x+1 and absf(z-site.entry.z)<1.3:
					var expected: float=lerpf(site.entry.y,site.inside.y,clampf((x-site.entry.x)/(site.inside.x-site.entry.x),0,1))
					ray=PhysicsRayQueryParameters3D.create(Vector3(x,expected+.4,z),Vector3(x,expected-1,z),1)
				var hit:=space.intersect_ray(ray)
				if hit.is_empty() or hit.normal.y<.6 or hit.position.y< -18:nav.set_point_solid(cell,true);continue
				query.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.96)
				if not space.intersect_shape(query,1).is_empty():nav.set_point_solid(cell,true);continue
				heights[cell]=float(hit.position.y)
		var walk:=AStar3D.new()
		var ids: Dictionary={}
		for cell in heights:
			ids[cell]=ids.size()
			walk.add_point(ids[cell],Vector3(cell.x,heights[cell],cell.y))
		for cell in heights:
			for offset: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
				var next: Vector2i=cell+offset
				if heights.has(next) and absf(heights[cell]-heights[next])<=.5:walk.connect_points(ids[cell],ids[next])
		var start:=nearest(nav,Vector2i(roundi(site.outside.x),roundi(site.outside.z)))
		var finish:=nearest(nav,Vector2i(roundi(site.inside.x),roundi(site.inside.z)))
		var route:=walk.get_point_path(ids[start],ids[finish])
		print("CHATEAU_ACCESS id=",site.id," start=",start," end=",finish," steps=",route.size()," outside_height=",heights.get(start)," inside_height=",heights.get(finish))
		if route.is_empty():failures.append(site.id+" no adult-sized walkable entrance route")
		if not route.is_empty() and "--capture-chateaux" not in OS.get_cmdline_user_args():
			var player: CharacterBody3D=load("res://player.gd").new()
			town.add_child(player)
			player.enabled=false
			player.position=route[0]+Vector3.UP*.05
			var index:=1
			for frame in range(4000):
				await physics_frame
				if index>=route.size():break
				var difference: Vector3=route[index]-player.position
				difference.y=0
				if difference.length()<.2:index+=1;continue
				var direction:=difference.normalized()
				player.velocity=Vector3(direction.x*3.5,-2,direction.z*3.5)
				player.move_with_steps(1.0/60.0)
			print("CHATEAU_ACTUAL_WALK id=",site.id," completed=",index>=route.size()," position=",player.position," destination=",route[-1])
			if index<route.size():failures.append(site.id+" player did not reach its actual interior")
			player.queue_free()
			await physics_frame
		if route.is_empty():
			var gaps: Array=[]
			for x in range(start.x,finish.x+1):
				var cell:=Vector2i(x,start.y)
				if not heights.has(cell):gaps.append(x)
			print("CHATEAU_ROUTE_GAPS id=",site.id," z=",start.y," blocked_x=",gaps)
		if "--capture-chateaux" in OS.get_cmdline_user_args():
			camera.global_position=site.root.position+Vector3(95,85,115)
			camera.look_at(site.root.position)
			for frame in range(90):await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../town-"+site.id+".png")
	print("CHATEAUX_REVIEW_COMPLETE failures=",failures)
	town.factory.free()
	quit(0 if failures.is_empty() else 1)

func nearest(nav: AStarGrid2D,point: Vector2i) -> Vector2i:
	for radius in range(8):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var candidate:=point+Vector2i(x,z)
				if nav.is_in_boundsv(candidate) and not nav.is_point_solid(candidate):return candidate
	return point



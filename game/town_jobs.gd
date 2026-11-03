extends Node3D

var town: Node3D
var life: Node
var benches: Array[Dictionary]=[]
var markets: Dictionary={}
var sources: Dictionary={}
var fields: Dictionary={}
var events: Array[Dictionary]=[]
var deliveries := 0
var furniture_made := 0
var supplies_delivered := 0
var supply_stock := {"city":0,"west":0,"castle":0}
var guards: Array[CharacterBody3D]=[]
var night_guards: Array[CharacterBody3D]=[]

func _ready() -> void:
	town=get_parent()
	build()

func prop(id: String,parent: Node3D,pos: Vector3,size: Vector3,solid := false) -> Node3D:
	return town.detailed_prop(id,parent,pos,size,solid)

func build() -> void:
	for spec in [["city",Vector3(35,0,5)],["city",Vector3(35,0,16)],["west",Vector3(-95,0,114)],["castle",Vector3(125,0,94)]]:
		var root := Node3D.new()
		add_child(root)
		root.position=spec[1]
		prop("Workbench_Drawers",root,Vector3.ZERO,Vector3(1.8,0.9,0.75),true)
		prop("Stool",root,Vector3(1.4,0,0.15),Vector3(0.45,0.48,0.45),true)
		var output := Node3D.new()
		root.add_child(output)
		benches.append({"root":root,"district":spec[0],"point":spec[1]+Vector3(0,0.03,0.8),"owner":null,"output":output,"made":0})
	for district in ["city","west","castle"]:
		var source: Vector3={"city":Vector3(42,0,-43),"west":Vector3(-93,0,112),"castle":Vector3(130,0,103)}[district]
		sources[district]=source+Vector3(0,0.03,1.2)
		prop("Crate_Wooden",self,source,Vector3(1.1,0.85,0.8),true)
		prop("Bag",self,source+Vector3(0,0.86,0),Vector3(0.45,0.38,0.4))
		var field: Vector3={"city":Vector3(-37,0,38),"west":Vector3(-94,0,74),"castle":Vector3(141,0,97)}[district]
		fields[district]=field+Vector3(0,0.03,-1.3)
		for row in range(3):
			for col in range(5):prop("Carrot",self,field+Vector3((col-2)*0.45,0.03,(row-1)*0.5),Vector3(0.16,0.3,0.16))
		prop("FarmCrate_Carrot",self,field+Vector3(1.8,0,-1.6),Vector3(0.7,0.4,0.5))
	prop("Crate_Wooden",self,Vector3(-35,0,25),Vector3(1.1,0.85,0.8),true)
	prop("Bag",self,Vector3(-35,0.86,25),Vector3(0.45,0.38,0.4))
	make_market("city",Vector3(-5,0,8),Vector3(-7,0.0,5),"Square market")
	make_market("west",Vector3(-97,0,103),Vector3(-101,0,103),"Western market",true)
	make_market("castle",Vector3(122,0,101),Vector3(118,0,101),"Castle provisions",true)

func make_market(district: String,point: Vector3,display: Vector3,title: String,add_stall := false) -> void:
	if add_stall:town.stall(display,true)
	var root := Node3D.new()
	add_child(root)
	root.position=display+Vector3(0,0,2.2)
	var sign := Label3D.new()
	root.add_child(sign)
	sign.position.y=1.6
	sign.font_size=25
	sign.pixel_size=0.008
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign.outline_size=6
	markets[district]={"point":point+Vector3.UP*0.03,"root":root,"label":sign,"stock":12,"title":title,"received":12,"sold":0,"returned":0}
	update_market(district)

func update_market(district: String) -> void:
	var market: Dictionary=markets[district]
	market.label.text=market.title+"\nVegetables: "+str(market.stock)+" portions · 2 coins"
	var count := mini(ceili(float(market.stock)/6.0),6)
	while market.root.get_child_count()-1>count:
		var extra: Node=market.root.get_child(market.root.get_child_count()-1)
		market.root.remove_child(extra)
		extra.queue_free()
	while market.root.get_child_count()-1<count:
		var index: int=market.root.get_child_count()-1
		prop("FarmCrate_Carrot",market.root,Vector3((index%3-1)*0.65,(index/3)*0.32,0),Vector3(0.58,0.3,0.4))
	for display: Node3D in get_tree().get_nodes_in_group("market_produce"):
		var region := "west" if display.global_position.x< -75 else "castle" if display.global_position.x>75 else "city"
		if region==district:display.visible=market.stock>0

func bind(residents: Node) -> void:
	life=residents
	var city_posts := [[Vector3(-5,0,61),0.0,"the south gate"],[Vector3(5,0,61),0.0,"the south gate"],
		[Vector3(-69,0,4),-PI/2,"the western town gate"],[Vector3(69,0,-4),PI/2,"the eastern crossing"],
		[Vector3(45,0,45),0.0,"the training yard"],[Vector3(6,0,-12),0.0,"the town hall"],
		[Vector3(24,0,-15),-PI/2,"the granary"],[Vector3(43,0,-46),0.0,"the storehouse"],[Vector3(4,0,-45),PI,"the northern road"]]
	var west_posts := [[Vector3(-100,0,95),PI/2,"the western village entrance"],[Vector3(-238,0,62),PI,"the western crofts"]]
	west_posts.append([Vector3(-105,0,89),PI,"the western gate house"])
	var castle_posts := [[Vector3(111,0,-63),PI,"Feira Castle gate"],[Vector3(180,0,-81),0.0,"Burg Arnstein approach"],[Vector3(115,0,91),0.0,"Castle XIX gate"]]
	var indexes := {"city":0,"west":0,"castle":0}
	var model_jobs: Dictionary={}
	for person in life.people:
		var district: String=person.get_meta("district")
		if person.style in ["knight","viking","saxon"] or (person.occupation=="Guard" and district=="castle"):
			var posts: Array=city_posts if district=="city" else west_posts if district=="west" else castle_posts
			var post: Array=posts[indexes[district]%posts.size()]
			indexes[district]+=1
			person.guard_post=guard_standing_place(person,post[0])
			person.guard_facing=post[1]
			person.guard_label=post[2]
			person.position=person.guard_post
			person.visual.rotation.y=person.guard_facing
			person.occupation="Guard"
			person.stall_name=""
			person.job={"kind":"guard","stage":"posted","district":district,"target":person.guard_post}
			person.path=PackedVector3Array()
			person.path_index=0
			guards.append(person)
		elif not person.indoor_house and person.stall_name.is_empty():
			var kind := "farm" if person.occupation=="Farmer" else "carpentry" if person.occupation=="Carpenter" else "supply" if person.occupation in ["Forester","Merchant","Supply courier"] else ""
			if not kind.is_empty():
				var start: Vector3=fields[district] if kind=="farm" else sources[district]
				var identity: String=district+":"+person.style+":"+kind
				var cohort: int=int(model_jobs.get(identity,0))
				model_jobs[identity]=cohort+1
				if kind=="supply" and district=="city" and cohort%2==1:start=Vector3(-35,0.03,26.2)
				var source_point := start
				if kind=="carpentry":
					var available: Array=[]
					for bench in benches:
						if bench.district==district:available.append(bench)
					if not available.is_empty():start=available[cohort%available.size()].point
				for offset: Vector3 in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(2,0,0)]:
					var cell: Vector2i=life.free_cell(start+offset)
					var point := Vector3(cell.x,float(life.floor_heights[cell])+0.03,cell.y)
					var clear := true
					for other in life.people:
						if other!=person and other.position.distance_to(point)<0.95:clear=false
					if clear:person.position=point;break
				var depot: Vector3=supply_target(district)
				if person.person_name=="Duncan":depot=Vector3(-35,0.03,26.2)
				if kind=="supply" and district=="city" and cohort%2==1:depot=benches[1].point+Vector3(2.4,0,0)
				person.job={"kind":kind,"stage":"start","district":district,"timer":person.decision_rng.randf_range(0,3)+cohort*5,"target":person.position,"source":source_point,"depot":depot,"has_load":false,"completed":0}
	print("VISIBLE_JOBS_READY guards=",guards.size()," benches=",benches.size())

func bind_night_watch() -> void:
	for spec in [["Cedric",Vector3(-3,0,57),0.0,"the south gate at night"],["Wolfram",Vector3(8,0,-9),PI,"the town hall at night"],["Rolf",Vector3(-98,0,98),PI/2,"the western village at night"],["Selene",Vector3(69,0,47),PI/2,"the eastern bridge at night"]]:
		for person in life.people:
			if person.person_name!=spec[0]:continue
			person.guard_shift="night"
			person.guard_post=guard_standing_place(person,spec[1])
			person.guard_facing=spec[2]
			person.guard_label=spec[3]
			person.occupation="Night guard"
			person.food=2
			person.job={"kind":"guard","stage":"posted","district":person.get_meta("district"),"target":person.guard_post,"was_away":true}
			night_guards.append(person)
	print("NIGHT_WATCH_READY count=",night_guards.size())

func guard_standing_place(person: CharacterBody3D,requested: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius=0.42
	shape.height=1.95
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	query.exclude=[person.get_rid(),town.player.get_rid()]
	var chosen := requested
	for offset: Vector3 in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(2,0,0),Vector3(-2,0,0)]:
		var cell: Vector2i=life.free_cell(requested+offset)
		var point := Vector3(cell.x,float(life.floor_heights[cell]),cell.y)
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.3,point-Vector3.UP*1.0,1)
		ray.exclude=[person.get_rid(),town.player.get_rid()]
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():point.y=hit.position.y
		query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(0.16+shape.height/2))
		if not space.intersect_shape(query,1).is_empty():continue
		chosen=point
		break
	# Keep the watch mark flush with the actual ground. A raised collision
	# block here can prevent a returning guard taking the final step to work.
	town.box(self,Vector3(1.1,0.012,1.1),chosen+Vector3.UP*0.006,Color("797b6c"),false)
	return chosen+Vector3.UP*0.008

func record(person: CharacterBody3D,kind: String,text: String) -> void:
	var event := {"who":person.person_name,"kind":kind,"text":text,"time":Time.get_ticks_msec()/1000.0}
	person.recent_events.append(event)
	if person.recent_events.size()>5:person.recent_events.pop_front()
	events.append(event)
	if events.size()>30:events.pop_front()
	if town.economy:town.economy.pay(person,kind)
	if town.character_life:town.character_life.worked(person,kind)

func set_target(person: CharacterBody3D,target: Vector3,stage: String) -> void:
	var route: PackedVector3Array=life.route_to_point(person,target)
	if route.is_empty():
		var cell: Vector2i=life.free_cell(target)
		var alternative := Vector3(cell.x,float(life.floor_heights[cell])+0.03,cell.y)
		if alternative.distance_to(target)<(0.95 if stage=="to_bench" else 2.0):
			target=alternative
			route=life.route_to_point(person,target)
	person.job.target=target
	person.job.stage=stage
	person.path=route
	person.path_index=0
	person.stuck_time=0

func plan(person: CharacterBody3D) -> void:
	if person.job.is_empty():return
	person.path=life.route_to_point(person,person.job.target)
	person.path_index=0
	person.stuck_time=0

func release_bench(person: CharacterBody3D) -> void:
	for bench in benches:
		if bench.owner==person:bench.owner=null

func suspend(person: CharacterBody3D) -> void:
	release_bench(person)
	person.set_carry("")
	if not person.guard_label.is_empty():person.job.was_away=true
	if not person.job.is_empty() and person.job.kind!="guard":person.job.stage="start"

func tick(person: CharacterBody3D,delta: float) -> void:
	var job: Dictionary=person.job
	if job.kind=="industrial":
		# The corridor manager owns these shifts; normal routines still run
		# during breaks and the existing night system owns sleeping.
		person.rest(delta);person.animate("Idle")
		return
	if job.kind=="guard":
		var difference: Vector3=person.guard_post-person.position
		difference.y=0
		if difference.length()>0.06:
			person.activity="Returning to "+person.guard_label
			if difference.length()<1.0:person.move_direction(difference.normalized(),minf(1.6,difference.length()/delta),delta)
			else:
				if person.path_index>=person.path.size():plan(person)
				person.follow_path(delta,6.5 if town.day_night.cycle_seconds<=60 else 1.6)
		else:
			if job.get("was_away",false):
				record(person,"watch","I returned to my "+person.guard_shift+" watch at "+person.guard_label+".")
				job.was_away=false
			person.rest(delta)
			person.visual.rotation.y=lerp_angle(person.visual.rotation.y,person.guard_facing,delta*8)
			person.animate("Idle")
			person.activity="Guarding "+person.guard_label
		return
	if job.get("timer",0)>0:
		job.timer-=delta
		person.rest(delta)
		person.animate(person.work_animation() if job.stage in ["harvesting","crafting"] else "Idle")
		return
	var district: String=job.district
	match String(job.stage):
		"start":
			if job.kind=="carpentry":
				var choices := benches.duplicate()
				choices.sort_custom(func(a: Dictionary,b: Dictionary):return person.position.distance_squared_to(a.point)<person.position.distance_squared_to(b.point))
				for bench in choices:
					if bench.district==district and not is_instance_valid(bench.owner):
						var duplicate_nearby := false
						for other in life.people:
							if other!=person and other.style==person.style and other.position.distance_to(bench.point)<6:duplicate_nearby=true;break
						if duplicate_nearby:continue
						bench.owner=person
						job.bench=bench
						set_target(person,bench.point,"to_bench")
						return
				person.activity="Waiting for a free workbench"
				job.timer=1.5
			elif job.get("has_load",false):
				person.set_carry("carrots" if job.kind=="farm" else "supplies")
				set_target(person,markets[district].point if job.kind=="farm" else job.depot,"delivering")
			else:set_target(person,job.source,"to_source")
		"to_source","to_bench","delivering":
			person.activity="Carrying vegetables to "+markets[district].title if job.stage=="delivering" and job.kind=="farm" else "Delivering supplies" if job.stage=="delivering" else "Walking to the workbench" if job.stage=="to_bench" else "Collecting vegetables" if job.kind=="farm" else "Collecting supplies"
			var close: bool=Vector2(person.position.x-job.target.x,person.position.z-job.target.z).length()<(0.25 if job.stage=="to_bench" else 0.75)
			if not close and not person.follow_path(delta,1.65):return
			if person.position.distance_to(job.target)>1.1:
				plan(person)
				return
			if job.stage=="delivering":finish_delivery(person)
			elif job.stage=="to_bench":
				job.stage="crafting"
				job.timer=7.0*(town.character_life.work_duration(person,"Carpentry") if town.character_life else 1.0)
				person.visual.rotation.y=PI
				person.activity="Making furniture at the workbench"
			elif job.kind=="farm":
				job.stage="harvesting"
				job.timer=5.0*(town.character_life.work_duration(person,"Farming") if town.character_life else 1.0)
				person.visual.rotation.y=0
				person.activity="Harvesting fresh carrots"
			else:load_delivery(person)
		"harvesting":load_delivery(person)
		"crafting":
			var bench: Dictionary=job.bench
			bench.made+=1
			furniture_made+=1
			if bench.output.get_child_count()<4:prop("Stool",bench.output,Vector3(-1.8,0,(bench.output.get_child_count()-1.5)*0.55),Vector3(0.45,0.5,0.45))
			record(person,"crafted","I finished a wooden stool at the workbench.")
			release_bench(person)
			job.completed+=1
			job.stage="break"
			job.timer=5.0
			person.activity="Finished a stool; taking a short break"
		"break":job.stage="start"

func supply_target(district: String) -> Vector3:
	for bench in benches:
		if bench.district==district:return bench.point+Vector3(2.4,0,0)
	return markets[district].point

func load_delivery(person: CharacterBody3D) -> void:
	person.job.has_load=true
	person.set_carry("carrots" if person.job.kind=="farm" else "supplies")
	set_target(person,markets[person.job.district].point if person.job.kind=="farm" else person.job.depot,"delivering")

func finish_delivery(person: CharacterBody3D) -> void:
	var job: Dictionary=person.job
	if not job.get("has_load",false):return
	person.set_carry("")
	job.has_load=false
	job.completed+=1
	if job.kind=="farm":
		deliveries+=1
		markets[job.district].stock+=6
		markets[job.district].received+=6
		update_market(job.district)
		record(person,"delivery","I delivered a crate of fresh carrots to "+markets[job.district].title+".")
	else:
		supplies_delivered+=1
		var index: int=supply_stock[job.district]
		supply_stock[job.district]=index+1
		record(person,"supply","I brought fresh supplies from the storehouse to the carpenters.")
		if index<8:prop("Crate_Wooden",self,job.depot+Vector3(0.8+(index%2)*0.6,(index/4)*0.45,((index/2)%2)*0.6),Vector3(0.5,0.45,0.4))
	job.stage="break"
	job.timer=5
	person.activity="Delivery completed; taking a short break"

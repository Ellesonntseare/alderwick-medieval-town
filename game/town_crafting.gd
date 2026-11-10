extends Node

const RECIPES={
	"Crafted stool":{"cost":{"Timber":3},"seconds":6.0,"level":0,"asset":"Stool","price":6},
	"Crafted table":{"cost":{"Timber":6,"Metal fittings":2},"seconds":9.0,"level":1,"asset":"Table_Large","price":16},
	"Supply crate":{"cost":{"Timber":4,"Metal fittings":1},"seconds":7.0,"level":0,"asset":"Crate_Wooden","price":8},
	"Repaired tools":{"cost":{"Timber":2,"Metal fittings":2},"seconds":8.0,"level":0,"asset":"Axe_Bronze","price":12}}
const PLACEABLES := {
	"Crafted stool":{"asset":"Stool","size":Vector3(.5,.52,.5)},
	"Crafted table":{"asset":"Table_Large","size":Vector3(1.8,.85,1)},
	"Supply crate":{"asset":"Crate_Wooden","size":Vector3(.65,.5,.55)},
	"Wooden bed":{"asset":"Bed_Twin1","size":Vector3(1.25,.6,2.15)}
}
var town: Node3D
var job: Dictionary={}
var restored_enabled:=true
var stock: Dictionary={}
var placed: Array=[]
var serial:=0
var status: Label
var cancel_button: Button
var tool: Node3D
func _ready() -> void:
	town=get_parent()
	var layer:=CanvasLayer.new();add_child(layer);status=Label.new();layer.add_child(status);status.position=Vector2(24,135)
	cancel_button=Button.new();cancel_button.text="Cancel crafting";cancel_button.position=Vector2(24,165)
	cancel_button.custom_minimum_size=Vector2(145,42);layer.add_child(cancel_button)
	cancel_button.pressed.connect(cancel);cancel_button.hide()
func near_bench() -> bool:
	for object in town.physical_gameplay.objects:
		if object.get_meta("activity","") in ["repair","furniture_repair"] and object.global_position.distance_to(town.player.global_position)<3.5:return true
	return false
func begin(item: String) -> bool:
	if not RECIPES.has(item) or not job.is_empty() or not near_bench():return false
	if town.physical_gameplay.get("carried") or town.physical_gameplay.get("mounted"):return false
	if town.physical_gameplay.get("busy")!=null and float(town.physical_gameplay.get("busy"))>0:return false
	var recipe: Dictionary=RECIPES[item]
	if town.character_life.skill_level("You","Carpentry")<int(recipe.level):return false
	for material in recipe.cost:
		if town.inventory_ui.amount(material)<int(recipe.cost[material]):return false
	if town.interface_ui.active:town.interface_ui.close()
	for material in recipe.cost:town.inventory_ui.change(material,-int(recipe.cost[material]))
	restored_enabled=town.player.enabled
	var point: Vector3=town.player.global_position
	job={"item":item,"remaining":recipe.seconds,"position":[point.x,point.y,point.z]}
	town.player.enabled=false;town.player.velocity=Vector3.ZERO
	show_work()
	town.inventory_ui.persist()
	return true
func cancel() -> void:
	if job.is_empty():return
	var item: String=job.item;job={}
	for material in RECIPES[item].cost:town.inventory_ui.change(material,int(RECIPES[item].cost[material]))
	town.player.enabled=restored_enabled;town.inventory_ui.persist()
	clear_work()
func _process(delta: float) -> void:
	if job.is_empty():return
	var point:=Vector3(job.position[0],job.position[1],job.position[2])
	if town.player.global_position.distance_to(point)>1.0 or not near_bench():cancel();return
	if town.player.animator.has_animation("RunnerWorking") and town.player.animator.current_animation!="RunnerWorking":
		town.player.animator.play("RunnerWorking",.15)
	job.remaining=maxf(0,float(job.remaining)-delta)
	if status:status.text="Crafting "+String(job.item)+" · %ds"%ceili(float(job.remaining))+(" · Esc to cancel" if not preload("res://mobile_runtime.gd").enabled() else "")
	if float(job.remaining)>0:return
	var item: String=job.item;job={};town.player.enabled=restored_enabled
	town.inventory_ui.change(item,1);town.character_life.gain_skill("You","Carpentry",10)
	town.inventory_ui.persist();town.economy.announce("Finished · "+item)
	clear_work()

func show_work() -> void:
	cancel_button.visible=preload("res://mobile_runtime.gd").enabled()
	if not town.player.animator.is_inside_tree():return
	var rig: Node=town.player.animator.get_node_or_null(town.player.animator.root_node)
	if not rig:return
	var rigs: Array[Node]=rig.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty() or rigs[0].find_bone("Wrist.R")<0:return
	var grip:=BoneAttachment3D.new();grip.bone_name="Wrist.R";rigs[0].add_child(grip)
	town.detailed_prop("Axe_Bronze",grip,Vector3(0,-.06,0),Vector3(.12,.33,.09),false)
	tool=grip

func clear_work() -> void:
	status.text="";cancel_button.hide()
	if is_instance_valid(tool):tool.queue_free()
	tool=null
func snapshot() -> Dictionary:return {"job":job.duplicate(true),"stock":stock.duplicate(true),"placed":placed.duplicate(true),"serial":serial}
func restore(data: Dictionary) -> void:
	clear_work()
	stock=data.get("stock",{});serial=maxi(0,int(data.get("serial",0)))
	for child in town.home_district.interior.get_children():
		if child.has_meta("crafted_id"):child.get_parent().remove_child(child);child.queue_free()
	placed.clear();job={}
	for record in data.get("placed",[]):
		if record is Dictionary:spawn_placed(record)
	var pending: Dictionary=data.get("job",{})
	if RECIPES.has(pending.get("item","")) and pending.get("position") is Array and pending.position.size()==3 and float(pending.get("remaining",-1))>=0:
		job=pending.duplicate(true);restored_enabled=true;town.player.enabled=false
		show_work()
func spawn_placed(record: Dictionary) -> Node3D:
	var item: String=record.get("item","")
	if not PLACEABLES.has(item) or not record.get("position") is Array or record.position.size()!=3:return null
	for value in record.position:
		if not (value is float or value is int) or not is_finite(float(value)):return null
	var parent: Node3D=town.home_district.interior
	var object:=StaticBody3D.new();parent.add_child(object);object.name="CraftedFurniture"+str(record.get("id",0));object.set_meta("crafted_id",int(record.get("id",0)))
	object.position=Vector3(record.position[0],record.position[1],record.position[2]);object.rotation.y=float(record.get("rotation",0))
	var size: Vector3=PLACEABLES[item].size
	town.detailed_prop(PLACEABLES[item].asset,object,Vector3.ZERO,size,false)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;collider.position.y=size.y/2;object.add_child(collider)
	if item=="Crafted stool":
		var seat:=Marker3D.new();object.add_child(seat);seat.position.y=size.y;seat.add_to_group("seats");seat.set_meta("player_owned",true)
	elif item=="Wooden bed":
		var bed:=Marker3D.new();object.add_child(bed)
		bed.name="Wooden bed";bed.position=Vector3(0,size.y,-.85)
		bed.add_to_group("beds");bed.set_meta("player_owned",true);bed.set_meta("resident_owner","PLAYER")
	placed.append(record.duplicate(true));return object
func place(item: String) -> bool:
	if not job.is_empty() or not PLACEABLES.has(item) or town.inventory_ui.amount(item)<1 or not town.home_district.inside:return false
	var point: Vector3=town.player.global_position-town.player.global_basis.z*1.8
	var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP*.6,1)
	var floor_hit:=town.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y<.8:return false
	point.y=floor_hit.position.y+.02
	var yaw: float = town.player.global_rotation.y
	var shape := BoxShape3D.new()
	shape.size = PLACEABLES[item].size + Vector3(.1,0,.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape;query.collision_mask = 3
	query.transform = Transform3D(Basis(Vector3.UP,yaw),point+Vector3.UP*(shape.size.y/2+.02))
	if not town.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	serial+=1
	var local: Vector3=town.home_district.interior.to_local(point)
	var record: Dictionary={"id":serial,"item":item,"position":[local.x,local.y,local.z],"rotation":yaw}
	if not spawn_placed(record):return false
	town.inventory_ui.change(item,-1);town.inventory_ui.persist();return true

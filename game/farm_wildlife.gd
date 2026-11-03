extends Node

var town: Node3D
var added: Array[Node]=[]

func _ready() -> void:
	town=get_parent()
	setup.call_deferred()

func setup() -> void:
	while get_tree().get_nodes_in_group("animals").size()<9:await get_tree().process_frame
	var paddocks={"Cow":Rect2(-56,-116,28,24),"Sheep":Rect2(-56,-116,28,24),"Horse":Rect2(30,-116,26,24),"Pig":Rect2(13,-121,15,18)}
	var counts: Dictionary={}
	for animal in get_tree().get_nodes_in_group("animals"):
		if not paddocks.has(animal.species):continue
		var index: int=counts.get(animal.species,0);counts[animal.species]=index+1
		var centre: Vector2=paddocks[animal.species].get_center()
		if animal.species=="Sheep":centre.y-=6
		animal.home=Vector3(centre.x+(index*3-2),.03,centre.y)
		animal.position=animal.home;animal.pasture=paddocks[animal.species]
		animal.radius=6 if animal.species!="Pig" else 3
		animal.pause=1.0+index;animal.target=animal.home
	for spec in [["Cow","cow_idle.glb",1.4,Vector3(-45,0,-107)],
		["Horse","horse_basemesh.glb",1.65,Vector3(45,0,-106)],
		["Sheep","sheep.glb",.85,Vector3(-47,0,-110)],
		["Sheep","",.82,Vector3(-42,0,-113)]]:
		var animal=load("res://animal.gd").new()
		animal.species=spec[0];animal.asset_path="res://animals/new/"+spec[1] if not String(spec[1]).is_empty() else "res://animals/Sheep.glb"
		animal.desired_height=spec[2];animal.pasture=paddocks[spec[0]]
		animal.home=spec[3]+Vector3.UP*.03;animal.position=animal.home;animal.radius=6;animal.pace=.65
		animal.name="Farm"+spec[1].get_basename() if not String(spec[1]).is_empty() else "FarmSheepCompanion"
		town.add_child(animal);added.append(animal)
	for rectangle: Rect2 in [paddocks.Cow,paddocks.Horse,paddocks.Pig]:build_fence(rectangle)
	for spec in [[Vector3(-43,0,-107),Vector3(23,3.6,19)],[Vector3(43,0,-105),Vector3(15,4.1,13)],[Vector3(20,0,-112),Vector3(13,3.1,12)]]:
		var shelter:=Node3D.new();town.add_child(shelter);shelter.position=spec[0]
		var size: Vector3=spec[1]
		town.box(shelter,Vector3(size.x,.2,size.z),Vector3(0,size.y,0),Color("67503b"),true)
		for x in [-size.x/2+.2,size.x/2-.2]:
			for z in [-size.z/2+.2,size.z/2-.2]:town.box(shelter,Vector3(.15,size.y,.15),Vector3(x,size.y/2,z),Color("6b5238"),false)
	for animal in get_tree().get_nodes_in_group("animals"):
		if paddocks.has(animal.species):animal.weather_shelter=true
	town.add_sign("ALDERWICK PASTURES",Vector3(-25,2,-88),PI,28)
	for index in range(5):
		var flock=load("res://sky_birds.gd").new()
		flock.asset_path="res://animals/new/birds.glb" if index<3 else "res://animals/new/model_110a_-_imperial_woodpecker_flying.glb"
		flock.centre=[Vector3(-45,0,-100),Vector3(-150,0,90),Vector3(225,0,20),Vector3(-75,0,-45),Vector3(225,0,-90)][index]
		flock.radius=35+index*9;flock.height=19+index*4;flock.phase=index*1.75
		flock.span=4.0 if index<3 else 1.1;flock.speed=.09+index*.012
		town.add_child(flock);added.append(flock)
	print("FARM_WILDLIFE_READY grounded_animals=13 flying_groups=5 pastures=true")

func build_fence(rectangle: Rect2) -> void:
	for x in range(int(rectangle.position.x),int(rectangle.end.x)+1,2):
		for z in [rectangle.position.y,rectangle.end.y]:
			if absf(x-rectangle.get_center().x)<2:continue
			town.model(town,"Prop_WoodenFence_Single",Vector3(x,0,z),0,false)
	for z in range(int(rectangle.position.y),int(rectangle.end.y)+1,2):
		for x in [rectangle.position.x,rectangle.end.x]:town.model(town,"Prop_WoodenFence_Single",Vector3(x,0,z),PI/2,false)

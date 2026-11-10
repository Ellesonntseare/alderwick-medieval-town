extends Node3D
var town: Node3D
var sites: Dictionary={}
var clock:=0.0
const PROJECTS={"castle_store":{"point":Vector3(124,.03,104),"asset":"Crate_Wooden","size":Vector3(.8,.65,.7),"title":"Castle dry store"},"castle_tools":{"point":Vector3(126,.03,104),"asset":"WeaponStand","size":Vector3(.9,1.3,.5),"title":"Castle tool station"},"industrial_bench":{"point":Vector3(10,.03,266),"asset":"Table_Large","size":Vector3(1.8,.85,1),"title":"Crew sorting table"}}
func _ready() -> void:
	town=get_parent();name="DistrictProjects"
	for id in PROJECTS:
		var data: Dictionary=PROJECTS[id];var site:=Node3D.new();add_child(site);site.position=data.point
		# Reserve the same footprint before and after the project so completed
		# furniture never silently invalidates the walking geometry.
		var body:=StaticBody3D.new();site.add_child(body);var collision:=CollisionShape3D.new();body.add_child(collision);var shape:=BoxShape3D.new();shape.size=data.size;collision.shape=shape;collision.position.y=data.size.y/2
		var damaged:=Node3D.new();site.add_child(damaged)
		for index in range(3):town.box(damaged,Vector3(.8,.08,.18),Vector3(0,.15+index*.1,0),Color("725b40"),false).rotation.z=.12*(index-1)
		var finished:=Node3D.new();site.add_child(finished);town.detailed_prop(data.asset,finished,Vector3.ZERO,data.size,false);finished.hide()
		var label:=Label3D.new();site.add_child(label);label.position.y=data.size.y+.5;label.font_size=18;label.pixel_size=.004;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sites[id]={"damaged":damaged,"finished":finished,"label":label,"done":false}
	refresh()
func refresh() -> void:
	for id in sites:
		var done: bool=town.adventures.progress.get(id,{}).get("status","")=="complete"
		sites[id].damaged.visible=not done;sites[id].finished.visible=done;sites[id].done=done
		sites[id].label.text=PROJECTS[id].title+(" · in use" if done else " · awaiting repairs")
func _process(delta: float) -> void:
	clock+=delta
	if clock>.5:clock=0;refresh()

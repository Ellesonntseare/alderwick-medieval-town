extends "res://physical_gameplay_review.gd"

class Receiver extends CharacterBody3D:
	var person_name:="Receiving resident"
	var posture:="standing"
	var night_schedule:=false
	var talking:=false
	var carry_kind:=""
	var received_object: Node3D
	var visual:=Node3D.new()
	func ensure_carry_modifier() -> void:pass
	func prop_action_busy() -> bool:return false
	func begin_prop_gesture() -> bool:return true

class Crafting extends Node:
	var job: Dictionary={}

class Life extends Node:
	var active: CharacterBody3D
	var dialog: Panel

var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func run() -> void:
	var town:=Town.new();root.add_child(town)
	town.player=Player.new();town.add_child(town.player);town.player.add_child(town.player.animator)
	var library:=AnimationLibrary.new()
	for name in ["PickUp","Interact","Idle"]:
		var clip:=Animation.new();clip.length=2;library.add_animation(name,clip)
	town.player.animator.add_animation_library("",library)
	town.home_district=Home.new();town.add_child(town.home_district);town.home_district.add_child(town.home_district.interior)
	town.character_life=Sim.new();town.add_child(town.character_life)
	town.economy=Economy.new();town.add_child(town.economy)
	town.crafting=Crafting.new();town.add_child(town.crafting)
	town.life=Life.new();town.add_child(town.life);town.life.dialog=Panel.new();town.life.add_child(town.life.dialog)
	town.box(town,Vector3(150,.2,150),Vector3(0,-.1,0),Color.WHITE,true)
	var physical: Node3D=load("res://physical_gameplay.gd").new();town.physical_gameplay=physical;town.add_child(physical)
	await process_frame;await physics_frame;physical.set_physics_process(false)
	var crate: Node3D=physical.objects[0];town.player.position=crate.global_position+Vector3(0,0,1)
	var original:=crate.global_transform;var id: String=physical.object_id(crate)
	check(physical.find_object(id)==crate and id=="physical/vegetable_delivery_crate","Physical IDs must survive reparenting and use deterministic names")
	check(physical.pickup(crate),"Pickup action starts")
	physical._physics_process(.3)
	check(physical.carried==null and crate.get_parent()==physical,"Prop stays in the world before contact")
	physical.cancel_object_action()
	check(crate.global_transform==original and crate.collision_layer==1,"Cancelling before pickup contact preserves the original prop")
	check(physical.pickup(crate),"Cancelled pickup can be retried")
	physical._physics_process(.8)
	check(physical.carried==crate and crate.get_parent()==town.player and crate.collision_layer==0,"Contact attaches exactly the original prop")
	physical.cancel_object_action()
	check(physical.carried==crate and physical.find_object(id)==crate,"Cancelling after contact retains the carried original")
	town.player.position=Vector3(0,.1,0);await physics_frame
	physical.place();physical._physics_process(.2);physical.cancel_object_action()
	check(physical.carried==crate and crate.collision_layer==0,"Cancelling put-down before release retains the carried prop")
	physical.place()
	var blocker:=town.box(town,Vector3(.8,1,.8),physical.action_destination+Vector3.UP*.5,Color.WHITE,true)
	await physics_frame;physical._physics_process(1)
	check(physical.carried==crate and not physical.object_action.active,"A newly obstructed landing cancels release without losing the prop")
	blocker.get_parent().remove_child(blocker);blocker.queue_free();await physics_frame
	physical.place();physical._physics_process(1)
	check(physical.carried==null and crate.get_parent()==physical and crate.collision_layer==1,"Put-down releases at contact into the checked landing")
	physical.cancel_object_action()
	check(is_instance_valid(crate) and crate.get_parent()==physical,"Cancelling after release leaves the placed prop intact")
	check(physical.restore_carried(crate),"Session restoration can attach a prop without replaying pickup")
	var receiver:=Receiver.new();town.add_child(receiver);receiver.add_child(receiver.visual);receiver.add_to_group("villagers");receiver.position=Vector3(1.5,.1,0)
	check(physical.handover_target()==receiver and physical.hand_over(receiver),"Nearby available resident can receive an item")
	physical._physics_process(.3)
	check(physical.carried==crate and receiver.received_object==null,"Hand-over retains the player object before contact")
	receiver.position.x=8;physical._physics_process(.4)
	check(physical.carried==crate and receiver.received_object==null and not physical.object_action.active,"A departing recipient cancels the hand-over safely")
	receiver.position.x=1.5
	check(physical.hand_over(receiver),"Hand-over can be retried")
	physical._physics_process(.7)
	check(physical.carried==null and receiver.received_object==crate and crate.get_parent()==receiver and crate.get_meta("held_by","")==receiver.person_name,"Hand-over transfers the same prop exactly once at contact")
	physical.cancel_object_action()
	check(receiver.received_object==crate and physical.objects.count(crate)==1,"Cancelled follow-through cannot duplicate or remove the delivered object")
	check(physical.restore_carried(crate) and receiver.received_object==null,"Restoring player ownership clears the previous NPC holder")
	town.crafting.job={"recipe":"test"}
	physical.place();check(not physical.object_action.active and not physical.hand_over(receiver),"Active crafting blocks placement and hand-over")
	physical.restore_carried();check(not physical.pickup(crate),"Active crafting blocks pickup")
	town.crafting.job={};town.player.position=crate.position+Vector3(0,0,1)
	check(physical.pickup(crate),"Pickup resumes after crafting")
	town.player.enabled=false;physical._physics_process(.9)
	check(not physical.object_action.active and physical.carried==null,"Pausing before contact cancels the action safely")
	town.player.position=Vector3(0,.1,0);town.life.active=receiver;receiver.talking=true
	var delivered: Array[String]=[]
	var commit:=func() -> bool:delivered.append("Supply crate");return true
	check(physical.animate_inventory_handover(receiver,"Supply crate",commit),"A mission hand-over can start with dialogue movement disabled")
	await create_timer(.15).timeout
	check(town.player.animator.current_animation_position>.05 and not town.player.enabled,"Animation advances while the panel disables player movement")
	physical._physics_process(.2)
	check(delivered.is_empty() and is_instance_valid(physical.inventory_parcel),"Inventory delivery keeps the item and shows a parcel until contact")
	town.life.dialog.hide();physical._physics_process(.5)
	check(delivered.is_empty() and not physical.object_action.active and physical.inventory_parcel==null,"Closing the panel before contact leaves inventory intact and clears the parcel")
	town.life.dialog.show()
	check(physical.animate_inventory_handover(receiver,"Supply crate",commit),"The same mission can retry after closing and reopening the panel")
	physical._physics_process(.7)
	check(delivered.size()==1 and not town.player.enabled,"Contact commits once while the real dialogue remains open and movement stays disabled")
	physical._physics_process(.7)
	check(delivered.size()==1 and physical.inventory_parcel==null,"Follow-through cleans the parcel without a second inventory commit")
	check(physical.objects.count(crate)==1 and is_instance_valid(crate),"All transaction paths retain exactly one physical object")
	print("PHYSICAL_ACTIONS_REVIEW_COMPLETE failures=",failures," stable_id=",id," object_count=",physical.objects.size())
	quit(0 if failures.is_empty() else 1)

extends SceneTree

var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message)

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var a: CharacterBody3D=load("res://villager.gd").new()
	var b: CharacterBody3D=load("res://villager.gd").new()
	a.person_name="First resident"
	b.person_name="Second resident"
	stage.add_child(a)
	stage.add_child(b)
	a.set_physics_process(false)
	b.set_physics_process(false)
	b.position.x=1.5
	await physics_frame
	check(not a.has_conversation_partner(),"A solitary resident cannot speak socially")
	var lines: Array[String]=[]
	a.begin_social(b,10,lines)
	check(not a.has_conversation_partner(),"One-sided invitations cannot become conversations")
	b.begin_social(a,10,lines)
	check(a.has_conversation_partner() and b.has_conversation_partner(),"Two nearby consenting residents can converse")
	b.position.x=4
	check(not a.has_conversation_partner(),"A partner walking away ends the conversation")
	b.position.x=1.5
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(.2,2.5,2)
	shape.shape=box
	shape.position=Vector3(.75,1.0,0)
	wall.add_child(shape)
	stage.add_child(wall)
	await physics_frame
	check(not a.has_conversation_partner(),"A wall between residents prevents a conversation")
	a.bubble.show()
	b.bubble.show()
	a.end_social()
	check(a.social_partner==null and b.social_partner==null and not a.bubble.visible and not b.bubble.visible,"Ending a conversation clears both participants and bubbles")
	print("CONVERSATION_PARTNER_REVIEW_COMPLETE failures=",failures)
	quit(0 if failures.is_empty() else 1)

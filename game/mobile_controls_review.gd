extends SceneTree

class Player extends CharacterBody3D:
	var enabled:=true
	var resting:=""
	var jump_requested:=false
	var camera:=Camera3D.new()
	var arm:=Node3D.new()
class AI extends Node:
	var URL:=""
	func check_health() -> void:pass
class Life extends Node:
	var active: Node
	var nearest: Node
	var nearest_furniture: Node
	var nearest_door: Node
	var ai:=AI.new()
class Speech extends Node:
	var URL:=""
	func check_health() -> void:pass
class Town extends Node3D:
	var player:=Player.new()
	var life:=Life.new()
	var speech:=Speech.new()
	var menu_collapsed:=false
	var view_mode:=0
	var orbit:=0.0
	var adventures: Node
	func toggle_menu() -> void:menu_collapsed=not menu_collapsed
	func toggle_view() -> void:view_mode=(view_mode+1)%3
	func update_camera() -> void:pass

func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var mobile=load("res://mobile_runtime.gd").new();mobile.name="Mobile";root.add_child(mobile)
	var town:=Town.new();root.add_child(town);town.add_child(town.player)
	await mobile.attach(town)
	for frame in range(3):await process_frame
	assert(town.menu_collapsed)
	assert(mobile.actions.find_children("*","TouchScreenButton",true,false).size()==8)
	var origin: Vector2=mobile.joystick.global_position+Vector2(85,85)
	assert(origin.y>400 and origin.y<720)
	var down:=InputEventScreenTouch.new();down.index=0;down.pressed=true;down.position=origin;mobile._input(down)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=origin+Vector2(40,-40);mobile._input(drag)
	assert(mobile.move_axis.x>.3 and mobile.move_axis.y<-.3)
	# A second finger looks while the first remains on the joystick.
	var look:=InputEventScreenTouch.new();look.index=2;look.pressed=true;look.position=Vector2(800,230);mobile._input(look)
	var look_drag:=InputEventScreenDrag.new();look_drag.index=2;look_drag.position=Vector2(830,240);look_drag.relative=Vector2(30,10);mobile._input(look_drag)
	assert(mobile.move_axis.length()>.3 and town.player.rotation.y<0)
	var jump: TouchScreenButton=mobile.actions.get_node("Jump")
	var tap:=InputEventScreenTouch.new();tap.index=3;tap.pressed=true;tap.position=jump.global_position
	Input.parse_input_event(tap);await process_frame
	assert(town.player.jump_requested and mobile.move_axis.length()>.3)
	tap.pressed=false;Input.parse_input_event(tap);await process_frame
	look.pressed=false;mobile._input(look)
	down=InputEventScreenTouch.new();down.index=0;down.pressed=false;mobile._input(down)
	assert(mobile.move_axis==Vector2.ZERO)
	down=InputEventScreenTouch.new();down.index=1;down.pressed=true;down.position=Vector2(900,250);mobile._input(down)
	drag=InputEventScreenDrag.new();drag.index=1;drag.position=Vector2(930,260);drag.relative=Vector2(30,10);mobile._input(drag)
	assert(town.player.rotation.y<0)
	mobile.control_scale=1.35;mobile.layout_controls()
	await process_frame
	assert(mobile.actions.get_global_rect().position.x>0)
	assert(mobile.actions.get_global_rect().end.y<=721)
	mobile.move_axis=Vector2.ONE;mobile.look_touch=4;town.player.enabled=false
	mobile._input(drag)
	assert(mobile.move_axis==Vector2.ZERO and mobile.look_touch==-1)
	town.player.enabled=true
	mobile.control_scale=1.0;mobile.layout_controls()
	origin=mobile.joystick.global_position+Vector2(85,85)
	down=InputEventScreenTouch.new();down.index=0;down.pressed=true;down.position=origin;mobile._input(down)
	drag=InputEventScreenDrag.new();drag.index=0;drag.position=origin+Vector2(1,1);mobile._input(drag)
	assert(mobile.move_axis==Vector2.ZERO)
	mobile.reset_touches()
	var saved: String=mobile.endpoint;mobile.endpoint="http://192.168.1.5:34322/token/test-pair"
	assert(mobile.backend_url(34320)=="http://192.168.1.5:34322/token/test-pair/ai")
	assert(mobile.backend_url(34319).ends_with("/speech"));mobile.endpoint=saved
	if DisplayServer.get_name()!="headless":
		var background:=ColorRect.new();background.color=Color("23372d");background.size=Vector2(1280,720);root.add_child(background);root.move_child(background,0)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../android-touch-controls.png")
	print("MOBILE_CONTROLS_REVIEW_COMPLETE joystick=true touch_camera=true actions=true saved_endpoint_routing=true")
	town.life.ai.free();town.player.camera.free();town.player.arm.free();town.life.free();town.speech.free()
	quit()



extends SceneTree
class Life extends Node:
	var navigation_ready:=false
class Town extends "res://town.gd":
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
class Person extends Node3D:
	var talking:=false
	var night_schedule:=false
	var home_door: Node3D
	var label:=Label3D.new()
	var bubble:=Label3D.new()
	func _ready() -> void:add_child(label);add_child(bubble)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var town:=Town.new();root.add_child(town)
	town.menu_body=VBoxContainer.new();town.add_child(town.menu_body)
	town.life=Life.new();town.add_child(town.life)
	var performance=load("res://town_performance.gd").new()
	performance.save_path="user://review-graphics-settings.json";town.add_child(performance)
	assert(performance.mode.item_count==4)
	performance.choose_quality(0)
	assert(is_equal_approx(root.scaling_3d_scale,.6) and Engine.physics_ticks_per_second==30)
	performance.choose_quality(3)
	assert(is_equal_approx(root.scaling_3d_scale,1.0) and Engine.physics_ticks_per_second==60)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(performance.save_path))
	assert(saved.quality==3)
	performance.choose_quality(1,false)
	assert(is_equal_approx(root.scaling_3d_scale,.8))
	var camera:=Camera3D.new();town.add_child(camera);camera.current=true
	var front:=Person.new();town.add_child(front);front.position=Vector3(0,0,-25)
	var back:=Person.new();town.add_child(back);back.position=Vector3(0,0,25)
	for person in [front,back]:performance.actors[person]={"visual":person,"animator":null}
	performance._process(.31)
	assert(front.visible and not back.visible)
	back.talking=true;performance._process(.31)
	assert(back.visible)
	var animator:=AnimationPlayer.new();front.add_child(animator)
	var library:=AnimationLibrary.new();var clip:=Animation.new();clip.length=2;clip.loop_mode=Animation.LOOP_LINEAR
	library.add_animation("Walk",clip);animator.add_animation_library("",library);animator.play("Walk")
	performance.actors[front].animator=animator
	performance._process(.31)
	assert(animator.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
	var before:=animator.current_animation_position
	performance._process(.1)
	assert(animator.current_animation_position>before)
	front.talking=true;performance._process(.31)
	assert(animator.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE)
	front.talking=false
	town.overview=camera;town.view_mode=1;town.orbit=0;town.distance=25
	town.pan_overview(Vector2(-100,90))
	assert(town.overview_focus==Vector3(-100,0,90))
	assert(camera.global_position.distance_to(Vector3(-100,25,106.25))<.01)
	front.position=Vector3(-100,0,90);back.talking=false
	performance._process(.31)
	assert(front.visible and not back.visible)
	town.pan_overview(Vector2(10000,10000))
	assert(town.overview_focus==Vector3(9900,0,10090))
	print("GRAPHICS_SETTINGS_REVIEW_COMPLETE presets=4 saved=true native_ultra=true balanced=true")
	quit()

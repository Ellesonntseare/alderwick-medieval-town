extends Node3D

var door_name := "Door"
var width := 1.1
var height := 2.35
var depth := 0.18
var is_open := false
var open_angle := -1.65
var closed_angle := 0.0
var collider: CollisionShape3D
var tween: Tween

func get_closed_transform() -> Transform3D:
	var closed := transform
	closed.basis=Basis(Vector3.UP,closed_angle)
	return get_parent().global_transform*closed

func _ready() -> void:
	add_to_group("doors")
	closed_angle=rotation.y
	var body := StaticBody3D.new()
	add_child(body)
	collider=CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(width,height,depth)
	collider.shape=shape
	collider.position=Vector3(width/2,height/2,0)
	body.add_child(collider)

func toggle(player_position: Vector3) -> bool:
	var local := to_local(player_position)
	if is_open:
		# The leaf cannot close while the player is standing in its doorway.
		var closed_local := (global_transform * Transform3D(Basis(Vector3.UP,-(rotation.y-closed_angle)),Vector3.ZERO)).affine_inverse()*player_position
		if absf(closed_local.z)<0.65 and closed_local.x> -0.35 and closed_local.x<width+0.35:return false
	is_open=not is_open
	if tween and tween.is_running():tween.kill()
	collider.set_deferred("disabled",true)
	tween=create_tween()
	tween.tween_property(self,"rotation:y",closed_angle+(open_angle if is_open else 0.0),0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_open:tween.tween_callback(func():collider.set_deferred("disabled",false))
	return true

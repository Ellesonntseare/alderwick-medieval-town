extends "res://villager.gd"
var survey_origin:=Vector3.ZERO
var survey_target:=Vector3.ZERO
var survey_pause:=3.0

func plan() -> void:pass
func choose_next() -> void:pass

func _physics_process(delta: float) -> void:
	if life.town.day_night.night and not talking and assigned_bed and posture!="sleeping":sleep_at(assigned_bed)
	if not life.town.day_night.night and posture=="sleeping":stand_up(true)
	if posture=="sleeping":return
	if posture=="sitting":
		if animator.current_animation!="SitIdle" and not animator.is_playing():animator.play("SitIdle",.15)
		return
	if talking:rest(delta);animate("Interact")
	elif survey_pause>0:
		survey_pause-=delta;rest(delta);animate("WorkTable" if animator.has_animation("WorkTable") else "Idle")
		if survey_pause<=0:survey_target=survey_origin+Vector3(1.8 if destination%2==0 else -1.2,0,0);destination+=1
	else:
		var difference:=survey_target-position;difference.y=0
		if difference.length()<.2 or test_move(global_transform,difference.normalized()*.5):survey_pause=decision_rng.randf_range(6,12)
		else:move_direction(difference.normalized(),.65,delta)
	var camera:=get_viewport().get_camera_3d()
	label.visible=not talking and camera and camera.global_position.distance_to(position)<15
	label.text="Ansel · Surveyor"
	bubble.hide()

extends Node3D

var asset_path:="res://animals/new/birds.glb"
var centre:=Vector3.ZERO
var span:=5.0
var radius:=50.0
var height:=24.0
var speed:=.12
var phase:=0.0
var visual: Node3D
var travelled:=0.0
var previous:=Vector3.ZERO

func _ready() -> void:
	add_to_group("sky_birds")
	visual=load(asset_path).instantiate();add_child(visual)
	var bounds:=AABB();var first:=true
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if String(mesh.name).begins_with("Icosphere"):mesh.hide();continue
		var box: AABB=visual.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if first else bounds.merge(box);first=false
	var scale_factor:=span/maxf(bounds.size.x,maxf(bounds.size.z,.1))
	visual.scale=Vector3.ONE*scale_factor
	visual.position=-bounds.get_center()*scale_factor
	for animator in visual.find_children("*","AnimationPlayer",true,false):
		for clip in animator.get_animation_list():
			if clip=="RESET":continue
			animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
			animator.play(clip);animator.speed_scale=.85+fposmod(phase,.35);break
	previous=centre+Vector3(cos(phase)*radius,height,sin(phase)*radius*.65)
	position=previous

func _process(delta: float) -> void:
	phase+=speed*delta
	position=centre+Vector3(cos(phase)*radius,height+sin(phase*.63)*3.5,sin(phase)*radius*.65)
	var direction:=position-previous
	if direction.length()>.0001:
		rotation.y=atan2(direction.x,direction.z)
		rotation.z=sin(phase*.7)*.12
	travelled+=direction.length();previous=position

extends Node

var life: Node
var banner: Label
var markers: Array[Node3D]=[]
var labels: Array[Label3D]=[]

func _ready() -> void:
	life=get_parent()
	banner=Label.new();banner.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_size_override("font_size",20);banner.modulate=Color("ffe0a0")
	var column=life.dialog.get_child(0);column.add_child(banner);column.move_child(banner,1)
	for index in range(2):
		var marker:=Node3D.new();life.town.add_child(marker);markers.append(marker)
		var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=.36;mesh.outer_radius=.43;mesh.rings=16;mesh.ring_segments=12;ring.mesh=mesh
		var material:=StandardMaterial3D.new();material.albedo_color=Color("f6cf77");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=material;marker.add_child(ring)
		var label:=Label3D.new();label.position.y=2.25;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=25;label.pixel_size=.004;label.modulate=Color("ffe0a0");label.no_depth_test=false;marker.add_child(label);labels.append(label)
		marker.hide()

func _process(_delta: float) -> void:
	for marker in markers:marker.hide()
	if not life.active or not life.dialog.visible:return
	var members: Array=[]
	if not life.ai.group_members.is_empty():members.assign(life.ai.group_members)
	else:members.append(life.active)
	var recipient: Node=life.active
	if members.size()>1:
		var selected: int=life.ai.group_target.selected
		if selected>0:recipient=members[selected-1]
		elif is_instance_valid(life.ai.focused_person):recipient=life.ai.focused_person
		banner.text="Talking with "+members[0].person_name+" & "+members[1].person_name+"\n"+("Your message goes to "+recipient.person_name if selected>0 else "Either resident can answer")
	else:banner.text="Talking to "+recipient.person_name+" · "+recipient.occupation
	for index in range(mini(members.size(),markers.size())):
		var person: Node3D=members[index]
		if not is_instance_valid(person):continue
		markers[index].show();markers[index].global_position=person.global_position+Vector3.UP*.035
		labels[index].text="▼ "+person.person_name
		markers[index].scale=Vector3.ONE*(1.0 if person==recipient else .85)

func _exit_tree() -> void:
	for marker in markers:
		if is_instance_valid(marker):marker.queue_free()

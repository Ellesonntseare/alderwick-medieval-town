extends Node3D

var town: Node3D
var windows: Array[StandardMaterial3D]=[]
var lights: Array[OmniLight3D]=[]
var clock := 0.0
var night_glow := 0.0
var enabled_lights := 0

func _ready() -> void:
	town=get_parent()
	build()
	collect.call_deferred()

func glow(parent: Node3D,point: Vector3,angle: float,size: Vector2) -> void:
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=size
	pane.mesh=quad
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(1,0.65,0.25,0)
	material.emission_enabled=true
	material.emission=Color("ffb650")
	material.emission_energy_multiplier=0.8
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	pane.material_override=material
	parent.add_child(pane)
	pane.position=point
	pane.rotation.y=angle
	pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	windows.append(material)

func build() -> void:
	for house: Node3D in get_tree().get_nodes_in_group("enterable_houses"):
		for child in house.get_children():
			if not child.is_in_group("doors"):continue
			var closed: Transform3D=child.get_closed_transform()
			var point: Vector3=closed*Vector3(-0.3,1.75,-0.18)
			town.box(self,Vector3(0.23,0.34,0.20),point,Color("4b3926"),false)
			glow(self,point+closed.basis*Vector3(0,0,-0.111),child.global_rotation.y,Vector2(0.15,0.22))
			var lantern := OmniLight3D.new()
			add_child(lantern)
			lantern.position=point+closed.basis*Vector3(0,0,-0.3)
			lantern.light_color=Color("ffc47a")
			lantern.light_energy=0.0
			lantern.omni_range=5
			lantern.set_meta("night_lantern",true)
			for step in range(3):
				var stone: Vector3=closed*Vector3(child.width/2,-0.015,-0.55-step*0.6)
				var paving: MeshInstance3D=town.box(self,Vector3(1.45,0.035,0.52),stone,Color("8a816b"),false)
				paving.rotation.y=child.global_rotation.y
		if house.has_meta("modular_house"):
			var width: float=house.get_meta("width")
			var depth: float=house.get_meta("depth")
			glow(house,Vector3(-width/2+1,1.55,-depth/2-0.055),0,Vector2(0.65,0.8))
			glow(house,Vector3(width/2+0.055,1.55,-depth/2+1),PI/2,Vector2(0.65,0.8))
	for spec in [[Vector3(-80,0,4),"Western village ←"],[Vector3(80,0,7),"Castle road →"],[Vector3(80,0,82),"Castle XIX →"],[Vector3(-84,0,93),"Market & homes ←"]]:
		town.box(self,Vector3(0.13,2.5,0.13),spec[0]+Vector3.UP*1.25,Color("63472e"),false)
		town.box(self,Vector3(3.0,0.55,0.15),spec[0]+Vector3.UP*2.1,Color("72583b"),false)
		town.add_sign(spec[1],spec[0]+Vector3(0,2.1,0.09),0,21)

func collect() -> void:
	lights.clear()
	for light: Node in town.find_children("*","OmniLight3D",true,false):
		light.shadow_enabled=false
		if not light.has_meta("base_energy"):light.set_meta("base_energy",light.light_energy)
		lights.append(light)

func _process(delta: float) -> void:
	if not town.day_night:return
	var target := 1.0 if town.day_night.night else 0.0
	night_glow=move_toward(night_glow,target,delta*0.6)
	for material in windows:material.albedo_color.a=night_glow*0.88
	clock+=delta
	if clock<0.35:return
	clock=0
	var camera := get_viewport().get_camera_3d()
	if not camera:return
	var eye := camera.global_position
	lights.sort_custom(func(a: OmniLight3D,b: OmniLight3D):return eye.distance_squared_to(a.global_position)<eye.distance_squared_to(b.global_position))
	enabled_lights=0
	for light in lights:
		var near: bool=eye.distance_squared_to(light.global_position)<65.0*65.0 and enabled_lights<12
		light.visible=near
		if light.has_meta("night_lantern"):light.light_energy=night_glow*1.8
		elif light.is_in_group("interior_lamps"):light.light_energy=float(light.get_meta("base_energy"))*lerpf(0.5,1.0,night_glow)
		if near:enabled_lights+=1

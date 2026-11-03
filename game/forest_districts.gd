extends Node3D

var patches: Array[Node3D]=[]
var tree_count := 0
var layout: Dictionary
var extended_view := false

func _ready() -> void:
	name="WalkableWoodlands"
	layout=JSON.parse_string(FileAccess.get_file_as_string("res://downloaded/forest/layout.json"))
	var source: PackedScene=load("res://downloaded/forest/woodland_patch.glb")
	var positions := [Vector3(-100,0,-145),Vector3(-64,0,-145),Vector3(-28,0,-145),Vector3(8,0,-145),Vector3(44,0,-145),
		Vector3(155,0,-145),Vector3(191,0,-145),Vector3(227,0,-145),Vector3(263,0,-145),Vector3(299,0,-145),
		Vector3(335,0,-109),Vector3(335,0,-73),Vector3(335,0,-37),Vector3(335,0,-1),Vector3(335,0,35),Vector3(335,0,71),Vector3(335,0,107),
		Vector3(155,0,150),Vector3(191,0,150),Vector3(227,0,150),Vector3(263,0,150),Vector3(299,0,150),
		Vector3(-20,0,120),Vector3(20,0,120),Vector3(-56,0,120),Vector3(56,0,120),Vector3(-20,0,156),Vector3(20,0,156),Vector3(-56,0,192),Vector3(56,0,192),
		Vector3(-300,0,74),Vector3(-300,0,110),Vector3(-264,0,210),Vector3(-228,0,210),Vector3(-192,0,210),Vector3(-156,0,210),Vector3(-120,0,210)]
	for index in range(positions.size()):
		var rectangle := Rect2(Vector2(positions[index].x-16,positions[index].z-16),Vector2(32,32))
		var protected := false
		for site in get_parent().chateaux.sites:
			if rectangle.intersects(site.rect.grow(5)):protected=true;break
		if protected:continue
		var patch := Node3D.new()
		patch.name="Woodland_"+str(index+1)
		patch.position=positions[index]
		patch.rotation.y=(index%4)*PI/2
		add_child(patch)
		patch.add_to_group("woodland_patches")
		var visual := source.instantiate() as Node3D
		patch.add_child(visual)
		for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end=90 if String(mesh.name).begins_with("ForestUnderstory") else 340
			mesh.visibility_range_end_margin=25
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(mesh.name).begins_with("ForestGround"):
				mesh.create_trimesh_collision()
				var original := mesh.get_active_material(0) as StandardMaterial3D
				if original and original.albedo_texture:
					var earth := ShaderMaterial.new()
					earth.shader=preload("res://forest_ground.gdshader")
					earth.set_shader_parameter("ground_texture",original.albedo_texture)
					earth.set_shader_parameter("ground_tint",original.albedo_color)
					earth.set_shader_parameter("half_size",Vector2(layout.width/2,layout.depth/2))
					mesh.material_override=earth
			if not String(mesh.name).begins_with("ForestFoliage") and not String(mesh.name).begins_with("ForestUnderstory"):continue
			for surface in range(mesh.mesh.get_surface_count()):
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if not original:continue
				var material := original.duplicate() as StandardMaterial3D
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold=.35
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				material.roughness=1
				mesh.set_surface_override_material(surface,material)
		var trunks := StaticBody3D.new()
		patch.add_child(trunks)
		for tree in layout.trunks:
			var collision := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius=tree.radius
			shape.height=maxf(.3,tree.height)
			collision.shape=shape
			collision.position=Vector3(tree.x,tree.y+shape.height/2,tree.z)
			trunks.add_child(collision)
		patches.append(patch)
		tree_count+=layout.trees
	print("WALKABLE_WOODLANDS_READY patches=",patches.size()," trees=",tree_count," ground_edges_blended=true leaf_collision=false")

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var extended: bool=get_parent().get("view_mode")==1 or (camera and camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
	if extended==extended_view:return
	extended_view=extended
	for patch in patches:
		for mesh: MeshInstance3D in patch.find_children("*","MeshInstance3D",true,false):
			if String(mesh.name).begins_with("ForestUnderstory"):continue
			mesh.visibility_range_end=250 if extended else 180

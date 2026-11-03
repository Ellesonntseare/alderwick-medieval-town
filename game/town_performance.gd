extends Node

const Phone=preload("res://mobile_runtime.gd")

var town: Node3D
var clock:=0.0
var visuals: Array[MeshInstance3D]=[]
var actors: Dictionary={}
var mode: OptionButton
var smooth:=true
var stats_clock:=0.0
var quality:=1
var frame_label: Label
var save_path:="user://graphics-settings.json"

func _ready() -> void:
	town=get_parent()
	mode=OptionButton.new()
	for label in ["Quality · Performance","Quality · Balanced","Quality · High","Quality · Ultra"]:mode.add_item(label)
	mode.tooltip_text="Performance: lower resolution and distant detail. Balanced: moderate detail. High: native resolution. Ultra: longest view distance and full animation."
	mode.item_selected.connect(choose_quality)
	town.menu_body.add_child(mode)
	frame_label=Label.new();town.menu_body.add_child(frame_label)
	if Phone.enabled():quality=0
	if FileAccess.file_exists(save_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:quality=clampi(int(saved.get("quality",1)),0,3)
	mode.select(quality);choose_quality(quality,false)
	collect.call_deferred()

func collect() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	batch_house_surfaces()
	for mesh: MeshInstance3D in town.find_children("*","MeshInstance3D",true,false):
		if mesh.skin:continue
		if mesh.mesh==null:continue
		var box: AABB=mesh.global_transform*mesh.get_aabb()
		var extent:=box.size.length()
		if extent>200:continue
		visuals.append(mesh)
		mesh.set_meta("performance_original_range",mesh.visibility_range_end)
		mesh.set_meta("performance_original_shadow",mesh.cast_shadow)
		mesh.set_meta("performance_extent",extent)
	for person in town.life.people:
		actors[person]={"animator":person.animator,"visual":person.visual,"visible":true}
	for light: OmniLight3D in town.find_children("*","OmniLight3D",true,false):
		light.distance_fade_enabled=true
		light.distance_fade_begin=22
		light.distance_fade_length=10
		light.shadow_enabled=false
	apply_ranges()
	print("TOWN_PERFORMANCE_READY static_meshes=",visuals.size()," actors=",actors.size())

func set_quality(value: bool) -> void:
	choose_quality(0 if value else 2)

func choose_quality(index: int,persist:=true) -> void:
	quality=clampi(index,0,3);smooth=quality<2
	Engine.physics_ticks_per_second=30 if quality<2 else 60
	Engine.max_fps=60 if quality<3 else 120
	get_viewport().scaling_3d_scale=[.60,.80,1.0,1.0][quality]
	get_viewport().mesh_lod_threshold=[5.0,3.0,1.0,.5][quality]
	if persist:
		var file:=FileAccess.open(save_path,FileAccess.WRITE)
		if file:file.store_string(JSON.stringify({"version":1,"quality":quality}))
	apply_ranges()

func batch_house_surfaces() -> void:
	var source_count:=0
	var batch_count:=0
	for house in get_tree().get_nodes_in_group("enterable_houses"):
		if not house.get_meta("modular_house",false):continue
		var groups: Dictionary={}
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible or mesh.skin or not mesh.mesh:continue
			var current: Node=mesh
			var architecture:=true
			var movable:=false
			while current!=house and current:
				var label:=String(current.name)
				if label.begins_with("Wall_") or label.begins_with("Floor_") or label.begins_with("Window_"):architecture=true
				if current.is_in_group("doors") or label.contains("Roof"):movable=true
				current=current.get_parent()
			if not architecture or movable:continue
			for surface in range(mesh.mesh.get_surface_count()):
				var material: Material=mesh.get_active_material(surface)
				if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
				var key: String=str(material.get_instance_id()) if material else "none"
				if material is StandardMaterial3D:
					key=str([material.albedo_color,material.albedo_texture,material.vertex_color_use_as_albedo,material.roughness,material.metallic,material.cull_mode,material.shading_mode,material.normal_enabled,material.normal_texture,material.uv1_scale,material.emission_enabled,material.emission])
				if not groups.has(key):groups[key]={"tool":SurfaceTool.new(),"material":material,"sources":[]}
				var group: Dictionary=groups[key]
				if group.sources.is_empty():group.tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				group.tool.append_from(mesh.mesh,surface,house.global_transform.affine_inverse()*mesh.global_transform)
				group.sources.append(mesh)
		for group in groups.values():
			if group.sources.size()<2:continue
			group.tool.set_material(group.material)
			var combined:=MeshInstance3D.new();combined.name="BatchedWallsAndFloors"
			combined.mesh=group.tool.commit();house.add_child(combined)
			for mesh in group.sources:mesh.hide();mesh.set_meta("performance_batched",true)
			source_count+=group.sources.size();batch_count+=1
	print("HOUSE_RENDER_BATCHES source_surfaces=",source_count," batches=",batch_count)

func apply_ranges() -> void:
	for mesh in visuals:
		if not is_instance_valid(mesh):continue
		var extent: float=mesh.get_meta("performance_extent",1.0)
		if quality<3:
			var multiplier: float=[.75,1.0,1.6][quality]
			mesh.visibility_range_end=(40 if extent<2.5 else 85 if extent<12 else 180)*multiplier
			mesh.visibility_range_end_margin=8
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mesh.visibility_range_end=mesh.get_meta("performance_original_range",0.0)
			mesh.cast_shadow=mesh.get_meta("performance_original_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _process(delta: float) -> void:
	clock+=delta;stats_clock+=delta
	if clock<.3:return
	clock=0
	var camera:=get_viewport().get_camera_3d()
	if not camera:return
	var overview: bool=town.view_mode==1 or (town.builder and town.builder.active)
	for person in actors:
		if not is_instance_valid(person):continue
		var record: Dictionary=actors[person]
		var distance: float=camera.global_position.distance_to(person.global_position)
		var visible: bool=quality==3 or distance<[35,50,85,1000][quality] or person.talking or overview
		record.visual.visible=visible
		# Keep routines, movement, collision and conversations running. Only the
		# costly skin/animation evaluation sleeps when its model cannot be seen.
		if record.animator:record.animator.active=visible
		person.set_meta("performance_far",smooth and not person.talking and distance>35)
		if not visible:person.label.hide();person.bubble.hide()
	if stats_clock>10:
		stats_clock=0
		print("TOWN_PERF fps=",Engine.get_frames_per_second()," frame_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if frame_label:frame_label.text="%d FPS · %s"%[Engine.get_frames_per_second(),["Performance","Balanced","High","Ultra"][quality]]


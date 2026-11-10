extends Node

const Phone=preload("res://mobile_runtime.gd")

var town: Node3D
var clock:=0.0
var visuals: Array[MeshInstance3D]=[]
var actors: Dictionary={}
var mode: OptionButton
var smooth:=true
var stats_clock:=0.0
var sample_time:=0.0
var sample_frames:=0
var quality:=0
var frame_label: Label
var save_path:="user://graphics-settings.json"
var decorations=preload("res://static_decoration_batches.gd").new()
var primitive_scenery=preload("res://static_primitive_batches.gd").new()

func _ready() -> void:
	town=get_parent()
	mode=OptionButton.new()
	for label in ["Quality · Performance","Quality · Balanced","Quality · High","Quality · Ultra"]:mode.add_item(label)
	mode.tooltip_text="Performance: lower resolution and distant detail. Balanced: moderate detail. High: native resolution. Ultra: longest view distance and full animation."
	mode.item_selected.connect(choose_quality)
	town.menu_body.add_child(mode)
	frame_label=Label.new();town.menu_body.add_child(frame_label)
	if Phone.enabled():quality=0
	var migrate_settings := false
	if FileAccess.file_exists(save_path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if saved is Dictionary:
			quality=clampi(int(saved.get("quality",1)),0,3)
			migrate_settings=int(saved.get("version",1))<3
			if migrate_settings:quality=0
	mode.select(quality);choose_quality(quality,migrate_settings)
	collect.call_deferred()

func collect() -> void:
	while not town.life.navigation_ready:await get_tree().process_frame
	await batch_house_surfaces()
	decorations.build(town)
	primitive_scenery.build(town)
	var walking_world := town.get_world_3d()
	for mesh: MeshInstance3D in town.find_children("*","MeshInstance3D",true,false):
		# The map owns an independent world with an overhead camera. Its scenery
		# must keep its own visibility rules even when created before collection.
		if mesh.get_world_3d() != walking_world:continue
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
		actors[person]={"animator":person.animator,"visual":person.visual,"visible":true,"animation_step":0.0,"animation_clock":0.0,"animation_mode":person.animator.callback_mode_process if person.animator else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE}
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
	if mode:mode.select(quality)
	Engine.physics_ticks_per_second=30 if quality<2 else 60
	Engine.max_fps=60 if quality<3 else 120
	if Phone.enabled():Engine.max_fps=30 if quality==0 else 45 if quality==1 else 60
	get_viewport().scaling_3d_scale=[.60,.80,1.0,1.0][quality]
	get_viewport().mesh_lod_threshold=[5.0,3.0,1.0,.5][quality]
	if Phone.enabled() and quality<2:get_viewport().scaling_3d_scale=[.78,.90][quality]
	sample_time=0;sample_frames=0
	if persist:
		var file:=FileAccess.open(save_path,FileAccess.WRITE)
		if file:file.store_string(JSON.stringify({"version":3,"quality":quality}))
	apply_ranges()

func batch_house_surfaces() -> void:
	var source_count:=0
	var batch_count:=0
	for house in get_tree().get_nodes_in_group("enterable_houses"):
		if not house.get_meta("modular_house",false):continue
		if Phone.enabled():await get_tree().process_frame
		var groups: Dictionary={}
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible or mesh.skin or not mesh.mesh:continue
			var current: Node=mesh
			var architecture:=false
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
	decorations.apply_quality(quality)
	primitive_scenery.apply_quality(quality)
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
	var trace := preload("res://frame_costs.gd").begin()
	update_performance(delta)
	preload("res://frame_costs.gd").finish("town_performance._process",trace)

func update_performance(delta: float) -> void:
	for person in actors:
		if not is_instance_valid(person):continue
		var record: Dictionary=actors[person]
		var step: float=record.get("animation_step",0.0)
		if step<=0 or not record.animator or not record.animator.active:continue
		record.animation_clock=float(record.get("animation_clock",0.0))+delta
		if record.animation_clock>=step:
			record.animator.advance(record.animation_clock)
			record.animation_clock=0.0
	if Phone.enabled() and quality<2 and delta<.4:
		sample_time+=delta;sample_frames+=1
		if sample_time>=4:
			var fps:=sample_frames/sample_time
			var target:=float(Engine.max_fps)
			var scale_now:=get_viewport().scaling_3d_scale
			if fps<target*.90:scale_now-=.06
			elif fps>=target*.98:scale_now+=.03
			get_viewport().scaling_3d_scale=clampf(scale_now,[.60,.70][quality],[.86,1.0][quality])
			sample_time=0;sample_frames=0
	clock+=delta;stats_clock+=delta
	if clock<.3:return
	clock=0
	var camera:=get_viewport().get_camera_3d()
	if not camera:return
	var frustum: Array[Plane]=camera.get_frustum()
	var overview_mode: bool=town.view_mode==1
	for person in actors:
		if not is_instance_valid(person):continue
		var record: Dictionary=actors[person]
		var distance: float=camera.global_position.distance_to(person.global_position)
		var activity_distance: float=distance
		if overview_mode:activity_distance=town.overview_focus.distance_to(person.global_position)
		var actor_radius: float=[35,50,85,150][quality]
		if overview_mode:actor_radius=maxf(actor_radius,minf(140,town.distance*.9))
		var visible: bool=activity_distance<actor_radius or person.talking
		if visible and distance>10 and not person.talking:
			for plane in frustum:
				if plane.distance_to(person.global_position+Vector3.UP) > 2.0:
					visible=false
					break
		if Phone.enabled() and quality<2:visible=visible and (activity_distance<(22 if quality==0 else 35) or person.talking)
		if Phone.enabled() and distance>8 and not person.talking and camera.is_position_behind(person.global_position):visible=false
		record.visual.visible=visible
		# Keep routines, movement, collision and conversations running. Only the
		# costly skin/animation evaluation sleeps when its model cannot be seen.
		if record.animator:
			record.animator.active=visible
			var detailed: bool=quality>=2 or person.talking or distance<18
			record["animation_step"]=0.0 if detailed or not visible else 1.0/(12.0 if quality==0 else 20.0)
			record.animator.callback_mode_process=record.get("animation_mode",AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE) if detailed or not visible else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if detailed:record["animation_clock"]=0.0
		person.set_meta("performance_far",smooth and not person.talking and distance>18)
		var at_door: bool=person.night_schedule and is_instance_valid(person.home_door) and person.global_position.distance_to(person.home_door.global_position)<5
		person.set_meta("simulation_interval",.1 if quality<2 and not visible and not person.talking and not at_door else 0.0)
		if not visible:person.bubble.hide()
	if stats_clock>10:
		stats_clock=0
		print("TOWN_PERF fps=",Engine.get_frames_per_second()," frame_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," physics_ms=",Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if frame_label:frame_label.text="%d FPS · %s"%[Engine.get_frames_per_second(),["Performance","Balanced","High","Ultra"][quality]]


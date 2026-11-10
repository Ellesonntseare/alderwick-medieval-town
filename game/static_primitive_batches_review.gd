extends SceneTree

const Batcher = preload("res://static_primitive_batches.gd")
var failures: Array[String] = []
var plants: Array[MeshInstance3D] = []

func _initialize() -> void:run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:failures.append(message);push_error(message)

func box(parent: Node3D, point: Vector3, tint := Color("718248")) -> MeshInstance3D:
	var source := MeshInstance3D.new()
	var mesh := BoxMesh.new();mesh.size = Vector3(.2, .5, .2)
	var material := StandardMaterial3D.new();material.albedo_color = tint;material.roughness = .9
	source.mesh = mesh;source.material_override = material
	parent.add_child(source);source.position = point
	return source

func run() -> void:
	var town := Node3D.new();root.add_child(town)
	# Same independently allocated crop geometry/materials as Town.town().
	for patch_x in [-35.0, 32.0]:
		for row in range(5):
			for plant in range(12):plants.append(box(town, Vector3(patch_x - 4.5 + plant * .8, .25, 38 + row * 1.5)))
	# Collision children are retained, and moving the entire town still works.
	var body := StaticBody3D.new();plants[0].add_child(body)
	var shape := CollisionShape3D.new();shape.shape = BoxShape3D.new();body.add_child(shape)
	var excluded: Array[MeshInstance3D] = []
	for label in ["door", "editor", "garden", "roof", "actor"]:
		var owner := Node3D.new();owner.name = label;town.add_child(owner)
		if label == "door":owner.add_to_group("doors")
		if label == "editor":owner.set_meta("build_id", "review")
		excluded.append(box(owner, Vector3.ZERO))
		excluded.append(box(owner, Vector3.ONE))
	var marked := box(town, Vector3(0, 0, 0));marked.set_meta("future_trade_item", true);excluded.append(marked)
	var grouped := box(town, Vector3(1, 0, 0));grouped.add_to_group("seats");excluded.append(grouped)
	var hidden := box(town, Vector3(2, 0, 0));hidden.hide()
	var alpha := box(town, Vector3(3, 0, 0));alpha.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;excluded.append(alpha)
	var overlay := box(town, Vector3(4, 0, 0));overlay.material_overlay = StandardMaterial3D.new();excluded.append(overlay)
	var custom_bounds := box(town, Vector3(5, 0, 0));custom_bounds.custom_aabb = AABB(-Vector3.ONE, Vector3.ONE * 2);excluded.append(custom_bounds)
	var top := box(town, Vector3(6, 0, 0));top.top_level = true;excluded.append(top)
	var animated := box(town, Vector3(7, 0, 0));animated.add_child(AnimationPlayer.new());excluded.append(animated)
	# Nearly identical floats must not collapse to the same text fingerprint.
	var precise_a := box(town, Vector3(1, 0, -1))
	var precise_b := box(town, Vector3(2, 0, -1))
	precise_a.material_override.roughness = .9000001
	precise_b.material_override.roughness = .9000002
	excluded.append(precise_a);excluded.append(precise_b)
	# Matching meshes with different flags / different UVs / different colours
	# each get their own local group, never a representative's changed appearance.
	for variation in range(4):
		for index in range(2):
			var mesh := box(town, Vector3(2 + index, 1, -4))
			if variation == 1:mesh.layers = 2
			if variation == 2:mesh.material_override.uv1_scale = Vector3(2, 1, 1)
			if variation == 3:mesh.material_override.albedo_color = Color("934b30")
	var before_image: Image
	var before_draws := 0
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(800, 600)
		var camera := Camera3D.new();town.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 12
		camera.position = Vector3(-35, 8, 49);camera.look_at(Vector3(-35, .25, 41));camera.current = true
		var environment := WorldEnvironment.new();town.add_child(environment)
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("314330")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 1
		before_image = await capture("res://../review/primitive-crops-before.png")
		before_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var batcher := Batcher.new();batcher.build(town)
	check(batcher.source_count == 128, "120 crops and eight matching test boxes must batch")
	check(batcher.batches.size() == 8, "Four bounded crop cells plus four distinct render/material groups")
	for source in plants:check(not source.visible and source.has_meta("performance_batched"), "Crop rendered exactly once")
	for source in excluded:check(source.visible and not source.has_meta("performance_batched"), "Independent/dynamic source remains separate")
	check(not hidden.visible and not hidden.has_meta("performance_batched"), "Hidden object stays hidden")
	check(is_instance_valid(body) and body.get_parent() == plants[0] and shape.shape != null, "Source collisions retained")
	var count := batcher.source_count;batcher.build(town)
	check(batcher.source_count == count, "Repeated collection is idempotent")
	var material_variations: Dictionary = {}
	for batch in batcher.batches:
		check(batch.multimesh.custom_aabb.size.x < 16 and batch.multimesh.custom_aabb.size.z < 16, "Local culling bounds")
		check(batch.position.length() > 0, "Batch origin belongs to its own cell")
		check(batch.multimesh.mesh.get_surface_count() == 1, "Geometry retains its surface")
		if batch.position.z < 0:material_variations[str([batch.layers, batch.material_override.uv1_scale, batch.material_override.albedo_color])] = true
		if DisplayServer.get_name() != "headless":
			for index in range(batch.multimesh.instance_count):
				var point: Vector3 = (batch.global_transform * batch.multimesh.get_instance_transform(index)).origin
				var found := false
				for source in plants:found = found or point.is_equal_approx(source.global_position)
				check(found or point.z < 0, "Actual renderer retains every crop transform")
	check(material_variations.size() == 4, "Different layers, UVs and colours preserved")
	for quality in range(4):
		batcher.apply_quality(quality)
		for batch in batcher.batches:
			var padding: float = batch.get_meta("range_padding")
			var base_range: float = [30.0, 40.0, 64.0, 0.0][quality]
			check(is_equal_approx(batch.visibility_range_end, base_range + (padding if quality < 3 else 0)), "Source-size visibility preserved without losing nearest detail")
			check(batch.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality == 3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "Quality shadow policy restored")
	if before_image:
		var after_image: Image = await capture("res://../review/primitive-crops-after.png")
		var before_bytes := before_image.get_data()
		var after_bytes := after_image.get_data()
		var changed_pixels := 0
		for pixel in range(0, before_bytes.size(), 4):
			if absi(before_bytes[pixel] - after_bytes[pixel]) > 3 or absi(before_bytes[pixel + 1] - after_bytes[pixel + 1]) > 3 or absi(before_bytes[pixel + 2] - after_bytes[pixel + 2]) > 3:changed_pixels += 1
		check(changed_pixels < before_image.get_width() * before_image.get_height() * .01, "Crop render retains appearance")
		print("PRIMITIVE_RENDER_COMPARISON before_draws=", before_draws, " after_draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " changed_pixels=", changed_pixels)
	var old_origin: Vector3 = batcher.batches[0].global_position
	town.position = Vector3(100, 0, 90)
	check(batcher.batches[0].global_position.is_equal_approx(old_origin + town.position), "Owner transform preserved")
	town.hide()
	check(not batcher.batches[0].is_visible_in_tree(), "Owner visibility preserved")
	print("STATIC_PRIMITIVE_REVIEW_COMPLETE failures=", failures, " sources=", batcher.source_count, " batches=", batcher.batches.size(), " crop_draws=120->4 geometry_unchanged=true collisions_retained=true")
	quit(0 if failures.is_empty() else 1)

func capture(path: String) -> Image:
	for frame in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8);result.save_png(path)
	return result

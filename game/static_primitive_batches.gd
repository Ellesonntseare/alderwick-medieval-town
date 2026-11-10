extends RefCounted

# The original town generator places these fixed boxes directly under Town.
# Do not recurse: children of scripts, houses, gardens, doors and editor roots
# can move or change visibility independently. Their existing nodes stay intact.
const CELL_SIZE := 16.0
const RENDER_PROPERTIES := ["layers", "cast_shadow", "extra_cull_margin", "gi_mode",
	"ignore_occlusion_culling", "transparency", "lod_bias", "sorting_offset",
	"sorting_use_aabb_center", "visibility_range_begin", "visibility_range_end",
	"visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode"]
var batches: Array[MultiMeshInstance3D] = []
var source_count := 0

func build(town: Node3D) -> void:
	var groups: Dictionary = {}
	var fingerprints: Dictionary = {}
	for child in town.get_children():
		if not eligible(child):continue
		var source: MeshInstance3D = child
		var material: Material = source.get_active_material(0)
		var state: Array = []
		for property in RENDER_PROPERTIES:state.append(source.get(property))
		var cell := Vector3i(floori(source.position.x / CELL_SIZE), floori(source.position.y / CELL_SIZE), floori(source.position.z / CELL_SIZE))
		var key := var_to_bytes([cell, fingerprint(source.mesh, fingerprints), fingerprint(material, fingerprints), state]).hex_encode()
		if not groups.has(key):groups[key] = []
		groups[key].append(source)
	for sources: Array in groups.values():
		if sources.size() < 2:continue
		create_batch(town, sources)
	print("STATIC_PRIMITIVE_BATCHES sources=", source_count, " batches=", batches.size())

func eligible(node: Node) -> bool:
	if not node is MeshInstance3D:return false
	var source: MeshInstance3D = node
	if not source.mesh is BoxMesh or source.skin or not source.is_visible_in_tree():return false
	if source.get_script() or not source.get_groups().is_empty() or not source.get_meta_list().is_empty():return false
	if source.material_overlay or source.transparency != 0 or source.top_level:return false
	if not source.custom_aabb.size.is_zero_approx() or not source.visibility_parent.is_empty():return false
	if not RenderingServer.instance_geometry_get_shader_parameter_list(source.get_instance()).is_empty():return false
	for child in source.get_children():
		if not child is StaticBody3D:return false
	var material := source.get_active_material(0)
	return material is StandardMaterial3D and not material.get_script() and material.next_pass == null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED

func fingerprint(resource: Resource, cache: Dictionary) -> String:
	var id := resource.get_instance_id()
	if cache.has(id):return cache[id]
	# Compare every stored setting, including textures, UVs and render flags.
	# Different resources with identical settings can share one draw. Resource
	# references inside settings retain their identity (e.g. different textures).
	var state: Array = [resource.get_class()]
	for property in resource.get_property_list():
		var label: String = property.name
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE):continue
		if label in ["resource_name", "resource_path", "resource_local_to_scene", "material"]:continue
		state.append([label, resource.get(label)])
	cache[id] = var_to_bytes(state).hex_encode()
	return cache[id]

func create_batch(owner: Node3D, sources: Array) -> void:
	var first: MeshInstance3D = sources[0]
	var batch := MultiMeshInstance3D.new()
	batch.name = "FixedPrimitiveScenery"
	owner.add_child(batch)
	# An origin at the group's centre keeps range culling local to these boxes.
	var centre := Vector3.ZERO
	for source: MeshInstance3D in sources:centre += source.position
	batch.position = centre / sources.size()
	batch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for property in RENDER_PROPERTIES:batch.set(property, first.get(property))
	batch.set_meta("original_shadow", first.cast_shadow)
	batch.set_meta("original_range", first.visibility_range_end)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = first.mesh
	multimesh.instance_count = sources.size()
	batch.material_override = first.get_active_material(0)
	var bounds := AABB()
	var radius := 0.0
	var extent := 0.0
	for index in range(sources.size()):
		var source: MeshInstance3D = sources[index]
		var relative := batch.transform.affine_inverse() * source.transform
		multimesh.set_instance_transform(index, relative)
		var part: AABB = relative * source.get_aabb()
		bounds = part if index == 0 else bounds.merge(part)
		radius = maxf(radius, relative.origin.length())
		extent = maxf(extent, (source.transform * source.get_aabb()).size.length())
		source.hide()
		source.set_meta("performance_batched", true)
	multimesh.custom_aabb = bounds
	batch.multimesh = multimesh
	# Match the source-size policy, not the larger combined bounds. Add the
	# furthest instance offset so batching cannot shorten nearby visibility.
	batch.set_meta("range_extent", extent)
	batch.set_meta("range_padding", radius)
	batches.append(batch)
	source_count += sources.size()

func apply_quality(quality: int) -> void:
	for batch in batches:
		if not is_instance_valid(batch):continue
		if quality < 3:
			var extent: float = batch.get_meta("range_extent")
			var end: float = (40 if extent < 2.5 else 85 if extent < 12 else 180) * [.75, 1.0, 1.6][quality]
			batch.visibility_range_end = end + float(batch.get_meta("range_padding"))
			batch.visibility_range_end_margin = 8
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			batch.visibility_range_end = batch.get_meta("original_range")
			batch.cast_shadow = batch.get_meta("original_shadow")

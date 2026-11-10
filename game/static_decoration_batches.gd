extends RefCounted

# Only fixed, decorative assets enter these batches. Each owner's visibility
# and transform remain authoritative; doors, roof hiding and editor objects
# keep their individual nodes. Cells keep the resulting culling bounds small.
const ASSETS=["Prop_Crate","Prop_WoodenFence_Single","Prop_Wagon","Crate_Wooden","Barrel","Bag","Workbench_Drawers","Bed_Twin1","Cabinet",
	"Table_Large","Table_Plate","Mug","Stool","Bookcase_2","Chandelier"]
var batches: Array[MultiMeshInstance3D]=[]
var source_count:=0

func build(town: Node3D) -> void:
	var groups: Dictionary={}
	for source: MeshInstance3D in town.find_children("*","MeshInstance3D",true,false):
		if source.skin or not source.mesh or not source.is_visible_in_tree() or source.has_meta("performance_batched"):continue
		var asset: Node3D
		var owner: Node3D
		var current: Node=source
		var excluded:=false
		while current and current!=town:
			if current is CharacterBody3D or current is Skeleton3D or current.is_in_group("doors") or current.has_meta("future_trade_item") or current.has_meta("build_id") and not current.is_in_group("enterable_houses"):
				excluded=true;break
			if String(current.name).contains("Roof"):excluded=true;break
			if not asset and current.get_meta("static_asset","") in ASSETS:asset=current
			if current.is_in_group("enterable_houses"):owner=current;break
			current=current.get_parent()
		if excluded or not asset:continue
		if owner:owner=asset.get_parent()
		if not owner:
			# Outside buildings, only fixed models directly placed in the town
			# or a deliberately marked work station are safe to combine.
			if asset.get_parent()==town:owner=town
			elif asset.get_parent().get_meta("static_workplace",false):owner=asset.get_parent().get_parent()
			else:continue
		var materials: Array=[]
		var opaque:=true
		for surface in range(source.mesh.get_surface_count()):
			var material: Material=source.get_active_material(surface)
			if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:opaque=false;break
			materials.append(material)
		if not opaque:continue
		var position: Vector3=owner.to_local(source.global_position)
		var key:=str([owner.get_instance_id(),Vector2i(floori(position.x/16),floori(position.z/16)),source.mesh.get_instance_id(),materials,source.layers,source.cast_shadow])
		if not groups.has(key):groups[key]={"owner":owner,"sources":[],"materials":materials}
		groups[key].sources.append(source)
	for group in groups.values():
		if group.sources.size()<2:continue
		var first: MeshInstance3D=group.sources[0]
		var mesh: Mesh=first.mesh.duplicate()
		for surface in range(group.materials.size()):mesh.surface_set_material(surface,group.materials[surface])
		var batch:=MultiMeshInstance3D.new();batch.name="StaticDecorations"
		group.owner.add_child(batch)
		# Keep the instance origin beside its cell, not at the district's origin.
		# Distance visibility must use the same local area as the combined props.
		batch.global_position=first.global_position
		batch.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		batch.layers=first.layers;batch.cast_shadow=first.cast_shadow
		batch.set_meta("original_shadow",first.cast_shadow)
		batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=mesh;batch.multimesh.instance_count=group.sources.size()
		for index in range(group.sources.size()):
			var source: MeshInstance3D=group.sources[index]
			batch.multimesh.set_instance_transform(index,batch.global_transform.affine_inverse()*source.global_transform)
			source.hide();source.set_meta("performance_batched",true)
		batches.append(batch);source_count+=group.sources.size()
	print("STATIC_DECORATION_BATCHES sources=",source_count," batches=",batches.size())

func apply_quality(quality: int) -> void:
	for batch in batches:
		if not is_instance_valid(batch):continue
		batch.visibility_range_end=[65.0,85.0,130.0,0.0][quality]
		batch.visibility_range_end_margin=8
		batch.cast_shadow=batch.get_meta("original_shadow") if quality==3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

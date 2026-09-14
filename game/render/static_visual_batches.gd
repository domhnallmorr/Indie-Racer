extends RefCounted
## Runtime-only batching of opaque static track meshes. Collision nodes stay intact.
var sources: Array[Dictionary] = []
var batches: Array[MeshInstance3D] = []

func build(root: Node3D) -> void:
	if not batches.is_empty():
		return
	var groups := {}
	for node in root.find_children("*","MeshInstance3D",true,false):
		var source := node as MeshInstance3D
		if not source.is_visible_in_tree() or source.mesh == null or source.skin != null:
			continue
		var mesh: ArrayMesh
		if source.mesh is ArrayMesh:
			mesh = source.mesh
		elif source.mesh is BoxMesh or source.mesh is CylinderMesh or source.mesh is SphereMesh or source.mesh is QuadMesh or source.mesh is PlaneMesh:
			mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.mesh.surface_get_arrays(0))
		else:
			continue
		if mesh.get_blend_shape_count() > 0:
			continue
		if source.material_overlay != null or source.transparency != 0 or source.visibility_range_begin != 0 or source.visibility_range_end != 0:
			continue
		var eligible := true
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface)
			# Local-coordinate shaders and transparent sorting must retain their instances.
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES or (material != null and (not material is StandardMaterial3D or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)):
				eligible = false
			if material is StandardMaterial3D and (material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.uv1_triplanar or material.uv2_triplanar or material.next_pass != null):
				eligible = false
		if not eligible:
			continue
		var transform := root.global_transform.affine_inverse()*source.global_transform
		var chunk := Vector2i(floori(transform.origin.x/80),floori(transform.origin.z/80))
		sources.append({"node":source,"layers":source.layers})
		for surface in range(source.mesh.get_surface_count()):
			var material := source.get_active_material(surface)
			var key := "%s:%s:%s:%s:%s:%s" % [chunk,material.get_instance_id() if material != null else 0,source.layers,source.cast_shadow,source.gi_mode,mesh.surface_get_format(surface)]
			if not groups.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(material)
				groups[key] = {"builder":builder,"layers":source.layers,"shadow":source.cast_shadow,"gi":source.gi_mode}
			groups[key].builder.append_from(mesh,surface,transform)
	var container := Node3D.new()
	container.name = "StaticVisualBatches"
	root.add_child(container)
	for key in groups:
		var group: Dictionary = groups[key]
		var batch := MeshInstance3D.new()
		batch.mesh = group.builder.commit()
		batch.layers = group.layers
		batch.cast_shadow = group.shadow
		batch.gi_mode = group.gi
		container.add_child(batch)
		batches.append(batch)
	set_enabled(true)

func set_enabled(value: bool) -> void:
	for source in sources:
		source.node.layers = 0 if value else source.layers
	for batch in batches:
		batch.visible = value

extends RefCounted
## Apply full-colour artwork to one car without modifying shared roster materials.
static func apply(visual: Node3D, texture: Texture2D) -> int:
	var count := 0
	for node in visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(node.mesh.get_surface_count()):
			var original = node.get_active_material(surface)
			if original is StandardMaterial3D and original.resource_name.begins_with("Livery_"):
				var paint: StandardMaterial3D = original.duplicate()
				paint.albedo_texture = texture
				paint.albedo_color = Color.WHITE
				node.set_surface_override_material(surface,paint)
				count += 1
	return count

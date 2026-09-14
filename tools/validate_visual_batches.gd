extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var batching = main.visual_batches
	var source_triangles := 0
	var batch_triangles := 0
	for source in batching.sources:
		assert(source.node.layers == 0)
		for surface in range(source.node.mesh.get_surface_count()):
			var arrays: Array = source.node.mesh.surface_get_arrays(surface)
			source_triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	for batch in batching.batches:
		for surface in range(batch.mesh.get_surface_count()):
			var arrays: Array = batch.mesh.surface_get_arrays(surface)
			batch_triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	assert(source_triangles == batch_triangles,"Batching must preserve every triangle")
	assert(batching.batches.size() < batching.sources.size()/2,"Batching must substantially reduce instances")
	print("BATCH GEOMETRY PASSED: %d source meshes -> %d batches; %d triangles preserved" % [batching.sources.size(),batching.batches.size(),source_triangles])
	if "--capture" in OS.get_cmdline_user_args():
		main.get_node("DisplayCar/Cockpit").deactivate()
		main.get_node("HUD").hide()
		var camera = main.get_node("InspectionCamera")
		camera.make_current()
		for view in ["main_stand","backstraight"]:
			camera.global_position = main.get_node("MileOval").to_global(Vector3(0,8,110) if view == "main_stand" else Vector3(0,8,-110))
			camera.look_at(main.get_node("MileOval").to_global(Vector3(20,7,157) if view == "main_stand" else Vector3(30,5,-145)))
			for enabled in [false,true]:
				batching.set_enabled(enabled)
				for i in range(5):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://builds/batch_"+view+("_after" if enabled else "_before")+".png")
				print(view," batch=",enabled," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	main.free()
	quit()

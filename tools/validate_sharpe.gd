extends SceneTree
## Integration check: discovered roster, spawned identity and instance-local skin.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var roster = preload("res://game/race/roster_data.gd").new()
	var path := "res://content/rosters/scott_sharpe_2001/manifest.json"
	assert(path in roster.discover())
	assert(roster.load_roster(path), str(roster.errors))
	assert(roster.entries.size() == 15)
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = path
	main.roster_seed = 1234
	root.add_child(main)
	assert(main.ai_cars.size() == 15)
	var car = main.get_node("AI_Sharpe")
	assert(car.get_meta("driver_name") == "Scott Sharpe")
	assert(car.get_meta("roster_entry").number == "8")
	var texture = load("res://content/vehicles/open_wheel/liveries/scott_sharpe_2001.png")
	var panels := 0
	for mesh in car.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var mat = mesh.get_active_material(surface)
			if mat is StandardMaterial3D and mat.resource_name.begins_with("Livery_"):
				assert(mat.albedo_texture == texture and mat.albedo_color == Color.WHITE)
				panels += 1
	assert(panels == 14)
	var other = main.ai_cars[0].get_node("Visual").find_child("Nose",true,false)
	assert(other.get_active_material(0).albedo_texture != texture)
	print("SHARPE PASSED: roster discovery, 15-car spawn, identity, 14 skin panels and instance isolation.")
	quit()

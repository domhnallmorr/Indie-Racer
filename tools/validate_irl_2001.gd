extends SceneTree
## Check roster identities, race order and independent runtime liveries.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var roster = preload("res://game/race/roster_data.gd").new()
	var path := "res://content/rosters/irl_2001/manifest.json"
	assert(path in roster.discover())
	assert(roster.load_roster(path), str(roster.errors))
	assert(roster.data.display_name == "2001 IRL")
	assert(roster.entries.size() == 16)
	assert(roster.race_entries()[1].id == "Hornish")
	assert(roster.race_entries()[2].id == "Lazier")
	assert(roster.entries[2].driver_name == "Buddy Lazier" and roster.entries[2].number == "91")
	assert(roster.race_entries()[3].id == "Boat")
	assert(roster.entries[3].driver_name == "Billy Boat" and roster.entries[3].number == "98")
	assert(roster.race_entries()[4].id == "Salazar")
	assert(roster.entries[4].driver_name == "Eliseo Salazar" and roster.entries[4].number == "14")
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = path
	main.roster_seed = 1234
	root.add_child(main)
	assert(main.ai_cars.size() == 16)
	assert(roster.race_entries()[6].id == "Unser")
	assert(roster.entries[6].driver_name == "Al Unser Jr." and roster.entries[6].number == "3")
	assert(roster.race_entries()[5].id == "Giaffone")
	assert(roster.entries[5].driver_name == "Felipe Giaffone" and roster.entries[5].number == "21")
	assert(roster.race_entries()[7].id == "Cheever")
	assert(roster.entries[7].driver_name == "Eddie Cheever" and roster.entries[7].number == "51")
	assert(roster.race_entries()[8].id == "Calkins")
	assert(roster.entries[8].driver_name == "Buzz Calkins" and roster.entries[8].number == "12")
	assert(roster.race_entries()[9].id == "Dare")
	assert(roster.entries[9].driver_name == "Airton Dar\u00e9" and roster.entries[9].number == "88")
	assert(roster.race_entries()[10].id == "JeffWard")
	assert(roster.entries[10].driver_name == "Jeff Ward" and roster.entries[10].number == "35")
	assert(roster.race_entries()[11].id == "Buhl")
	assert(roster.entries[11].driver_name == "Robbie Buhl" and roster.entries[11].number == "24")
	assert(roster.race_entries()[12].id == "Hattori")
	assert(roster.entries[12].driver_name == "Shigeaki Hattori" and roster.entries[12].number == "55")
	assert(roster.race_entries()[13].id == "Dismore")
	assert(roster.entries[13].driver_name == "Mark Dismore" and roster.entries[13].number == "28")
	assert(roster.entries[13].team == roster.entries[0].team)
	assert(roster.race_entries()[14].id == "Beechler")
	assert(roster.entries[14].driver_name == "Donnie Beechler" and roster.entries[14].number == "84")
	assert(roster.race_entries()[15].id == "McGehee")
	assert(roster.entries[15].driver_name == "Robbie McGehee" and roster.entries[15].number == "10")
	var assigned_boxes := {}
	for entry in roster.entries:
		var car = main.get_node("AI_"+entry.id)
		assert(car.get_meta("driver_name") == entry.driver_name)
		assert(car.get_meta("roster_entry").number == entry.number)
		var box_id = car.get_node("PlayerState").assigned_pit_box_id
		assert(not assigned_boxes.has(box_id))
		assigned_boxes[box_id] = true
		var texture = load(entry.livery)
		var panels := 0
		for mesh in car.get_node("Visual").find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var mat = mesh.get_active_material(surface)
				if mat is StandardMaterial3D and mat.resource_name.begins_with("Livery_"):
					assert(mat.albedo_texture == texture and mat.albedo_color == Color.WHITE)
					panels += 1
		assert(panels == 14)
	# Check the loaded controllers actually produce distinct, ordered speeds.
	var pace_order := ["Hornish", "JeffWard", "Lazier", "Boat", "Buhl", "Giaffone", "Sharpe", "Calkins", "Cheever", "Salazar", "Dismore", "McGehee", "Dare", "Unser", "Hattori"]
	var previous = null
	for id in pace_order:
		# Compare the base calibration without random practice fuel loads.
		main.get_node("AI_"+id).player_state.fuel_gal = 0.0
		var driver = main.get_node("AI_"+id+"/Driver")
		assert(driver.profile_ready, driver.profile_error)
		if previous != null:
			assert(driver.base_lap_target_s > previous.base_lap_target_s)
			var slower_samples := 0
			for speed in driver.reference_speeds:
				var current_speed: float = driver._scaled_reference_speed(speed)
				var previous_speed: float = previous._scaled_reference_speed(speed)
				assert(current_speed <= previous_speed + 0.00001)
				if current_speed < previous_speed - 0.00001:
					slower_samples += 1
			assert(slower_samples > 0, "No effective pace difference for "+id)
		previous = driver
	assert(is_equal_approx(main.get_node("AI_Hornish/Driver").base_lap_target_s, 21.2))
	assert(is_equal_approx(main.get_node("AI_Hattori/Driver").base_lap_target_s, 22.65951))
	assert(main.get_node("AI_Beechler/Driver").base_lap_target_s == main.get_node("AI_Salazar/Driver").base_lap_target_s)
	var original = load("res://content/vehicles/open_wheel/models/open_wheel.glb").instantiate()
	assert(original.find_child("Nose",true,false).get_active_material(0).albedo_texture != load(roster.entries[1].livery))
	original.free()
	print("2001 IRL PASSED: sixteen drivers, race order, 224 painted panels, material isolation and qualifying-relative runtime speed ordering.")
	quit()

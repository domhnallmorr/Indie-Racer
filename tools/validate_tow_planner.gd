extends SceneTree
## Compare the cached planner with the original direct geometry calculation.
func _initialize() -> void:
	call_deferred("validate")

func direct_speed(driver) -> float:
	var car = driver.car
	var position: Vector3 = car.track.to_local(car.global_position)
	var segment: Vector3 = driver.race[(driver.index+1)%driver.race.size()]-driver.race[driver.index]
	var fraction := clampf((position-driver.race[driver.index]).dot(segment)/maxf(segment.length_squared(),.001),0,1)
	var result: float = driver._scaled_reference_speed(lerpf(driver.reference_speeds[driver.index],driver.reference_speeds[(driver.index+1)%driver.race.size()],fraction))*driver.racecraft.speed_factor()
	if car.slipstream_speed_fraction < .00001:
		return result
	result *= 1.0+car.slipstream_speed_fraction*driver._tow_straight_weight(driver.index)
	var horizon: float = car.speed_mps*car.speed_mps/(2.0*car.braking_limit)+car.speed_mps*.5+driver.braking_margin_m
	var distance := -fraction*segment.length()
	for step in range(1,driver.race.size()):
		var at: int = (driver.index+step)%driver.race.size()
		distance += driver.race[(at-1+driver.race.size())%driver.race.size()].distance_to(driver.race[at])
		if distance > horizon:
			break
		var future: float = driver._scaled_reference_speed(driver.reference_speeds[at])*driver.racecraft.speed_factor()
		future *= 1.0+car.slipstream_speed_fraction*driver._tow_straight_weight(at)
		result = minf(result,sqrt(future*future+2.0*car.braking_limit*maxf(0.0,distance-driver.braking_margin_m-car.speed_mps*.5)))
	return result

func validate() -> void:
	var cases := 0
	var max_error := 0.0
	for track_id in ["mile_oval","texas"]:
		root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/irl_2001/manifest.json","seed":1234,"session_mode":"race"})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		var car = main.ai_cars[0]
		var driver = car.get_node("Driver")
		driver.mode = driver.Mode.RACING
		driver.racecraft.opponent = main.ai_cars[1]
		driver.racecraft.passing_speed_factor = .97
		for variant in range(3):
			car.player_state.fuel_gal = 5.0+15.0*variant
			car.player_state.tyre_condition = 1.0-.3*variant
			driver.pace_scale = .95+.05*variant
			driver.racecraft.lane = variant*.5
			car.speed_mps = 45.0+30.0*variant
			for at in range(0,driver.race.size(),13):
				driver.index = at
				var point: Vector3 = driver.race[at].lerp(driver.race[(at+1)%driver.race.size()],.37)
				car.global_position = car.track.to_global(point)
				for tow in [0.0,.00002,.02,.067]:
					car.slipstream_speed_fraction = tow
					max_error = maxf(max_error,absf(driver._planned_speed()-direct_speed(driver)))
					cases += 1
		main.free()
	print("TOW PLANNER EQUIVALENCE cases=",cases," max_error_mps=",max_error)
	quit(0 if max_error < .00001 else 1)

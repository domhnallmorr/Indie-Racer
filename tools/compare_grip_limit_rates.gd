extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")

func _initialize() -> void:
	var cfg = Config.new()
	assert(cfg.load_directory("res://content/vehicles/open_wheel/physics"))
	var results := []
	var finite := true
	for hz in [60,120,240]:
		for catch_slide in [false,true]:
			for direction in [-1.0,1.0]:
				var sim = Model.new()
				sim.configure(cfg.values.duplicate(true))
				sim.u = 25
				sim.gear = 2
				sim.front_omega = 25/sim.p.front_radius_m
				sim.rear_omega = 25/sim.p.rear_radius_m
				sim.engine_omega = sim.rear_omega*sim.ratio()
				var peak_beta := 0.0
				var peak_rear_slip := 0.0
				var onset := -1.0
				for tick in range(6*hz):
					var time := tick/float(hz)
					var gas := .2 if time < 1 else 1.0
					var angle: float = 2.0*direction
					if catch_slide and time >= 3:
						gas = 0
						angle = -3.0*direction if time < 4 else 0.0
					var input: float = angle/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length())
					sim.advance(1.0/hz,gas,0,input)
					var beta := absf(rad_to_deg(atan2(sim.v,absf(sim.u))))
					peak_beta = maxf(peak_beta,beta)
					peak_rear_slip = maxf(peak_rear_slip,absf(rad_to_deg(sim.rear_slip_angle)))
					if onset < 0 and beta > 2: onset = (tick+1)/float(hz)
					finite = finite and is_finite(sim.u) and is_finite(sim.v) and is_finite(sim.yaw_rate)
				var result := {"hz":hz,"catch":catch_slide,"direction":direction,"breakaway_onset_s":onset,"peak_sideslip_deg":peak_beta,"peak_rear_slip_deg":peak_rear_slip,"final_speed_mps":sim.u,"final_sideslip_deg":rad_to_deg(atan2(sim.v,absf(sim.u))),"final_yaw_rad_s":sim.yaw_rate}
				results.append(result)
				print("GRIP RATE ",JSON.stringify(result))
	DirAccess.make_dir_recursive_absolute("res://builds")
	var file := FileAccess.open("res://builds/grip_limit_rates.json",FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	quit(0 if finite else 1)

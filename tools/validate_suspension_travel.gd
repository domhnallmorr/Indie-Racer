extends SceneTree
const Travel = preload("res://game/vehicle/travel_suspension.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const PROFILE = "res://content/vehicles/open_wheel/physics/indy_suspension.cfg"
var failures: Array[String] = []
var p: Dictionary

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func run_case(hz: int, bump: bool, front_aero: float = 0.0, rear_aero: float = 0.0,
		roll_input: float = 0.0, pitch_input: float = 0.0,
		normal_gravity: float = 9.81, support_accel: float = 9.81) -> Dictionary:
	var body = Travel.new()
	check(body.configure_indy(PROFILE),"Travel profile loads")
	var height: float = body.ride_height_m
	var mass := 800.0
	var peak_load := 0.0
	var peak_compression := 0.0
	var peak_height := height
	var peak_roll := 0.0
	var bump_left := 0.0
	var bump_right := 0.0
	var dt := 1.0/hz
	for frame in range(4*hz):
		var t := frame*dt
		var road := 0.0
		var road_speed := 0.0
		# Smooth 30 mm, 0.2 s single-wheel bump; derivative is known independently.
		if bump and t >= 1 and t < 1.2:
			road = .015*(1.0-cos(TAU*(t-1.0)/.2))
			road_speed = .015*TAU/.2*sin(TAU*(t-1.0)/.2)
		body.begin_frame(PackedFloat64Array([height-road,height,height,height]),
			PackedFloat64Array([road_speed,0,0,0]),PackedByteArray([1,1,1,1]))
		var steps := int(ceil(dt/.0005))
		for step in range(steps):
			body.advance_travel(dt/steps,mass,p,normal_gravity,support_accel,front_aero,rear_aero,roll_input,pitch_input)
			for load_n in body.loads:
				check(is_finite(load_n) and load_n >= 0,"Finite unilateral support")
			peak_load = maxf(peak_load,body.loads[0])
			peak_compression = maxf(peak_compression,body.compression[0])
			peak_roll = maxf(peak_roll,absf(body.roll))
			if road > .015:
				bump_left = maxf(bump_left,body.loads[0])
				bump_right = maxf(bump_right,body.loads[1])
		height += body.heave_delta_m
		peak_height = maxf(peak_height,height)
	check(absf(body.heave_velocity_mps) < .001,"Heave settles after excitation")
	return {"height":height,"roll":body.roll,"pitch":body.pitch,"loads":body.loads.duplicate(),
		"roll_reaction":body.roll_reaction_nm,"pitch_reaction":body.pitch_reaction_nm,
		"peak_load":peak_load,"peak_compression":peak_compression,"peak_roll":peak_roll,
		"bump_left":bump_left,"bump_right":bump_right,"peak_height":peak_height}

func _initialize() -> void:
	var cfg = Config.new()
	check(cfg.load_directory("res://content/vehicles/open_wheel/physics"),"Vehicle parameters load")
	p = cfg.values
	var parked := run_case(120,false)
	check(absf(parked.height-.16) < .0001,"Parked loaded height")
	check(absf(parked.loads[0]+parked.loads[1]-800*9.81*p.front_weight_fraction) < .01,"Parked front weight split")
	var aero := run_case(120,false,3500,6500,8500,-1800)
	print("TRAVEL equilibrium=",aero)
	check(absf(aero.height-(.16-10000.0/1200000.0)) < .0001,"10 kN aero compresses stiffened heave by 8.33 mm")
	check(absf(aero.loads[0]+aero.loads[1]-(800*9.81*p.front_weight_fraction+3500+1800/p.wheelbase_m)) < .1,"Steady axle loads retain brake/aero balance")
	check(absf(aero.roll_reaction-8500) < .1 and absf(aero.pitch_reaction+1800) < .1,"Roll/pitch reaction equilibrium")
	# Compare all four steady loads against the accepted stage-2 transfer split
	# under the same bank, aero, braking and roll moment. Geometry transients
	# may change balance, but wheel travel must not invent a steady bias.
	var gn := 9.81*cos(deg_to_rad(9))
	var support := gn+95*.2*sin(deg_to_rad(9))
	var saved_balance: float = p.front_roll_stiffness_fraction
	var max_load_error := 0.0
	for balance in [.4,.5,.6]:
		p.front_roll_stiffness_fraction = balance
		var settled := run_case(120,false,3500,6500,8500,-1800,gn,support)
		var baseline = Model.new()
		baseline.configure(p.duplicate(true))
		baseline.suspension.enabled = true
		baseline.suspension.roll_reaction_nm = 8500
		baseline.front_load = 800*support*p.front_weight_fraction+3500+1800/p.wheelbase_m
		baseline.rear_load = 800*support*(1-p.front_weight_fraction)+6500-1800/p.wheelbase_m
		baseline._update_wheel_loads()
		for i in range(4):
			max_load_error = maxf(max_load_error,absf(settled.loads[i]-baseline.wheel_loads[i]))
		check(absf(settled.height-(.16-(10000+800*(support-gn))/1200000)) < .0001,"Banking plus aero heave equilibrium")
	p.front_roll_stiffness_fraction = saved_balance
	print("BANK BALANCE stage-2/travel max_corner_load_error_n=",max_load_error)
	check(max_load_error < .1,"Banked steady four-corner loads preserve accepted balance")
	var cases: Array[Dictionary] = []
	for hz in [60,120,240]:
		var result := run_case(hz,true)
		cases.append(result)
		print("TRAVEL bump hz=",hz," result=",result)
		check(result.peak_height > .1601 and result.peak_roll > .0001,"Single-wheel bump excites heave and roll")
		check(result.bump_left > result.bump_right,"Bumped left wheel carries asymmetric load")
		check(absf(result.height-.16) < .0001 and absf(result.roll) < .0001,"Bump settles back to reference stance")
	check(absf(cases[0].peak_height-cases[2].peak_height) < .004,"Bump heave convergence 60/240 Hz")
	check(absf(cases[0].peak_roll-cases[2].peak_roll) < .004,"Bump roll convergence 60/240 Hz")
	# Stiff travel now runs with 120 Hz road/collision sampling. Keep 60 Hz as
	# a diagnostic; evaluate the same 8% bound at the supported runtime rate.
	check(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") >= 120,"Stiff suspension requires at least 120 Hz road sampling")
	check(absf(cases[1].peak_load-cases[2].peak_load)/cases[2].peak_load < .08,"120/240 Hz bump peak load convergence within 8%")
	var body = Travel.new()
	body.configure_indy(PROFILE)
	# A coordinate-frame relabelling with unchanged physical travel must not
	# create damper force. Its gap and relative body tilt cancel exactly.
	body.roll = .01
	body.pitch = .005
	body.road_roll_rate = 1
	body.road_pitch_rate = 2
	var a: float = p.wheelbase_m*(1-p.front_weight_fraction)
	var b: float = p.wheelbase_m*p.front_weight_fraction
	var xs := [a,a,-b,-b]
	var ys := [p.front_track_m*.5,-p.front_track_m*.5,p.rear_track_m*.5,-p.rear_track_m*.5]
	var relabelled_gaps := PackedFloat64Array()
	for i in range(4): relabelled_gaps.append(.16-xs[i]*body.pitch-ys[i]*body.roll)
	body.begin_frame(relabelled_gaps,PackedFloat64Array([0,0,0,0]),PackedByteArray([1,1,1,1]))
	body.advance_travel(.0000001,800,p,9.81,9.81,0,0,0,0)
	for i in range(4):
		var share: float = p.front_weight_fraction*.5 if i < 2 else (1-p.front_weight_fraction)*.5
		check(absf(body.loads[i]-800*9.81*share) < .001,"Road-frame relabelling cannot invent spring/damper loading")
	body.reset()
	body.begin_frame(PackedFloat64Array([.02,.16,.16,.16]),PackedFloat64Array([0,0,0,0]),PackedByteArray([1,1,1,1]))
	body.advance_travel(.0005,800,p,9.81,9.81,0,0,0,0)
	check(body.bump_stop_loads[0] > 0,"Bump stop engages beyond compression limit")
	body.begin_frame(PackedFloat64Array([.5,.16,.16,.16]),PackedFloat64Array([0,0,0,0]),PackedByteArray([1,1,1,1]))
	body.advance_travel(.0005,800,p,9.81,9.81,0,0,0,0)
	check(body.loads[0] == 0 and body.contact[0] == 0,"Droop limit releases unsupported wheel")
	body.reset()
	body.begin_frame(PackedFloat64Array([.5,.5,.5,.5]),PackedFloat64Array([0,0,0,0]),PackedByteArray([0,0,0,0]))
	body.advance_travel(.0005,800,p,9.81,9.81,0,0,0,0)
	check(body.loads == PackedFloat64Array([0,0,0,0]) and body.heave_velocity_mps < 0,"Free fall without fake wheel support")
	body.reset()
	check(not body.sampled and body.heave_velocity_mps == 0,"Reset clears travel history")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SUSPENSION TRAVEL PASSED: equilibrium, aero/braking balance, bump response, convergence, bump stops, droop, freefall and reset.")
	quit(0 if failures.is_empty() else 1)

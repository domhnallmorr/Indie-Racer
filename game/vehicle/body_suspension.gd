extends RefCounted
## Reduced roll/pitch modes about the road plane. No heave or wheel travel.
## Positive roll loads right tyres; positive pitch loads rear tyres.
var enabled := false
var profile_id := "disabled"
var source_shocks: Array = [] # FL, FR, RL, RR; ICR2 dimensionless values.
var roll_stiffness_nm_rad := 180000.0
var pitch_stiffness_nm_rad := 180000.0
var roll_inertia_kgm2 := 1000.0
var pitch_inertia_kgm2 := 1000.0
var damping_ratio := .8
var roll := 0.0
var pitch := 0.0
var roll_rate := 0.0
var pitch_rate := 0.0
var roll_reaction_nm := 0.0
var pitch_reaction_nm := 0.0

func reset() -> void:
	roll = 0.0
	pitch = 0.0
	roll_rate = 0.0
	pitch_rate = 0.0
	roll_reaction_nm = 0.0
	pitch_reaction_nm = 0.0

func configure_indy(path: String) -> bool:
	enabled = false
	profile_id = "disabled"
	source_shocks = []
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for key in ["roll_stiffness_nm_rad","pitch_stiffness_nm_rad","roll_inertia_kgm2","pitch_inertia_kgm2","damping_ratio"]:
		var value = cfg.get_value("prototype",key,null)
		if not (value is float or value is int) or not is_finite(float(value)) or value <= 0:
			return false
		set(key,float(value))
	for corner in ["fl","fr","rl","rr"]:
		var setting = cfg.get_value("icr2",corner+"_shock",null)
		if not (setting is int or setting is float) or not is_finite(float(setting)) or setting < 0 or setting > 100:
			return false
		source_shocks.append(float(setting))
	# Hypothesis: use the recovered coefficient relative to setting 50 only as
	# a stiffness scale. No claim that ICR2's shock value is a physical spring rate.
	var mean_scale := 0.0
	for setting in source_shocks:
		mean_scale += (2047.0+floor(setting*2048.0/100.0))/3071.0
	mean_scale *= .25
	roll_stiffness_nm_rad *= mean_scale
	pitch_stiffness_nm_rad *= mean_scale
	profile_id = "indy_race_ind_roll_pitch_v2"
	enabled = true
	return true

func advance(dt: float, roll_moment: float, pitch_moment: float, mass_scale: float, grounded: bool) -> void:
	if not enabled or not grounded:
		reset()
		return
	var ir := roll_inertia_kgm2*mass_scale
	var ip := pitch_inertia_kgm2*mass_scale
	var cr := 2.0*damping_ratio*sqrt(roll_stiffness_nm_rad*ir)
	var cp := 2.0*damping_ratio*sqrt(pitch_stiffness_nm_rad*ip)
	# Semi-implicit integration at the existing drivetrain substep cadence.
	roll_rate += (roll_moment-roll_stiffness_nm_rad*roll-cr*roll_rate)/ir*dt
	pitch_rate += (pitch_moment-pitch_stiffness_nm_rad*pitch-cp*pitch_rate)/ip*dt
	roll += roll_rate*dt
	pitch += pitch_rate*dt
	roll_reaction_nm = roll_stiffness_nm_rad*roll+cr*roll_rate
	pitch_reaction_nm = pitch_stiffness_nm_rad*pitch+cp*pitch_rate

func metadata() -> Dictionary:
	return {"enabled":enabled,"profile":profile_id,"source_shocks_fl_fr_rl_rr":source_shocks,
		"roll_stiffness_nm_rad":roll_stiffness_nm_rad,"pitch_stiffness_nm_rad":pitch_stiffness_nm_rad,
		"roll_inertia_kgm2":roll_inertia_kgm2,"pitch_inertia_kgm2":pitch_inertia_kgm2,
		"damping_ratio":damping_ratio,"icr2_si_conversion_verified":false}

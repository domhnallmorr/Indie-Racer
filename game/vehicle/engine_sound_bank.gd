extends RefCounted
## IndyV8.sfx engine mappings. Row: sample key, min RPM, max RPM, natural RPM.
## The mixer holds the first/last layer beyond its range to cover any redline.
const BANKS := {
	"inside_power": [
		["internal_v1h", 1.0, 4100.0, 6700.0],
		["internal_v1h", 3000.0, 5400.0, 6700.0],
		["internal_l1g", 4400.0, 6700.0, 6700.0],
		["internal_h1f", 5700.0, 8600.0, 6700.0],
		["internal_h5h", 7000.0, 13500.0, 10100.0]],
	"inside_coast": [
		["internal_indy_idle", 1.0, 2900.0, 4000.0],
		["internal_ov3m", 1150.0, 4300.0, 6700.0],
		["internal_ov3m", 3100.0, 5500.0, 6700.0],
		["internal_ol1g", 4600.0, 7100.0, 6700.0],
		["internal_oh1g", 6100.0, 10400.0, 6700.0]],
	"outside_power": [
		["indy_idle_ex", 1.0, 3973.0, 7200.0],
		["indy_onhigh_ex", 2734.0, 8340.0, 7200.0],
		["indy_onhigh_ex", 6391.0, 12030.0, 7200.0]],
	"outside_coast": [
		["indy_idle_ex", 1.0, 3026.0, 7200.0],
		["indy_onlow_ex", 2094.0, 8187.0, 7200.0],
		["indy_onlow_ex", 5917.0, 11958.0, 7200.0]],
}
const LOAD_BLEND := {"inside": Vector2(0.15, 0.7), "outside": Vector2(0.1, 0.7)}
const SAMPLES := {
	"internal_v1h": preload("res://content/vehicles/open_wheel/audio/internal_v1h.wav"),
	"internal_l1g": preload("res://content/vehicles/open_wheel/audio/internal_l1g.wav"),
	"internal_h1f": preload("res://content/vehicles/open_wheel/audio/internal_h1f.wav"),
	"internal_h5h": preload("res://content/vehicles/open_wheel/audio/internal_h5h.wav"),
	"internal_indy_idle": preload("res://content/vehicles/open_wheel/audio/internal_indy_idle.wav"),
	"internal_ov3m": preload("res://content/vehicles/open_wheel/audio/internal_ov3m.wav"),
	"internal_ol1g": preload("res://content/vehicles/open_wheel/audio/internal_ol1g.wav"),
	"internal_oh1g": preload("res://content/vehicles/open_wheel/audio/internal_oh1g.wav"),
	"indy_idle_ex": preload("res://content/vehicles/open_wheel/audio/indy_idle_ex.wav"),
	"indy_onhigh_ex": preload("res://content/vehicles/open_wheel/audio/indy_onhigh_ex.wav"),
	"indy_onlow_ex": preload("res://content/vehicles/open_wheel/audio/indy_onlow_ex.wav"),
}
static var loops: Dictionary = {}

static func stream_for(key: String) -> AudioStreamWAV:
	if not loops.has(key):
		var sample: AudioStreamWAV = SAMPLES[key].duplicate()
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_begin = 0
		sample.loop_end = sample.data.size() / 2 # Prepared files are mono 16-bit PCM.
		loops[key] = sample
	return loops[key]

static func rpm_weights(bank_name: String, rpm: float) -> PackedFloat32Array:
	var rows: Array = BANKS[bank_name]
	var weights := PackedFloat32Array()
	weights.resize(rows.size())
	# Adjacent intervals overlap, never three at once in this SFX. At either
	# extreme hold the endpoint rather than fading out above the donor redline.
	weights[0] = 1.0
	for i in range(1, rows.size()):
		var blend := clampf(inverse_lerp(rows[i][1], rows[i-1][2], rpm), 0.0, 1.0)
		weights[i-1] *= 1.0-blend
		weights[i] = blend
	return weights

static func mix(perspective: String, rpm: float, load_value: float) -> Dictionary:
	var blend: Vector2 = LOAD_BLEND[perspective]
	var power := clampf(inverse_lerp(blend.x, blend.y, load_value), 0.0, 1.0)
	var result: Dictionary = {}
	for mode in ["power", "coast"]:
		var name: String = perspective + "_" + mode
		var rows: Array = BANKS[name]
		var weights := rpm_weights(name, rpm)
		for i in range(rows.size()):
			var key: String = rows[i][0]
			var weight := weights[i] * (power if mode == "power" else 1.0-power)
			# Merge duplicate recordings BEFORE equal-power normalization.
			if not result.has(key):
				result[key] = Vector2(0.0, rpm / float(rows[i][3]))
			result[key].x += weight
	var energy := 0.0
	for value: Vector2 in result.values():
		energy += value.x * value.x
	var normalization := sqrt(maxf(energy, 0.000001))
	for key in result:
		result[key].x /= normalization
	return result

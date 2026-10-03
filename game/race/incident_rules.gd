extends RefCounted
## One seeded event budget per car, shared by AI and player.
enum Kind { ENGINE, OTHER, TRANSMISSION, HALF_SHAFT, TURBO, ELECTRONICS, PUNCTURE, CRASH }
const EVENT_CHANCE := 0.20
const DEBRIS_CHANCE := 0.08
const LIMP_SPEED_MPS := 100.0/3.6
const NAMES := ["Engine failure", "Other", "Transmission failure", "Half-shaft failure", "Turbo failure", "Electronics failure", "Puncture", "Spin / crash"]

static func schedule(seed_value: int, laps: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0xFA17
	var at := INF
	if rng.randf() < EVENT_CHANCE:
		at = rng.randf_range(.05,.95)*laps
	var type_rng := RandomNumberGenerator.new()
	type_rng.seed = seed_value ^ 0x07E2
	var draw := type_rng.randf()
	# 50% stop/crash, 35% terminal pit return, 15% repairable puncture.
	var kind := Kind.CRASH
	if draw < .20:
		kind = Kind.ENGINE
	elif draw < .30:
		kind = Kind.TRANSMISSION
	elif draw < .40:
		kind = Kind.HALF_SHAFT
	elif draw < .60:
		kind = Kind.TURBO
	elif draw < .75:
		kind = Kind.ELECTRONICS
	elif draw < .90:
		kind = Kind.PUNCTURE
	return {"progress":at,"kind":kind}

static func returns_to_pits(kind: int) -> bool:
	return kind in [Kind.OTHER,Kind.TURBO,Kind.ELECTRONICS,Kind.PUNCTURE]

static func progress(timing, car: Node3D) -> float:
	for entry in timing.entries:
		if entry.car == car:
			return maxf(0.0,(timing._track_progress(entry)-1.0)/maxi(1,timing.gates.size()))
	return 0.0

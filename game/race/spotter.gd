extends RefCounted
## Player-relative overlap detection, independent of presentation and audio.
signal callout(message: String, occupied_sides: int)

const LEFT := 1
const RIGHT := 2
const HALF_LENGTH := 2.5
const HALF_WIDTH := 1.0
const SIDE_RANGE := 6.0
const CLEAR_DELAY := 0.4
var occupied_sides := 0
var left_clear_time := 0.0
var right_clear_time := 0.0

func reset() -> void:
	occupied_sides = 0
	left_clear_time = 0.0
	right_clear_time = 0.0

func update(player: Node3D, cars: Array, delta: float) -> void:
	var detected := 0
	var basis := player.global_basis.orthonormalized()
	for car in cars:
		if not is_instance_valid(car) or car == player or not car.is_visible_in_tree():
			continue
		var offset: Vector3 = basis.inverse() * (car.global_position - player.global_position)
		if offset.length_squared() > 144.0 or absf(offset.y) > 2.5:
			continue
		# Project the opponent's footprint onto the player's axes, including yaw.
		var other: Basis = basis.inverse() * car.global_basis.orthonormalized()
		var reach := HALF_LENGTH + absf(other.z.z) * HALF_LENGTH + absf(other.x.z) * HALF_WIDTH
		var side := LEFT if offset.x < 0.0 else RIGHT
		var margin := 0.6 if (occupied_sides & side) != 0 else 0.0
		if absf(offset.z) <= reach + margin and absf(offset.x) >= 0.75 and absf(offset.x) <= SIDE_RANGE + margin:
			detected |= side
	left_clear_time = 0.0 if (detected & LEFT) != 0 else left_clear_time + delta
	right_clear_time = 0.0 if (detected & RIGHT) != 0 else right_clear_time + delta
	var next := detected
	if (occupied_sides & LEFT) != 0 and left_clear_time < CLEAR_DELAY:
		next |= LEFT
	if (occupied_sides & RIGHT) != 0 and right_clear_time < CLEAR_DELAY:
		next |= RIGHT
	if next == occupied_sides:
		return
	var previous := occupied_sides
	occupied_sides = next
	var message := ""
	match next:
		3: message = "THREE WIDE — HOLD YOUR LINE"
		LEFT: message = "CLEAR RIGHT — CAR LEFT" if previous == 3 else "CAR LEFT"
		RIGHT: message = "CLEAR LEFT — CAR RIGHT" if previous == 3 else "CAR RIGHT"
		0:
			message = "ALL CLEAR" if previous == 3 else ("CLEAR LEFT" if previous == LEFT else "CLEAR RIGHT")
	callout.emit(message, occupied_sides)

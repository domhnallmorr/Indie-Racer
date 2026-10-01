extends RefCounted
## Adjustable ratios are dimensionless. Speed preview assumes zero tyre slip.
static func valid(final_drive: Variant, ratios: Variant) -> bool:
	if not (final_drive is float or final_drive is int):
		return false
	if not is_finite(float(final_drive)) or final_drive < 2.0 or final_drive > 6.0:
		return false
	if not ratios is Array or ratios.size() != 6:
		return false
	var previous := INF
	for ratio in ratios:
		if not (ratio is float or ratio is int):
			return false
		if not is_finite(float(ratio)) or ratio < 0.5 or ratio > 5.0 or ratio >= previous:
			return false
		previous = float(ratio)
	return true

static func speed_kph(rpm: float, radius: float, final_drive: float, ratio: float) -> float:
	return rpm/60.0*TAU*radius/(final_drive*ratio)*3.6

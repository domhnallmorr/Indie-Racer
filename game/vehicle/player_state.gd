extends Node
## Shared state for future limiter, timing and pit systems. No driving logic.
signal pit_lane_changed(in_pit_lane: bool)
var is_in_pit_lane := false
var assigned_pit_box_id := ""
var is_in_pit_speed_zone := false
var speed_mps := 0.0

func set_in_pit_lane(value: bool) -> void:
	if value == is_in_pit_lane:
		return
	is_in_pit_lane = value
	pit_lane_changed.emit(value)

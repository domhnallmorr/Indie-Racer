@tool
extends "res://content/tracks/mile_oval/pit_station/pit_stations.gd"
## Shared Mile Oval canopies and equipment, aligned with Texas's straight boxes.
func _ready() -> void:
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/session.json"))
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var boxes: Array = session.pit_boxes.duplicate()
	boxes.append(session.pace_car_box)
	for index in range(boxes.size()):
		var box: Dictionary = boxes[index]
		var station := Station.new()
		station.name = "PitStation%02d" % (index+1)
		station.station_index = index
		station.team_colour = Color("e8b632") if box.id == "pace_car_pit" else Color(PALETTE[index%PALETTE.size()])
		# Roof extends 1.8 m toward pit road; leave .2 m behind the .5 m wall.
		station.position = Vector3(box.position[0],-.19,float(geometry.pit_wall_z)-2.5)
		station.set_meta("pit_box_id",box.id)
		station.set_meta("painted_box_number",index+1)
		add_child(station)
		stations.append(station)

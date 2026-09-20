@tool
extends Node3D
## 26 race boxes plus the dedicated pace-car bay at the pit exit.
const Station = preload("res://content/tracks/mile_oval/pit_station/pit_station.gd")
const COUNT := 27
const STRAIGHT := (1609.344-TAU*125.0)/2.0
const SPACING := (STRAIGHT-145.0)/COUNT
const PALETTE := ["ab2431","244d85","d7ac31","347569","d0d1ce","6c457f","cf6427","38454c"]
var stations: Array[Node3D] = []

func _ready() -> void:
	for index in range(COUNT):
		var station := Station.new()
		station.name = "PitStation%02d" % (index+1)
		station.station_index = index
		station.team_colour = Color(PALETTE[index%PALETTE.size()])
		if index == COUNT-1:
			station.team_colour = Color("e8b632")
			station.set_meta("pit_box_id","pace_car_pit")
		station.position = Vector3(120.0+(index+.5)*SPACING-STRAIGHT/2.0,0,84.45)
		station.set_meta("painted_box_number",index+1)
		add_child(station)
		stations.append(station)

func match_assigned_cars(cars: Array, pit_boxes: Array) -> void:
	for car in cars:
		var id: String = car.player_state.assigned_pit_box_id
		for box in pit_boxes:
			if box.id != id:
				continue
			var nearest := 0
			for i in range(stations.size()):
				if absf(stations[i].position.x-box.position[0]) < absf(stations[nearest].position.x-box.position[0]):
					nearest = i
			var entry: Dictionary = car.get_meta("roster_entry",{})
			stations[nearest].set_team_colour(Color.html(entry.get("colour","#ab2431")))
			stations[nearest].set_meta("pit_box_id",id)

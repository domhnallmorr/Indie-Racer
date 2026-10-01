extends "res://content/vehicles/pace_car/pace_car_model.gd"
## Visual-only period safety pickup / rollback truck, facing local -Z.
var flatbed := false

func _ready() -> void:
	flashing = true
	var paint := material("e6e8df",.55)
	var red := material("b82c24",.5)
	var glass := material("263c48",.25,.25)
	var rubber := material("181b1d",.9)
	var metal := material("929ca2",.5,.65)
	var front := -3.2 if flatbed else -2.6
	var cab_z := -1.7 if flatbed else -.45
	box("Chassis",Vector3(0,.52,.2),Vector3(2.05,.3,8.0 if flatbed else 5.1),rubber)
	box("Hood",Vector3(0,1.14,front+.65),Vector3(2.05,.65,1.3),paint)
	box("Cab",Vector3(0,1.08,cab_z),Vector3(2.1,.72,1.8),paint)
	loft("CabGlass",[[1.43,1.02,cab_z-.9,cab_z+.9],[2.12,.85,cab_z-.6,cab_z+.7]],glass)
	box("CabRoof",Vector3(0,2.16,cab_z+.05),Vector3(1.82,.12,1.45),paint)
	for side in [-1.0,1.0]:
		box("DoorStripe",Vector3(side*1.057,1.15,cab_z),Vector3(.025,.25,1.7),red)
		box("CabPillar",Vector3(side*.91,1.8,cab_z+.7),Vector3(.12,.64,.13),paint)
		box("Mirror",Vector3(side*1.2,1.55,cab_z-.6),Vector3(.25,.24,.23),rubber)
		box("Handle",Vector3(side*1.075,1.4,cab_z+.43),Vector3(.025,.06,.22),metal)
		var label := Label3D.new()
		label.text = "RECOVERY" if flatbed else "SAFETY"
		label.font_size = 48
		label.pixel_size = .004
		label.position = Vector3(side*1.08,1.17,cab_z)
		label.rotation.y = side*PI/2
		add_child(label)
		for axle in ([front+.7,1.7,2.65] if flatbed else [-1.7,1.65]):
			_cylinder("Tyre",Vector3(side*1.03,.46,axle),.46,.3,rubber)
			_cylinder("Hub",Vector3(side*1.195,.46,axle),.26,.035,metal)
		box("Headlamp",Vector3(side*.7,1.22,front-.02),Vector3(.5,.25,.04),material("fff1c2"))
		box("Beacon",Vector3(side*.5,2.38,cab_z),Vector3(.4,.19,.3),material("ffa315"))
		beacons.append(get_child(get_child_count()-1))
	box("Lightbar",Vector3(0,2.25,cab_z),Vector3(1.5,.08,.36),rubber)
	box("Grille",Vector3(0,1.06,front-.03),Vector3(.8,.36,.05),rubber)
	box("FrontBumper",Vector3(0,.68,front-.12),Vector3(2.18,.2,.2),metal)
	if flatbed:
		box("Deck",Vector3(0,.97,1.55),Vector3(2.5,.2,5.6),metal)
		for side in [-1.0,1.0]:
			box("DeckRail",Vector3(side*1.23,1.12,1.55),Vector3(.08,.12,5.6),red)
			box("RearLamp",Vector3(side*1.0,.82,4.37),Vector3(.35,.16,.05),red)
		box("Headboard",Vector3(0,1.52,-1.2),Vector3(2.4,.95,.12),metal)
		box("Winch",Vector3(0,1.16,-.85),Vector3(.65,.25,.4),rubber)
	else:
		box("BedFloor",Vector3(0,.87,1.55),Vector3(2.05,.18,2.15),rubber)
		for side in [-1.0,1.0]:
			box("BedSide",Vector3(side*.97,1.17,1.55),Vector3(.17,.65,2.15),paint)
			box("BedStripe",Vector3(side*1.065,1.15,1.55),Vector3(.025,.25,2.15),red)
			box("TailLamp",Vector3(side*.85,1.14,2.64),Vector3(.22,.4,.05),red)
		box("Tailgate",Vector3(0,1.16,2.57),Vector3(2.05,.65,.16),paint)
		box("EquipmentChest",Vector3(0,1.17,.78),Vector3(1.75,.45,.55),metal)

func _cylinder(label: String, at: Vector3, radius: float, width: float, mat: Material) -> void:
	var wheel := MeshInstance3D.new()
	wheel.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 16
	wheel.mesh = mesh
	wheel.material_override = mat
	wheel.position = at
	wheel.rotation.z = PI/2
	add_child(wheel)

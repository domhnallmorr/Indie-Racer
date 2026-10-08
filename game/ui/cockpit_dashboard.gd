extends Control
## Period LCD: real speed, gear, RPM, fuel and the session's existing lap clock.
const SIZE := Vector2(960,440)
const INK := Color("263127")
const GHOST := Color("98a28a")
const BACKGROUND := Color("b1baa2")
const SEGMENTS := {
	"0": [0,1,2,3,4,5], "1": [1,2], "2": [0,1,6,4,3],
	"3": [0,1,6,2,3], "4": [5,6,1,2], "5": [0,5,6,2,3],
	"6": [0,5,6,4,2,3], "7": [0,1,2], "8": [0,1,2,3,4,5,6],
	"9": [0,1,2,3,5,6], "-": [6]
}
var font := ThemeDB.fallback_font
var player: Node
var refresh_time := 0.0
var readouts: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = SIZE
	readouts = sample_readouts()
	queue_redraw()

func _process(delta: float) -> void:
	refresh_time += delta
	if refresh_time >= .05:
		refresh_time = fmod(refresh_time,.05)
		readouts = sample_readouts()
		queue_redraw()

func sample_readouts() -> Dictionary:
	var data := {"speed":0,"gear":"N","rpm":0.0,"redline":13800.0,"fuel":0.0,
		"lap":"OUT","current":"--:--.---","last":"--:--.---","best":"--:--.---",
		"session":"PRACTICE","servicing":false,"service_remaining":0.0,"limiter":false,"engine":true}
	if not is_instance_valid(player):
		return data
	data.speed = clampi(int(round(absf(player.speed_mps)*3.6)),0,999)
	data.gear = player.gear_text
	data.rpm = player.engine_rpm
	if player.physics_ready:
		data.redline = player.sim.p.redline_rpm
	var state = player.player_state
	if state != null:
		data.fuel = state.fuel_litres()
		data.servicing = state.pit_stall_state == state.StallState.SERVICING
		data.service_remaining = state.service_remaining
		data.limiter = state.is_in_pit_speed_zone
		data.engine = state.engine_running
		if state.session != null:
			data.session = state.session.display_name().to_upper()
	var timing = player.get_parent().get_node_or_null("LapTiming")
	if timing != null:
		for entry in timing.entries:
			if entry.car != player:
				continue
			data.lap = str(int(entry.laps)+1) if entry.armed else "OUT"
			data.current = timing.format_lap(maxf(0.0,timing.clock-entry.started)) if entry.armed else "--:--.---"
			data.last = timing.format_lap(entry.last)
			data.best = timing.format_lap(entry.best)
			if state != null and state.session != null and state.session.session_type == state.session.SessionType.RACE:
				if state.session.status == state.session.Status.FORMATION:
					data.lap = "--"
					data.current = "--:--.---"
				elif entry.armed:
					data.lap = str(mini(int(entry.laps)+1,state.session.race_laps))
					if state.session.status == state.session.Status.FINISHED:
						data.current = timing.format_lap(entry.last)
			break
	return data

func text_at(text: String, pos: Vector2, size: int, color := INK) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _segment(a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
	var direction := (b-a).normalized()
	var normal := Vector2(-direction.y,direction.x)*thickness*.5
	var inset := direction*thickness*.48
	draw_colored_polygon(PackedVector2Array([a,a+inset+normal,b-inset+normal,b,b-inset-normal,a+inset-normal]),color)

func digits(value: String, position: Vector2, height: float, color := INK, ghosts := true) -> void:
	var width := height*.51
	var thickness := height*.085
	var x := position.x
	for character in value:
		if character == ".":
			draw_rect(Rect2(x,position.y+height-thickness,thickness,thickness),color)
			x += height*.17
			continue
		if character == ":":
			for y in [.30,.70]:
				draw_rect(Rect2(x,position.y+height*y,thickness,thickness),color)
			x += height*.19
			continue
		if character not in SEGMENTS:
			text_at(character,Vector2(x,position.y+height),int(height),color)
			x += width+height*.15
			continue
		var origin := Vector2(x,position.y)
		var points := [Vector2(thickness,0),Vector2(width-thickness,0),Vector2(width,thickness),
			Vector2(width,height*.5-thickness*.5),Vector2(width,height*.5+thickness*.5),Vector2(width,height-thickness),
			Vector2(width-thickness,height),Vector2(thickness,height),Vector2(0,height-thickness),
			Vector2(0,height*.5+thickness*.5),Vector2(0,height*.5-thickness*.5),Vector2(0,thickness),
			Vector2(thickness,height*.5),Vector2(width-thickness,height*.5)]
		for i in range(7):
			if ghosts or i in SEGMENTS[character]:
				_segment(origin+points[i*2],origin+points[i*2+1],thickness,color if i in SEGMENTS[character] else GHOST)
		x += width+height*.15

func _tach_point(t: float) -> Vector2:
	return Vector2(40+t*870,134-66*sin(t*PI*.5))

func _draw() -> void:
	if readouts.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO,SIZE),BACKGROUND)
	# Gentle LCD shading, without a glass reflection obscuring the instruments.
	for y in range(0,440,4):
		draw_rect(Rect2(0,y,960,4),Color(0.11,0.16,0.10,.035*float(y)/440))
	text_at("OVAL 95",Vector2(94,38),23)
	var mode: String = readouts.session
	text_at(mode,Vector2(910-font.get_string_size(mode,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x,38),19)
	for i in range(42):
		var a := _tach_point(float(i)/42)
		var b := _tach_point(float(i+1)/42)-Vector2(3,0)
		var lit: bool = readouts.rpm >= float(i+1)/42*14000
		var color := INK if (float(i)/42*14000 < readouts.redline-800) else Color("81522e")
		draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,18),a+Vector2(0,18)]),color if lit else GHOST)
	for i in range(1,15):
		var pos := _tach_point(float(i)/14)
		text_at(str(i),pos+Vector2(-9,-9),18)
	text_at("RPM x 1000",Vector2(52,182),17)
	text_at("km/h",Vector2(60,217),24)
	digits("%03d" % readouts.speed,Vector2(58,240),104)
	draw_line(Vector2(316,191),Vector2(316,361),Color("819075"),2)
	text_at("GEAR",Vector2(351,217),24)
	digits(readouts.gear,Vector2(357,242),103)
	draw_line(Vector2(469,191),Vector2(469,361),Color("819075"),2)
	text_at("LAP  "+readouts.lap,Vector2(510,187),23)
	for row in range(3):
		var title: String = ["TIME","LAST","BEST"][row]
		var value: String = [readouts.current,readouts.last,readouts.best][row]
		var y := 219.0+row*48
		text_at(title,Vector2(510,y+25),19)
		digits(value,Vector2(605,y),38)
	draw_line(Vector2(38,367),Vector2(922,367),Color("819075"),2)
	text_at("FUEL",Vector2(54,412),23)
	digits("%04.1f" % readouts.fuel,Vector2(133,384),32)
	text_at("L",Vector2(238,413),21)
	var status := "ENGINE OFF" if not readouts.engine else ("PIT LIMIT" if readouts.limiter else "RUN")
	if readouts.servicing:
		status = "REFUELLING  /  %.1f s" % readouts.service_remaining
	text_at(status,Vector2(920-font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x,412),21)

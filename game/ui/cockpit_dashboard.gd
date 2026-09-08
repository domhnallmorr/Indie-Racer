extends Control
## Speed, RPM and gear are live; remaining engine/lap fields are placeholders.
var font := ThemeDB.fallback_font
var player: Node
var last_speed := -1
var refresh_time := 0.0

func _process(delta: float) -> void:
	var speed := int(round(absf(player.speed_mps) * 3.6)) if is_instance_valid(player) else 0
	refresh_time += delta
	if speed != last_speed or refresh_time >= .05:
		refresh_time = 0
		last_speed = speed
		queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(640, 320)
	queue_redraw()

func text_at(text: String, pos: Vector2, size: int, color := Color("202720")) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	draw_rect(Rect2(0,0,640,320), Color("a8b3a0"))
	draw_rect(Rect2(8,8,624,304), Color("28332c"), false, 4)
	text_at("OVAL 95     /     PRACTICE", Vector2(24,36), 22)
	text_at("RPM x 1000", Vector2(24,64), 18)
	for i in range(14):
		var rpm: float = player.engine_rpm if is_instance_valid(player) else 0
		var active := rpm >= (i+1)*1000
		var ink := Color("283b20") if i < 12 else Color("913c23")
		draw_rect(Rect2(24+i*42,78,34,26), ink if active else Color("85937e"))
		text_at(str(i+1),Vector2(27+i*42,122),15)
	text_at("km/h",Vector2(28,155),22)
	text_at("%03d" % maxi(0,last_speed),Vector2(24,229),74)
	text_at("GEAR",Vector2(230,155),22)
	text_at(player.gear_text if is_instance_valid(player) else "N",Vector2(248,229),60)
	text_at("LAP",Vector2(390,155),22)
	text_at("--",Vector2(390,211),48)
	text_at("TIME  --:--.---",Vector2(24,272),25)
	text_at("FUEL  -- L",Vector2(355,256),23)
	text_at("WATER  -- °C",Vector2(355,288),23)

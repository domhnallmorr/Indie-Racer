extends Label
## Lightweight display; never intercepts driving or UI input.
var next_refresh_ms := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -100
	offset_top = -32
	offset_right = -12
	offset_bottom = -10
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size",14)
	add_theme_color_override("font_outline_color",Color(0,0,0,.9))
	add_theme_constant_override("outline_size",4)
	text = "-- FPS"

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now < next_refresh_ms:
		return
	next_refresh_ms = now+250
	var fps := Engine.get_frames_per_second()
	text = "%d FPS" % fps if fps > 0 else "-- FPS"

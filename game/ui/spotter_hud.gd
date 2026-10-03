extends PanelContainer

var practice: Node
var spotter = preload("res://game/race/spotter.gd").new()
var label: Label
var clear_seconds := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -240
	offset_right = 240
	offset_top = 155
	offset_bottom = 205
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.022, 0.88)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	spotter.callout.connect(_on_callout)
	hide()

func _physics_process(delta: float) -> void:
	if not practice.player.driving_enabled:
		spotter.reset()
		clear_seconds = 0.0
		hide()
		return
	clear_seconds = maxf(0.0, clear_seconds - delta)
	spotter.update(practice.player, practice.ai_cars, delta)
	visible = spotter.occupied_sides != 0 or clear_seconds > 0.0

func _on_callout(message: String, occupied_sides: int) -> void:
	label.text = "SPOTTER  •  " + message
	label.modulate = Color("ffcf42") if occupied_sides != 0 else Color("8ee6a1")
	clear_seconds = 2.0 if occupied_sides == 0 else 0.0

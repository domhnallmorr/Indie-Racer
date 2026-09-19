extends PanelContainer

var practice: Node
var shell: Control
var wheel_host: MarginContainer
var wheel_panel: PanelContainer

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.72)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",24)
	scroll.add_child(layout)
	var help := VBoxContainer.new()
	help.custom_minimum_size.x = 300
	layout.add_child(help)
	var title := Label.new()
	title.text = "DRIVING & CAMERA"
	title.add_theme_font_size_override("font_size",18)
	help.add_child(title)
	var guide := Label.new()
	guide.text = "W / S\nThrottle / brake\n\nA / D\nSteer\n\nQ / E\nShift down / up\n\nM\nAutomatic / manual\n\nV / N\nReverse / neutral\n\nR\nReset to pit box or grid\n\n1–4\nExterior cameras\n\n5\nCockpit camera\n\n6 / 7\nPrevious / next opponent\n\nT\nTV trackside camera\n\nNumpad + / -\nNext / previous car in track order\n\nCockpit: [ / ] FOV\nPgUp / PgDn seat height\nHome resets cockpit view"
	guide.text += "\n\nF1 / F2 / F3\nLap Timing / Standings / Fuel panel"
	guide.add_theme_font_size_override("font_size",14)
	help.add_child(guide)
	wheel_host = MarginContainer.new()
	wheel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(wheel_host)
	call_deferred("_embed_wheel_setup")

func _embed_wheel_setup() -> void:
	if not is_instance_valid(practice) or not is_instance_valid(practice.player.wheel_input):
		return
	wheel_panel = practice.player.wheel_input.panel
	if not is_instance_valid(wheel_panel):
		return
	var old_parent := wheel_panel.get_parent()
	old_parent.remove_child(wheel_panel)
	wheel_host.add_child(wheel_panel)
	wheel_panel.position = Vector2.ZERO
	wheel_panel.custom_minimum_size = Vector2(0,0)
	wheel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel_panel.show()

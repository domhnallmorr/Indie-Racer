extends Control

var practice: Node
var timing: Node
var active_page := ""
var driving_was_enabled := true

@onready var pages: Dictionary = {
	"session": $Shell/Layout/Content/Pages/RosterPanel,
	"timing": $Shell/Layout/Content/Pages/TimingPanel,
	"controls": $Shell/Layout/Content/Pages/ControlsPanel,
	"diagnostics": $Shell/Layout/Content/Pages/PhysicsDebug,
}
@onready var page_title: Label = $Shell/Layout/Content/PageTitle

func _ready() -> void:
	$Shell/Layout/Navigation/Buttons/Drive.pressed.connect(close_shell)
	$Shell/Layout/Navigation/Buttons/Session.pressed.connect(open_page.bind("session"))
	$Shell/Layout/Navigation/Buttons/Timing.pressed.connect(open_page.bind("timing"))
	$Shell/Layout/Navigation/Buttons/Controls.pressed.connect(open_page.bind("controls"))
	$Shell/Layout/Navigation/Buttons/Diagnostics.pressed.connect(open_page.bind("diagnostics"))
	for page in pages.values():
		page.hide()
	hide()

func open_page(page_name: String) -> void:
	if not pages.has(page_name):
		return
	if visible and active_page == page_name:
		close_shell()
		return
	active_page = page_name
	for name in pages:
		pages[name].visible = name == page_name
	page_title.text = {
		"session": "SESSION",
		"timing": "TIMING & STANDINGS",
		"controls": "CONTROLS",
		"diagnostics": "DIAGNOSTICS",
	}[page_name]
	if page_name == "timing":
		pages[page_name].refresh()
	if not visible:
		driving_was_enabled = practice.player.driving_enabled
	show()
	practice.get_node("HUD/Panel").hide()
	practice.get_node("HUD/BlackBox").hide()
	practice.player.driving_enabled = false

func close_shell() -> void:
	hide()
	practice.get_node("HUD/Panel").show()
	practice.get_node("HUD/BlackBox").show()
	practice.player.driving_enabled = driving_was_enabled
	active_page = ""

func toggle_page(page_name: String) -> void:
	open_page(page_name)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var page_name := ""
	match event.keycode:
		KEY_F12: page_name = "session"
		KEY_F10: page_name = "controls"
		KEY_8: page_name = "diagnostics"
		KEY_9: page_name = "timing"
		KEY_ESCAPE:
			if visible:
				close_shell()
				get_viewport().set_input_as_handled()
			return
	if not page_name.is_empty():
		toggle_page(page_name)
		get_viewport().set_input_as_handled()

extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var menu = load("res://game/main/menu.tscn").instantiate()
	root.add_child(menu)
	menu._on_race_weekend_pressed()
	for frame in range(5):
		await process_frame
	var panel: Control = menu.get_node("Center/WeekendSetup/Panel")
	var fits := Rect2(Vector2.ZERO,Vector2(root.size)).encloses(panel.get_global_rect())
	var defaults := is_equal_approx(menu.fuel_select.value,35.0)
	defaults = defaults and is_equal_approx(menu.strength_select.value,100.0)
	defaults = defaults and menu.incident_select.selected == 2
	menu.incident_select.select(1)
	menu.strength_select.value = 120
	var strength_label: bool = menu.strength_label.text == "AI STRENGTH: 120"
	menu.fuel_select.value = 3
	menu._on_setup_continue_pressed()
	var summary: bool = "3 gal tank" in menu.race_summary.text
	summary = summary and "AI strength: 120" in menu.race_summary.text
	var saved: bool = root.get_meta("roster_selection").ai_strength == 120
	saved = saved and root.get_meta("roster_selection").incident_mode == "ai_only"
	print("SETUP bounds=",panel.get_global_rect()," default=",defaults," summary=",summary)
	menu.free()
	root.set_meta("return_to_weekend",true)
	menu = load("res://game/main/menu.tscn").instantiate()
	root.add_child(menu)
	var restored: bool = menu.strength_select.value == 120 and "AI strength: 120" in menu.race_summary.text
	restored = restored and menu.incident_select.selected == 1
	menu.free()
	print("STRENGTH label=",strength_label," saved=",saved," restored=",restored)
	quit(0 if fits and defaults and summary and strength_label and saved and restored else 1)

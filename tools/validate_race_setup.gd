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
	menu.fuel_select.value = 3
	menu._on_setup_continue_pressed()
	var summary: bool = "3 gal tank" in menu.race_summary.text
	print("SETUP bounds=",panel.get_global_rect()," default=",defaults," summary=",summary)
	menu.free()
	quit(0 if fits and defaults and summary else 1)

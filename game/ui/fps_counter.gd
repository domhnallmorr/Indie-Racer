extends Label
## Lightweight display; never intercepts driving or UI input.
var next_refresh_ms := 0
var practice: Node
var diagnostics_directory := "user://telemetry"
var diagnostics_path := ""
const MAX_HITCHES := 128
var last_frame_usec := 0
var last_physics_frame := 0
var measured_frames := 0
var measured_ms := 0.0
var worst_frame_ms := 0.0
var frames_over_33ms := 0
var frames_over_50ms := 0
var minimum_reported_fps := 0
var hitches: Array[Dictionary] = []
var next_hitch := 0
var report_context: Dictionary = {}

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
	_record_frame(Time.get_ticks_usec())
	var now := Time.get_ticks_msec()
	if now < next_refresh_ms:
		return
	next_refresh_ms = now+250
	var fps := Engine.get_frames_per_second()
	text = "%d FPS" % fps if fps > 0 else "-- FPS"
	if measured_ms >= 1000 and last_frame_usec > 0 and fps > 0:
		minimum_reported_fps = fps if minimum_reported_fps == 0 else mini(minimum_reported_fps,fps)

func _record_frame(now_usec: int) -> void:
	# Keep normal driving free of diagnostic disk writes. Only retain a bounded
	# in-memory history; scene shutdown saves the report alongside telemetry.
	if DisplayServer.get_name() == "headless" or not is_instance_valid(practice) or practice.session == null or practice.session.status != practice.session.Status.RUNNING:
		last_frame_usec = 0
		return
	var physics_frame := Engine.get_physics_frames()
	if last_frame_usec == 0:
		last_frame_usec = now_usec
		last_physics_frame = physics_frame
		if report_context.is_empty():
			report_context = {"track":practice.track_session_file,"seed":practice.active_seed,"session_mode":practice.session_mode,"ai_cars":practice.ai_cars.size(),"window_size":str(DisplayServer.window_get_size()),"window_mode":DisplayServer.window_get_mode(),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method")}
		return
	var frame_ms := (now_usec-last_frame_usec)/1000.0
	var physics_ticks := physics_frame-last_physics_frame
	last_frame_usec = now_usec
	last_physics_frame = physics_frame
	measured_frames += 1
	measured_ms += frame_ms
	worst_frame_ms = maxf(worst_frame_ms,frame_ms)
	if frame_ms <= 33.333:
		return
	frames_over_33ms += 1
	if frame_ms > 50.0:
		frames_over_50ms += 1
	var camera := get_viewport().get_camera_3d()
	var hitch := {"elapsed_s":measured_ms/1000.0,"frame_ms":frame_ms,"physics_ticks":physics_ticks,"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"camera":str(camera.get_path()) if camera != null else "none","player_speed_kph":practice.player.speed_mps*3.6,"player_position":str(practice.player.global_position),"window_size":str(DisplayServer.window_get_size()),"window_mode":DisplayServer.window_get_mode()}
	if hitches.size() < MAX_HITCHES:
		hitches.append(hitch)
	else:
		hitches[next_hitch] = hitch
	next_hitch = (next_hitch+1)%MAX_HITCHES

func _exit_tree() -> void:
	if measured_frames == 0:
		return
	if DirAccess.make_dir_recursive_absolute(diagnostics_directory) != OK:
		return
	diagnostics_path = diagnostics_directory+"/frame_times_"+Time.get_datetime_string_from_system().replace(":","-")+"_"+str(Time.get_ticks_msec())+".json"
	var file := FileAccess.open(diagnostics_path,FileAccess.WRITE)
	if file == null:
		push_warning("Could not save frame diagnostics")
		return
	hitches.sort_custom(func(a,b): return a.elapsed_s < b.elapsed_s)
	var report := report_context.duplicate()
	report.measured_frames = measured_frames
	report.mean_frame_ms = measured_ms/measured_frames
	report.worst_frame_ms = worst_frame_ms
	report.minimum_reported_fps = minimum_reported_fps
	report.frames_over_33ms = frames_over_33ms
	report.frames_over_50ms = frames_over_50ms
	report.recent_hitches = hitches
	report.monitor_note = "Physics/draw-call monitors are engine snapshots, not isolated timings for each hitch. History retains the latest 128 frames above 33.333 ms; aggregate counts cover the whole running session."
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("Frame diagnostics saved: ",ProjectSettings.globalize_path(diagnostics_path))

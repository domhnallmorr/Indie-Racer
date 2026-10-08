extends "res://tools/compare_tyre_falloff.gd"
var free_front := true
func make_sim(width: float, fine := false):
 var sim = fine_model.new() if fine else Model.new()
 sim.configure(parameters.duplicate(true))
 sim.p.post_peak_falloff = width
 sim.direct_steering = true
 sim.experimental_wheel_motion = true
 sim.independent_front_rotation = free_front
 return sim
func _initialize():
 call_deferred("validate")
func seeded(speed: float):
 var sim = make_sim(2.0)
 sim.u = speed
 sim.gear = 0
 sim.front_omega = speed/parameters.front_radius_m
 sim.rear_omega = speed/parameters.rear_radius_m
 return sim
func corner(speed: float, direction: float, fine := false) -> Dictionary:
 var sim = make_sim(2.0,fine)
 sim.u = speed
 sim.gear = 0
 sim.front_omega = speed/parameters.front_radius_m
 sim.rear_omega = speed/parameters.rear_radius_m
 for i in range(600):
  sim.u = speed
  sim.advance(1.0/60,0,0,direction*4.0/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length()))
 return {"speed":speed,"free_front":free_front,"yaw":rad_to_deg(sim.yaw_rate),"beta":beta(sim),"front_slip":rad_to_deg(sim.front_slip_angle),"wheel_speed_difference":sim.front_right_omega-sim.front_left_omega}
func validate():
 var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_tyre_falloff.json"))
 var meta := ConfigFile.new()
 assert(meta.load(fixture.metadata)==OK)
 parameters = meta.get_value("run","physics")
 var source := FileAccess.get_file_as_string("res://game/vehicle/bicycle_model.gd")
 fine_model = GDScript.new()
 fine_model.source_code = source.replace("MAX_INTEGRATION_STEP_S := .0005","MAX_INTEGRATION_STEP_S := .00025").replace(".8/clutch_rate",".4/clutch_rate")
 assert(fine_model.reload()==OK)
 for abs_strength in [0.0,1.0]:
  parameters.anti_lock_brakes = abs_strength
  for braking in [0.0,.3,1.0]:
   free_front = false
   var shared = seeded(40.0)
   free_front = true
   var independent = seeded(40.0)
   for i in range(240):
    shared.advance(1.0/60,0,braking,0)
    independent.advance(1.0/60,0,braking,0)
    check(absf(shared.u-independent.u)<.000001,"Straight braking unchanged")
    check(absf(independent.front_left_omega-independent.front_right_omega)<.000001,"Straight wheel speed symmetry")
    check(absf(independent.yaw_rate)<.000001,"Straight braking introduces no yaw")
 parameters.anti_lock_brakes = 1.0
 for speed in [15.0,25.0,40.0]:
  free_front = false
  var shared := corner(speed,1)
  free_front = true
  var left := corner(speed,1)
  var right := corner(speed,-1)
  var fine := corner(speed,1,true)
  check(absf(left.yaw+right.yaw)<.000001,"Mirrored corner yaw")
  check(absf(left.beta+right.beta)<.000001,"Mirrored corner sideslip")
  check(absf(left.yaw-fine.yaw)<.1,"Steady yaw converges with halved step")
  check(absf(left.wheel_speed_difference)>1,"Front wheel speeds separate in a turn")
  print("FREE FRONT CORNER shared=%s independent=%s" % [shared,left])
 for window in fixture.windows:
  free_front = false
  var old := replay(window,fixture.columns,2.0,1)
  free_front = true
  var current := replay(window,fixture.columns,2.0,1)
  var fine := replay(window,fixture.columns,2.0,2)
  var error := 0.0
  for i in range(current.trace.size()):
   error = maxf(error,absf(current.trace[i][1]-fine.trace[i][1]))
  # Budget 0.2 degrees across the whole open-loop trace, including spins.
  # Report the actual error; trajectory stability is a separate driving result.
  check(error<.2,window.name+": sideslip convergence under step refinement")
  print("FREE FRONT REPLAY %s old=%.3f new=%.3f refinement_error=%.4f" % [window.name,old.peak_beta,current.peak_beta,error])
 var sim = seeded(20.0)
 sim.advance(1.0/60,0,0,.2)
 sim.reset()
 check(sim.front_left_omega==0 and sim.front_right_omega==0,"Reset clears both wheel speeds")
 check(sim.independent_front_rotation,"Reset preserves free-front selection")
 for failure in failures: push_error(failure)
 if failures.is_empty(): print("FREE FRONT PASSED: straight coast/braking with ABS on/off, corner symmetry, independent rotation, reset and integration convergence.")
 quit(0 if failures.is_empty() else 1)

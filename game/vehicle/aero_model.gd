extends RefCounted
## ICR2 report reconstruction. Internal coefficients require a calibrated area scale.
## The wing efficiency curve is the report's continuous approximation.
static func areas(package: String, front_deg: float, rear_deg: float, scale: float) -> Dictionary:
	var body_drag := 28000.0 if package == "speedway" else 33000.0
	var body_df := body_drag*(2.60 if package == "speedway" else 2.55)
	var front := _wing(front_deg,1.0)
	var rear := _wing(rear_deg,2.0)
	var total_df := body_df+front.y+rear.y
	return {
		"drag_area_m2": (body_drag+front.x+rear.x)*scale,
		"downforce_area_m2": total_df*scale,
		"front_downforce_fraction": (body_df/3.0+front.y)/total_df,
	}

static func _wing(degrees: float, multiplier: float) -> Vector2:
	var angle := roundf(clampf(degrees,3.0,18.0)*100.0)
	var drag := 50.0*multiplier+floorf(13100.0*multiplier*(angle-300.0)/1500.0)
	var efficiency := 4.5/(0.5+(angle/100.0-3.0)/15.0)
	return Vector2(drag,drag*efficiency)

static func apply(parameters: Dictionary, package: String, front_deg: float, rear_deg: float) -> void:
	parameters["body_package"] = package
	parameters["front_wing_deg"] = snappedf(clampf(front_deg,3.0,18.0),0.01)
	parameters["rear_wing_deg"] = snappedf(clampf(rear_deg,3.0,18.0),0.01)
	parameters.merge(areas(package,parameters.front_wing_deg,parameters.rear_wing_deg,parameters.coefficient_area_scale),true)

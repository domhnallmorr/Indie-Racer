shader_type spatial;

uniform mat4 world_to_track;
uniform bool outer_wall = false;
uniform vec4 concrete_color : source_color = vec4(0.57, 0.545, 0.50, 1.0);
uniform vec4 paint_color : source_color = vec4(0.94, 0.935, 0.915, 1.0);
uniform float block_width_m : hint_range(6.0, 7.0) = 6.5;
varying vec3 track_position;
varying vec3 track_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x),
		mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
// s along the reference line and radius of the actual wall, in metres.
vec2 oval_coordinates(vec2 p) {
	const float straight = 411.9729183;
	const float arc = 392.6990817;
	if (abs(p.x) > straight*0.5) {
		vec2 radial = vec2(p.x-sign(p.x)*straight*0.5, -p.y);
		float angle = atan(radial.y, radial.x);
		if (p.x > 0.0) {
			return vec2(straight+(angle+PI*0.5)*125.0, length(radial));
		}
		if (angle < PI*0.5) { angle += TAU; }
		return vec2(2.0*straight+arc+(angle-PI*0.5)*125.0, length(radial));
	}
	return vec2(p.y >= 0.0 ? p.x+straight*0.5 : straight+arc+straight*0.5-p.x, abs(p.y));
}
float rubber_patch(vec2 p, float center, float half_length, float height, float seed) {
	float x = p.x-center;
	float y = p.y-height + (noise(vec2(p.x*.7, seed))-.5)*.09;
	float edge = abs(x)/half_length;
	float band = 1.0-smoothstep(.08, .22, abs(y));
	float ends = 1.0-smoothstep(.65, 1.0, edge+(noise(p*vec2(2.0, 9.0)+seed)-.5)*.18);
	float streak_detail = mix(noise(p*vec2(.8, 38.0)+seed), .5,
		smoothstep(.008, .045, fwidth(p.y)));
	float streaks = .45+.55*streak_detail;
	return band*ends*streaks;
}
void vertex() {
	track_position = (world_to_track * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	track_normal = mat3(world_to_track) * MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
	const float straight = 411.9729183;
	const float arc = 392.6990817;
	vec2 oval = oval_coordinates(track_position.xz);
	float s = oval.x;
	// Centre radius makes joints line up across the half-metre wall thickness.
	float radius = outer_wall ? 135.5 : (oval.y < 98.0 ? 87.0 : 108.0);
	float wall_s = min(s, straight)
		+ clamp(s-straight, 0.0, arc)*radius/125.0
		+ clamp(s-straight-arc, 0.0, straight)
		+ max(s-2.0*straight-arc, 0.0)*radius/125.0;
	float perimeter = 2.0*straight+TAU*radius;
	float spacing = perimeter/round(perimeter/block_width_m);
	vec2 p = vec2(wall_s, track_position.y);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float grain = mix(noise(p*65.0), .5, smoothstep(.01, .07, footprint));
	float mottling = noise(p*vec2(.6, 2.0))-.5;
	vec3 base = outer_wall ? paint_color.rgb : concrete_color.rgb;
	base *= 1.0+mottling*.085+(grain-.5)*.07;
	float side = 1.0-smoothstep(.3, .8, abs(normalize(track_normal).y));
	float dirt = 1.0-smoothstep(.03, .35, track_position.y);
	base *= 1.0-dirt*.12;
	if (!outer_wall) {
		float block = floor(wall_s/spacing);
		base *= .97+.06*hash(vec2(block, radius));
		float joint_distance = abs(mod(wall_s+spacing*.5, spacing)-spacing*.5);
		float aa = max(fwidth(wall_s), .003);
		float joint = 1.0-smoothstep(.018-aa, .018+aa, joint_distance);
		base = mix(base, base*.40, joint*.85);
	} else {
		// Signed distance around each exit: T2 at half-lap, T4 at lap wrap.
		float exit_distance = mod(s+402.336, 804.672)-402.336;
		float seed = s > 402.336 && s < 1207.008 ? 17.0 : 43.0;
		// Follow the banked wall's base on the final metres of the turn.
		float ramp = clamp(-exit_distance/100.0, 0.0, 1.0);
		float bank = radians(9.0)*ramp*ramp*ramp*(10.0-15.0*ramp+6.0*ramp*ramp);
		float height = track_position.y-max(0.0, oval.y-115.0)*tan(bank);
		vec2 rub = vec2(exit_distance, height);
		float marks = rubber_patch(rub, -20.0, 9.0, .43, seed);
		marks = max(marks, rubber_patch(rub, -4.0, 6.5, .55, seed+3.0));
		marks = max(marks, rubber_patch(rub, 12.0, 11.0, .39, seed+8.0));
		marks = max(marks, rubber_patch(rub, 29.0, 4.0, .60, seed+11.0));
		vec2 outward = abs(track_position.x) > straight*.5
			? normalize(vec2(track_position.x-sign(track_position.x)*straight*.5, track_position.z))
			: vec2(0.0, sign(track_position.z));
		float track_face = smoothstep(.2, .8, -dot(normalize(track_normal).xz, outward));
		base = mix(base, vec3(.018, .016, .014), clamp(marks*1.35, 0.0, .96)*side*track_face);
	}
	ALBEDO = base;
	ROUGHNESS = .94;
	SPECULAR = .15;
}

shader_type spatial;
uniform vec3 base_color = vec3(0.45);
uniform bool concrete = false;
varying vec2 p;
float hash(vec2 v) {
	return fract(sin(dot(v,vec2(127.1,311.7))) * 43758.5453);
}
void vertex() {
	p = VERTEX.xz;
}
void fragment() {
	float footprint = max(length(dFdx(p)),length(dFdy(p)));
	float grain = mix(hash(floor(p*35.0)),0.5,smoothstep(0.02,0.12,footprint));
	vec3 color = base_color + (grain-0.5)*0.045;
	if (concrete) {
		vec2 cell = floor(p/6.0);
		color += (hash(cell)-0.5)*0.035;
		vec2 edges = abs(fract(p/6.0+0.5)-0.5)*6.0;
		float seam = 1.0-smoothstep(0.018,0.018+max(footprint,0.02),min(edges.x,edges.y));
		color *= 1.0-seam*0.18*min(1.0,0.08/max(footprint,0.001));
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}

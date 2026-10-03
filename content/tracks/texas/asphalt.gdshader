shader_type spatial;
// UV: lap metres / metres outward from inner edge. UV2: racing-groove offset / road width.
uniform bool racing_surface = true;
uniform vec4 turn_limits = vec4(327.558,1004.833,1409.868,2084.773);
uniform float lap_length = 2414.016;
uniform float rubber_strength : hint_range(0.0,0.8) = 0.42;
uniform float dash_length = 3.0;
uniform float dash_period = 12.0;
uniform float line_width = 0.15;
varying vec2 local_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float band(float p,float half_width,float aa) { return 1.0-smoothstep(half_width-aa,half_width+aa,abs(p)); }
void vertex() { local_position=VERTEX.xz; }
void fragment() {
 vec2 p=local_position;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float aggregate=mix(noise(p*85.0),0.5,smoothstep(.006,.055,footprint));
 float mottling=noise(p*.25)*.6+noise(p*1.8)*.4;
 vec3 asphalt=vec3(.37,.375,.38)+vec3((mottling-.5)*.045+(aggregate-.5)*.10);
 float rubber=0.0;
 float paint=0.0;
 if (racing_surface) {
  float s=UV.x, lateral=UV.y;
  float aa=max(fwidth(lateral),.012);
  // Long paving seams follow the banking and curve with the track.
  float seam_distance=abs(mod(lateral+2.375,4.75)-2.375);
  float seam=1.0-smoothstep(.022,.022+aa,seam_distance);
  asphalt*=1.0-.16*seam;
  float across=lateral-UV2.x;
  float feather=(noise(vec2(s*.09,lateral*1.2))-.5)*.4;
  float groove=1.0-smoothstep(.6,3.1,abs(across)+feather);
  float turn=max(smoothstep(turn_limits.x,turn_limits.x+70.0,s)*(1.0-smoothstep(turn_limits.y-70.0,turn_limits.y,s)),smoothstep(turn_limits.z,turn_limits.z+70.0,s)*(1.0-smoothstep(turn_limits.w-70.0,turn_limits.w,s)));
  float streak=mix(noise(vec2(p.x*.09+p.y*.07,across*9.0)),.5,smoothstep(.03,.25,footprint));
  rubber=groove*(.40+.60*turn)*(.72+.28*streak);
  rubber*=smoothstep(.2,1.0,lateral)*(1.0-smoothstep(UV2.y-1.0,UV2.y-.2,lateral));
  // Two parallel separators on the front tri-oval and backstraight only.
  float straight=1.0;
  if ((s>turn_limits.x && s<turn_limits.y)||(s>turn_limits.z && s<turn_limits.w)) { straight=0.0; }
  float section_s=s-turn_limits.y;
  if (s<=turn_limits.x || s>=turn_limits.w) { section_s=mod(s-turn_limits.w+lap_length,lap_length); }
  float phase=mod(section_s,dash_period);
  float along_aa=max(fwidth(s),.02);
  float dash=band(phase-dash_length*.5,dash_length*.5,along_aa);
  float lines=max(band(lateral-UV2.y/3.0,line_width*.5,aa),band(lateral-UV2.y*2.0/3.0,line_width*.5,aa));
  paint=straight*dash*lines;
 }
 asphalt*=1.0-rubber_strength*rubber;
 float wear=.90+.10*noise(p*18.0);
 ALBEDO=mix(asphalt,vec3(.82,.81,.77)*wear,paint);
 ROUGHNESS=mix(.95-.10*rubber,.84,paint);
 SPECULAR=.16;
}

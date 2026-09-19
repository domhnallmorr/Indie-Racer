shader_type spatial;
// Track-local coordinates keep the material attached when the scene is moved.
uniform vec3 track_origin = vec3(0.0);
uniform sampler2D racing_line_map : filter_linear, repeat_enable;
uniform float rubber_strength : hint_range(0.0, 0.3) = 0.15;
uniform float rubber_half_width_m : hint_range(1.0, 4.0) = 2.2;
varying vec2 road_position;
float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float noise(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Metres along the oval and metres out from its centreline.
// This bends repairs with the corners rather than aligning them to world axes.
vec2 track_coordinates(vec2 p) {
 const float straight = 411.9729183;
 const float arc = 392.6990817;
 float s;
 float lateral;
 if (p.x > straight*.5) {
  vec2 radial = vec2(p.x-straight*.5,-p.y);
  s = straight + (atan(radial.y,radial.x)+1.5707963268)*125.0;
  lateral = length(radial)-125.0;
 } else if (p.x < -straight*.5) {
  vec2 radial = vec2(p.x+straight*.5,-p.y);
  float angle = atan(radial.y,radial.x);
  if (angle < 1.5707963268) { angle += 6.2831853072; }
  s = 2.0*straight+arc+(angle-1.5707963268)*125.0;
  lateral = length(radial)-125.0;
 } else {
  s = p.y >= 0.0 ? p.x+straight*.5 : straight+arc+straight*.5-p.x;
  lateral = abs(p.y)-125.0;
 }
 return vec2(s,lateral);
}
void vertex() {
 road_position = ((MODEL_MATRIX * vec4(VERTEX,1.0)).xyz - track_origin).xz;
}
void fragment() {
 vec2 p = road_position;
 float broad = noise(p*.32)*.65 + noise(p*1.7)*.35;
 // Fade subpixel aggregate to its mean, avoiding sparkle in the distance.
 float footprint = max(length(dFdx(p)),length(dFdy(p)));
 float grain = mix(noise(p*75.0),.5,smoothstep(.008,.06,footprint));
 vec3 asphalt = vec3(.48,.48,.47) + vec3((broad-.5)*.024 + (grain-.5)*.038);
 vec2 road = track_coordinates(p);
 vec2 cell_size = vec2(1609.344/80.0,8.0);
 vec2 cell = floor(road / cell_size);
 float patch = 0.0;
 float repair_tone = .6;
 for (int y=-1; y<=1; y++) {
  for (int x=-1; x<=1; x++) {
   vec2 id = cell + vec2(float(x),float(y));
   id.x = mod(id.x,80.0);
   float seed = hash(id);
   if (seed > .84) {
    vec2 center = (id + vec2(.2+.6*hash(id+7.1),.2+.6*hash(id+15.3))) * cell_size;
    float angle = (hash(id+31.7)-.5)*.06;
    vec2 delta = road-center;
    delta.x = mod(delta.x+804.672,1609.344)-804.672;
    vec2 q = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * delta;
    vec2 half_size = vec2(1.0+3.0*hash(id+41.0),.6+1.3*hash(id+63.0));
    if (hash(id+55.0) > .6) {
     half_size = vec2(3.5+4.0*hash(id+41.0),.22+.33*hash(id+63.0));
    }
    // Different aspect ratios, clipped corners and ragged edges on every repair.
    float edge = max(abs(q.x)-half_size.x,abs(q.y)-half_size.y);
    float corner = (abs(q.x)+abs(q.y)-half_size.x-half_size.y+hash(id+88.0)*.15*min(half_size.x,half_size.y))*.707;
    edge = max(edge,corner);
    edge += (noise(p*5.0+id)-.5)*.06;
    float aa = max(.025,footprint*.7);
    float mask = 1.0-smoothstep(-aa,aa,edge);
    if (mask > patch) {
     patch = mask;
     repair_tone = .50+.28*hash(id+103.0);
    }
   }
  }
 }
 // Rubber follows the authored racing line, strictly inside the two turns.
 // The 45 m end fades remove it entirely before either straight begins.
 float turn_s = mod(road.x,804.672)-411.9729183;
 float corner = smoothstep(0.0,45.0,turn_s)*(1.0-smoothstep(347.6990817,392.6990817,turn_s));
 float line_offset = texture(racing_line_map,vec2(road.x/1609.344,.5)).r*20.0-10.0;
 float across_line = road.y-line_offset;
 float feather = (noise(vec2(road.x*.12,road.y*.9))-.5)*.3;
 float groove = 1.0-smoothstep(rubber_half_width_m*.3,rubber_half_width_m+1.0,abs(across_line)+feather);
 float streak = mix(noise(vec2(road.x*.075,across_line*7.0)),.5,smoothstep(.04,.22,footprint));
 float rubber = corner*groove*(.8+.2*streak);
 // Keep apron/pit lane and the painted track edges clean.
 rubber *= 1.0-smoothstep(8.8,9.5,abs(road.y));
 ALBEDO = mix(asphalt,asphalt*repair_tone,patch)*(1.0-rubber_strength*rubber);
 ROUGHNESS = .96-.025*rubber;
 SPECULAR = .12;
}



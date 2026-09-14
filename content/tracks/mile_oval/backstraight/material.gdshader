shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform float strip = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
 vec2 coord;
 if (strip < 0.5) { coord = world_pos.xz / 3.0; }
 else if (strip < 1.5) {
  coord = abs(world_normal.x) > 0.7 ? world_pos.zy / 3.0 : world_pos.xy / 3.0;
 } else { coord = vec2(UV.x, world_pos.y / 3.0); }
 vec2 tile = fract(coord);
 vec2 uv = vec2((strip + mix(0.006, 0.994, tile.x)) / 3.0, mix(0.003, 0.997, tile.y));
 ALBEDO = texture(atlas, uv).rgb;
 ROUGHNESS = 1.0;
}

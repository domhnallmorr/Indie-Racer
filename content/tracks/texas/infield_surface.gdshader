shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(.40,.43,.25,1.0);
uniform vec4 secondary_color : source_color = vec4(.52,.46,.31,1.0);
uniform int surface_kind = 0; // 0 rough turf, 1 maintained turf, 2 concrete, 3 asphalt

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 p=UV;
    float footprint=max(length(dFdx(p)),length(dFdy(p)));
    float grain=mix(noise(p*24.0),.5,smoothstep(.03,.3,footprint));
    float patches=noise(p*.038)*.65+noise(p*.13)*.35;
    vec3 color=base_color.rgb;
    if (surface_kind < 2) {
        float mix_amount=smoothstep(.28,.75,patches)*(surface_kind==0 ? .8 : .20);
        color=mix(color,secondary_color.rgb,mix_amount);
        color*=.92+.16*noise(p*.7)+(grain-.5)*.09;
        if(surface_kind==1) { color*=1.0+.025*sin(p.x*.6); }
    } else {
        color*=.94+.12*patches+(grain-.5)*.08;
        if(surface_kind==2) {
            vec2 grid=abs(mod(p+4.0,8.0)-4.0);
            float aa=max(footprint,.02);
            float seams=1.0-smoothstep(.025,.025+aa,min(grid.x,grid.y));
            color*=1.0-seams*.035;
        }
    }
    ALBEDO=color;
    ROUGHNESS=.97;
    SPECULAR=.12;
}

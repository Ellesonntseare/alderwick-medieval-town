shader_type spatial;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap;
uniform vec4 ground_tint : source_color = vec4(1.0);
uniform vec2 half_size = vec2(15.3,15.15);
varying vec3 patch_position;
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){patch_position=VERTEX;world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 p=world_position.xz*.08;
    vec2 i=floor(p);vec2 f=smoothstep(vec2(0.0),vec2(1.0),fract(p));
    float n=mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
    vec3 grass=mix(vec3(.19,.27,.12),vec3(.34,.41,.20),n);
    float edge=min(half_size.x-abs(patch_position.x),half_size.y-abs(patch_position.z));
    ALBEDO=mix(grass,texture(ground_texture,UV).rgb*ground_tint.rgb,smoothstep(0.0,3.0,edge));
    ROUGHNESS=1.0;
}

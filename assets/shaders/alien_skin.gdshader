shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 skin_color : source_color = vec4(.4,.9,.7,1.0);
uniform vec3 mesh_origin = vec3(0.0);
uniform vec3 mesh_size = vec3(1.0);
varying vec3 skin_position;

float hash3(vec3 p) {
	p = fract(p * .1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float grain(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
	skin_position = (VERTEX - mesh_origin) / max(mesh_size,vec3(.001));
}
void fragment() {
	float tissue = grain(skin_position * 9.0);
	float pores = grain(skin_position * 82.0);
	float folds = abs(grain(skin_position * 27.0) - .5);
	float relief = tissue * .3 + pores * .1 + folds * .25;
	ALBEDO = skin_color.rgb * (.82 + .25 * tissue) * (1.0 - .08 * smoothstep(.66,.85,pores));
	ROUGHNESS = .4 + .28 * pores;
	METALLIC = .035;
	SPECULAR = .45;
	// Surface-gradient bump: preserves the kit silhouette and requires no UV edits.
	vec3 normal = normalize(NORMAL);
	vec3 dx = dFdx(VERTEX); vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,normal); vec3 r2 = cross(normal,dx);
	float det = dot(dx,r1);
	vec3 gradient = sign(det) * (dFdx(relief) * r1 + dFdy(relief) * r2);
	NORMAL = normalize(abs(det) * normal - gradient * .012);
}

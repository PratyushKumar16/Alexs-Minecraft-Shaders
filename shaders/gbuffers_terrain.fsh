#version 120

uniform sampler2D texture;

varying vec2 texcoord;
varying vec3 normal;
varying vec4 color;
varying vec3 viewPos;

/* DRAWBUFFERS:01 */
// 0: color, 1: normal

void main() {
    vec4 albedo = texture2D(texture, texcoord) * color;
    if (albedo.a < 0.1) discard;

    // Output color to gbuffer 0
    gl_FragData[0] = albedo;
    
    // Output encoded normal to gbuffer 1
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
}

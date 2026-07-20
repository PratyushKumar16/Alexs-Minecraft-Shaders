#version 120

varying vec2 texcoord;
varying vec3 normal;
varying vec4 color;
varying vec3 viewPos;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    color = gl_Color;
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
}

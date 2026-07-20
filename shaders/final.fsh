#version 120

uniform sampler2D colortex0;
varying vec2 texcoord;

// ACES Tone Mapping
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;
    
    // Exposure adjustment
    color *= 1.2;
    
    // Tonemap
    color = ACESFilm(color);
    
    // Gamma correction
    color = pow(color, vec3(1.0 / 2.2));
    
    // Subtle Vignette
    vec2 center = texcoord - 0.5;
    float dist = length(center);
    color *= smoothstep(0.8, 0.3, dist);
    
    gl_FragColor = vec4(color, 1.0);
}

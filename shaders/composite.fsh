#version 120

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

uniform int worldTime;

varying vec2 texcoord;

// Noise function for clouds
float hash(vec2 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * (p.x + p.y));
}

float noise(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), 
                   hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), 
                   hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float f = 0.0;
    f += 0.5000 * noise(p); p = p * 2.02;
    f += 0.2500 * noise(p); p = p * 2.03;
    f += 0.1250 * noise(p); p = p * 2.01;
    f += 0.0625 * noise(p);
    return f / 0.9375;
}

vec3 getSkyColor(vec3 viewDir, vec3 lightDir) {
    float costh = dot(viewDir, lightDir);
    float costhUp = dot(viewDir, normalize(upPosition));
    
    vec3 skyTop = vec3(0.1, 0.3, 0.8);
    vec3 skyHorizon = vec3(0.6, 0.8, 1.0);
    vec3 sunsetColor = vec3(1.0, 0.4, 0.1);
    
    // Time of day mixing (simplified)
    float sunElevation = dot(normalize(upPosition), lightDir);
    float isDay = smoothstep(-0.1, 0.1, sunElevation);
    
    vec3 sky = mix(skyHorizon, skyTop, clamp(costhUp, 0.0, 1.0));
    
    // Sunset glow
    float sunsetMix = smoothstep(0.2, -0.1, sunElevation) * smoothstep(-0.2, -0.1, sunElevation);
    sky = mix(sky, sunsetColor, sunsetMix * max(0.0, costh));
    
    // Sun glow
    float sunGlow = pow(max(0.0, costh), 128.0) * 1.5;
    sky += vec3(sunGlow) * isDay;
    
    // Night sky
    if (isDay < 1.0) {
        vec3 nightSky = vec3(0.01, 0.02, 0.05);
        sky = mix(nightSky, sky, isDay);
    }
    
    return sky;
}

vec4 drawClouds(vec3 viewDir, vec3 skyColor, float time) {
    if (viewDir.y < 0.01) return vec4(0.0);
    
    // Intersect view ray with cloud plane
    float cloudHeight = 400.0;
    float dist = cloudHeight / viewDir.y;
    vec2 cloudPos = viewDir.xz * dist * 0.005 + vec2(time * 0.2, 0.0);
    
    float n = fbm(cloudPos);
    
    // Shape clouds
    float coverage = 0.5;
    float density = smoothstep(coverage, coverage + 0.3, n);
    
    if (density <= 0.0) return vec4(0.0);
    
    // Simple lighting for clouds
    vec3 cloudLight = mix(vec3(0.8, 0.85, 0.9), vec3(1.0), density);
    vec3 finalCloudColor = mix(skyColor, cloudLight, 0.8);
    
    float alpha = density * clamp(viewDir.y * 5.0, 0.0, 1.0); // Fade at horizon
    return vec4(finalCloudColor, alpha);
}

void main() {
    vec4 albedo = texture2D(colortex0, texcoord);
    vec3 normal = texture2D(colortex1, texcoord).xyz * 2.0 - 1.0;
    float depth = texture2D(depthtex0, texcoord).r;
    
    // Reconstruct position
    vec4 clipPos = vec4(texcoord * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPosTemp = gbufferProjectionInverse * clipPos;
    vec3 viewPos = viewPosTemp.xyz / viewPosTemp.w;
    vec4 worldPosTemp = gbufferModelViewInverse * vec4(viewPos, 1.0);
    vec3 worldPos = worldPosTemp.xyz;
    
    vec3 viewDir = normalize(worldPos);
    
    vec3 lightDir = normalize(sunPosition);
    if (sunPosition.y < 0.0) lightDir = normalize(moonPosition);
    
    vec3 finalColor = albedo.rgb;
    
    if (depth == 1.0) {
        // Sky
        finalColor = getSkyColor(viewDir, lightDir);
        vec4 clouds = drawClouds(viewDir, finalColor, float(worldTime) * 0.01);
        finalColor = mix(finalColor, clouds.rgb, clouds.a);
    } else {
        // Lighting
        float NdotL = max(dot(normal, lightDir), 0.0);
        float ambient = 0.2;
        
        // Simple Shadow Mapping
        vec4 shadowViewPos = shadowModelView * vec4(worldPos, 1.0);
        vec4 shadowClipPos = shadowProjection * shadowViewPos;
        vec3 shadowCoord = shadowClipPos.xyz / shadowClipPos.w;
        shadowCoord = shadowCoord * 0.5 + 0.5;
        
        float shadow = 1.0;
        if (shadowCoord.x > 0.0 && shadowCoord.x < 1.0 && shadowCoord.y > 0.0 && shadowCoord.y < 1.0) {
            float shadowDepth = texture2D(shadowtex0, shadowCoord.xy).r;
            if (shadowDepth < shadowCoord.z - 0.001) {
                shadow = 0.0;
            }
        }
        
        vec3 diffuse = vec3(NdotL * shadow + ambient);
        finalColor *= diffuse;
        
        // Distance fog
        float dist = length(viewPos);
        float fogFactor = exp(-dist * 0.005);
        vec3 fogColor = getSkyColor(viewDir, lightDir);
        finalColor = mix(finalColor, fogColor, clamp(1.0 - fogFactor, 0.0, 1.0));
    }
    
    gl_FragData[0] = vec4(finalColor, 1.0);
}

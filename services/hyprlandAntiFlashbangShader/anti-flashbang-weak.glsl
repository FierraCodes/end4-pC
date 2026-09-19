#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float overlayOpacityForBrightness(float x) {
    // Note: range 0 to 1
    
    // Will a fancy curve help?... I'll have to experiment more at night
    // float y = pow(x, 2.0) * 0.75;
    // float y = (1.0 - exp(-x))*1.19;
    // float y = (1.0 - exp(-pow((x-0.15), 0.6)))*1.18;

    float y = x*0.42;
    return min(max(y, 0.001), 1.0);
}

void main() {
    // 1. Get the current pixel color
    vec4 pixColor = texture(tex, v_texcoord);

    // 2. Calculate average screen brightness
    vec3 totalRGB = vec3(0.0);
    
    // 4x4 grid (16 samples) provides sufficient coverage to gauge screen brightness
    // while reducing texture fetches by 84% compared to a 10x10 grid (100 samples).
    for (int i = 0; i < 4; ++i) {
        for (int j = 0; j < 4; ++j) {
            vec2 coord = vec2((float(i) + 0.5) * 0.25, (float(j) + 0.5) * 0.25);
            totalRGB += texture(tex, coord).rgb;
        }
    }
    
    vec3 avgColor = totalRGB * 0.0625; // 1.0 / 16.0
    float globalBrightness = dot(avgColor, vec3(0.2126, 0.7152, 0.0722));

    // 3. Get the specific opacity for this brightness level
    float opacity = overlayOpacityForBrightness(globalBrightness);

    // 4. Apply the "black overlay" effect
    vec3 outColor = mix(pixColor.rgb, vec3(0.0), opacity);

    fragColor = vec4(outColor, pixColor.a);
}

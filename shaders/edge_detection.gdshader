shader_type spatial;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

// --- LINE SETTINGS ---
uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;

// --- PIXELIZATION DISTANCE SETTINGS ---
uniform bool use_depth_pixelization = true;
uniform float min_pixel_size = 2.0; // Hard limit for closest pixels

// The distance where the transition STARTS (Point A)
uniform float pixelation_start_dist = 2.0; 
// The distance where the transition STOPS (Point B) - stays constant after this
uniform float pixelation_end_dist = 20.0; 

// How many "vertical pixels" fit on screen at Start Distance (Higher = Sharper)
uniform float pixel_density_start = 300.0;
// How many "vertical pixels" fit on screen at End Distance (Lower = Blockier)
uniform float pixel_density_end = 50.0;

// The curve of the transition between A and B (1.0 = Linear, >1.0 = Slow start, <1.0 = Fast start)
uniform float distance_curve : hint_range(0.1, 5.0) = 1.0;


float GetLinearDepth(vec2 sUV, sampler2D depthTexture, mat4 invProjectionMat) {
    float depth = texture(depthTexture, sUV).x;
    vec3 ndc = vec3(sUV * 2.0 - 1.0, depth);
    vec4 view = invProjectionMat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

vec3 GetNormal(vec2 uv, sampler2D normalTexture) {
    vec3 normal = texture(normalTexture, uv).rgb;
    normal = normal * 2.0 - 1.0;
    return normal;
}

float NormalEdgeIndicator(vec3 normalEdgeBias, vec3 normal, vec3 neighborNormal, float depthDifference) {
    float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
    float normalIndicator = clamp(smoothstep(-0.01, 0.01, normalDifference), 0.0, 1.0);
    float depthIndicator = clamp(sign(depthDifference * 0.25 + 0.0025), 0.0, 1.0);
    return (1.0 - dot(normal, neighborNormal)) * depthIndicator * normalIndicator;
}

void vertex() { 
    POSITION = vec4(VERTEX.xy, 1.0, 1.0); 
}

void fragment() {
    float depth = GetLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);

    // --- NEW PIXELIZATION LOGIC ---
    float grid = pixel_density_start; // Default to close density
    
    if (use_depth_pixelization) {
        // 1. Calculate the progression factor 't' between 0.0 and 1.0
        // If depth < start, t is 0. If depth > end, t is 1.
        float t = clamp((depth - pixelation_start_dist) / (pixelation_end_dist - pixelation_start_dist), 0.0, 1.0);
        
        // 2. Apply the curve control
        t = pow(t, distance_curve);
        
        // 3. Mix between the Start Density and End Density based on t
        grid = mix(pixel_density_start, pixel_density_end, t);
        
        // 4. Hard safety clamp (prevents dividing by zero or pixels becoming microscopic)
        grid = clamp(grid, 10.0, VIEWPORT_SIZE.y / min_pixel_size);
    }
    // -----------------------------

    vec2 pixel_size = vec2(1.0) / vec2(grid * (VIEWPORT_SIZE.x / VIEWPORT_SIZE.y), grid);
    vec2 pixel_uv = floor(SCREEN_UV / pixel_size) * pixel_size;
    pixel_uv += pixel_size * 0.5;

    // Recalculate depth at the new pixelated coordinate
    depth = GetLinearDepth(pixel_uv, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);

    vec2 UVOffsets[4];
    UVOffsets[0] = pixel_uv + vec2(0.0, -1.0) * pixel_size;
    UVOffsets[1] = pixel_uv + vec2(0.0, 1.0) * pixel_size;
    UVOffsets[2] = pixel_uv + vec2(1.0, 0.0) * pixel_size;
    UVOffsets[3] = pixel_uv + vec2(-1.0, 0.0) * pixel_size;

    float depthDifference = 0.0;
    float invDepthDifference = 0.5;
    float safeDepth = depth + 0.0001;

    for (int i = 0; i < UVOffsets.length(); i++) {
        float dOff = GetLinearDepth(UVOffsets[i], DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
        float relativeDiff = (dOff - depth) / safeDepth;
        depthDifference += clamp(relativeDiff, 0.0, 1.0);
        invDepthDifference += depth - dOff;
    }
    invDepthDifference = clamp(invDepthDifference, 0.0, 1.0);
    invDepthDifference = clamp(smoothstep(0.9, 0.9, invDepthDifference) * 10.0, 0.0, 1.0);

    depthDifference = smoothstep(0.25, 0.3, depthDifference);

    float normalDifference = 0.0;
    vec3 normal = GetNormal(pixel_uv, NORMAL_TEXTURE);
    vec3 normalEdgeBias = (vec3(1.0, 1.0, 1.0));
    for (int i = 0; i < UVOffsets.length(); i++) {
        vec3 nOff = GetNormal(UVOffsets[i], NORMAL_TEXTURE);
        normalDifference += NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference);
    }
    normalDifference = smoothstep(0.2, 0.25, normalDifference);
    normalDifference = clamp(normalDifference - invDepthDifference, 0.0, 1.0);

    float innerLines = clamp(normalDifference - depthDifference, 0.0, 1.0);
    ALBEDO = texture(SCREEN_TEXTURE, pixel_uv).rgb;

    ALBEDO += innerLines * lineHighlight;
    ALBEDO -= depthDifference * lineShadow;
}
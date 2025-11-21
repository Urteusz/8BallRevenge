shader_type spatial;
render_mode unshaded; // Correct, as we set ALBEDO manually

varying vec3 world_pos;

// --- UNIFORMS ---
uniform float u_noise_amplitude : hint_range(0.0, 1.0) = 0.3;
uniform float u_noise_frequency : hint_range(0.1, 10.0) = 4.0;
uniform int   u_noise_octaves : hint_range(1, 10) = 4;
uniform float u_noise_lacunarity : hint_range(1.0, 4.0) = 2.0;
uniform float u_noise_persistence : hint_range(0.0, 1.0) = 0.5;
uniform float u_surface_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float u_surface_density : hint_range(0.1, 2.0) = 0.42;
uniform vec3 u_gradient_start_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 u_gradient_end_color : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 u_fresnel_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float u_fresnel_power : hint_range(0.1, 20.0) = 5.0;
uniform vec3 u_center = vec3(0.0);


// --- NOISE FUNCTIONS (Unchanged) ---

vec3 getGradient(vec3 i) {
    vec3 p = fract(i * vec3(0.3183099, 0.331739, 0.325631));
    p += dot(p, p.yzx + 19.19);
    return normalize(vec3(
        fract((p.x + p.y) * p.z) * 2.0 - 1.0,
        fract((p.y + p.z) * p.x) * 2.0 - 1.0,
        fract((p.z + p.x) * p.y) * 2.0 - 1.0
    ));
}

float noise_perlin3D(vec3 p) {
    vec3 i = floor(p); 
    vec3 f = fract(p); 
    vec3 u = f * f * (3.0 - 2.0 * f);
    
    vec3 g000 = getGradient(i + vec3(0.0, 0.0, 0.0));
    vec3 g100 = getGradient(i + vec3(1.0, 0.0, 0.0));
    vec3 g010 = getGradient(i + vec3(0.0, 1.0, 0.0));
    vec3 g110 = getGradient(i + vec3(1.0, 1.0, 0.0));
    vec3 g001 = getGradient(i + vec3(0.0, 0.0, 1.0));
    vec3 g101 = getGradient(i + vec3(1.0, 0.0, 1.0));
    vec3 g011 = getGradient(i + vec3(0.0, 1.0, 1.0));
    vec3 g111 = getGradient(i + vec3(1.0, 1.0, 1.0));
    
    vec3 f000 = f - vec3(0.0, 0.0, 0.0);
    vec3 f100 = f - vec3(1.0, 0.0, 0.0);
    vec3 f010 = f - vec3(0.0, 1.0, 0.0);
    vec3 f110 = f - vec3(1.0, 1.0, 0.0);
    vec3 f001 = f - vec3(0.0, 0.0, 1.0);
    vec3 f101 = f - vec3(1.0, 0.0, 1.0);
    vec3 f011 = f - vec3(0.0, 1.0, 1.0);
    vec3 f111 = f - vec3(1.0, 1.0, 1.0);
    
    float d000 = dot(g000, f000);
    float d100 = dot(g100, f100);
    float d010 = dot(g010, f010);
    float d110 = dot(g110, f110);
    float d001 = dot(g001, f001);
    float d101 = dot(g101, f101);
    float d011 = dot(g011, f011);
    float d111 = dot(g111, f111);
    
    float n_x00 = mix(d000, d100, u.x);
    float n_x10 = mix(d010, d110, u.x);
    float n_x01 = mix(d001, d101, u.x);
    float n_x11 = mix(d011, d111, u.x);
    float n_y0 = mix(n_x00, n_x10, u.y);
    float n_y1 = mix(n_x01, n_x11, u.y);
    float n = mix(n_y0, n_y1, u.z);
    return n * 0.5 + 0.5;
}

float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = u_noise_amplitude;
    float frequency = u_noise_frequency; 
    
    vec3 time_offset = vec3(TIME * 0.1, 0.0, 0.0); 

    for (int i = 0; i < u_noise_octaves; i++) {
        value += amplitude * noise_perlin3D((p + time_offset) * frequency);
        frequency *= u_noise_lacunarity; 
        amplitude *= u_noise_persistence; 
    }
    return value;
}

float sceneSDF(vec3 p) {
    vec3 p_local = p - u_center;
    float noise_value = fbm(p_local); 
    float threshold = u_surface_threshold;
    float factor = u_surface_density;
    return (noise_value - threshold) * factor;  
}

// --- VERTEX FUNCTION (Unchanged) ---
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// --- Main Fragment Function ---

void fragment() {
    vec3 rayOrigin = world_pos;
    vec3 rayDir = normalize(world_pos - CAMERA_POSITION_WORLD);

    // --- 1. Calculate Raymarch Color (the noise) ---
    vec3 raymarch_color;
    
    const int MAX_STEPS = 6;
    const float MAX_DIST = 2.0; 
    const float STEP_SIZE = MAX_DIST / float(MAX_STEPS); 

    float t = 0.0; 
    float prev_dist = sceneSDF(rayOrigin);
    bool hit = false;

    for (int i = 0; i < MAX_STEPS; i++) {
        t += STEP_SIZE;
        vec3 p = rayOrigin + t * rayDir;
        
        float dist = sceneSDF(p);

        if (dist < 0.0 && prev_dist > 0.0) {
            float hit_dist = t - (STEP_SIZE * 0.5);
            float gradient_val = clamp(hit_dist / MAX_DIST, 0.0, 1.0);
            raymarch_color = mix(u_gradient_start_color, u_gradient_end_color, gradient_val);
            hit = true;
            break;
        }

        prev_dist = dist;

        if (t > MAX_DIST) {
            break;
        }
    }

    if (!hit) {
        raymarch_color = u_gradient_end_color;
    }
    
    // --- End of Raymarch Logic ---

    // --- 2. FRESNEL LOGIC (for cubes/planes) ---
    
    // We no longer need p_local_shape, since we're using the mesh normal
    // vec3 p_local_shape = world_pos - u_center;
    
    // --- CHANGE HERE ---
    // Use the built-in MESH normal (NORMAL) in world space.
    // This will respect the flat faces of a cube or plane.
    vec3 N_shape = NORMAL;

    // Get View Direction (from fragment on shape to camera)
    vec3 V_shape = VIEW; // Godot's built-in view vector

    // Calculate Fresnel Factor
    float NdotV = max(0.0, dot(N_shape, V_shape));
    float fresnel_factor = pow(1.0 - NdotV, u_fresnel_power);

    // --- 3. Mix the two results ---

    // --- CHANGE HERE ---
    // Mix the raymarched color (inside) with the fresnel color (rim)
    vec3 final_color = mix(raymarch_color, u_fresnel_color, fresnel_factor);

    // Set the final color and alpha
    ALBEDO = final_color;
    ALPHA = 1.0;
}
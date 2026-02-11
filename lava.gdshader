shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- USTAWIENIA ---
uniform float speed : hint_range(0.1, 2.0) = 0.2;
uniform float rotation_speed : hint_range(-1.0, 1.0) = 0.1;
uniform float scale : hint_range(0.1, 5.0) = 0.6; // Mniejsza skala = większe łaty

// Kolory (ustawione na Ciemna skała -> Czerwień -> Żółty)
uniform vec4 hot_color : source_color = vec4(1.0, 0.9, 0.1, 1.0);   // Żółty rdzeń
uniform vec4 medium_color : source_color = vec4(0.8, 0.1, 0.0, 1.0); // Czerwona lawa
uniform vec4 cool_color : source_color = vec4(0.05, 0.0, 0.0, 1.0);  // Czarna skała

uniform float emission_strength : hint_range(0.0, 10.0) = 3.0;
uniform float displacement_strength : hint_range(0.0, 0.2) = 0.05; // Wysokość bąbli

// --- ZMIENNE POMOCNICZE ---
varying vec3 v_local_pos; // Tu przechowamy pozycję niezależną od kamery

// --- FUNKCJE SZUMU (Simplex Noise) ---
vec3 mod289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289_3(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);
    vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289_2(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
        + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
    m = m*m; m = m*m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for(int i = 0; i < 5; i++) { // Zmniejszyłem pętlę do 5 dla wydajności
        value += amplitude * snoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value * 0.5 + 0.5;
}

// Funkcja generująca wzór (używana w Vertex i Fragment)
float get_pattern(vec3 pos, float time) {
    // Rotacja wokół Y i X
    float angle_y = time * rotation_speed;
    float angle_x = time * rotation_speed * 0.5;
    
    mat3 rot_y = mat3(
        vec3(cos(angle_y), 0.0, sin(angle_y)),
        vec3(0.0, 1.0, 0.0),
        vec3(-sin(angle_y), 0.0, cos(angle_y))
    );
    
    mat3 rot_x = mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, cos(angle_x), -sin(angle_x)),
        vec3(0.0, sin(angle_x), cos(angle_x))
    );
    
    // Obracamy pozycję lokalną
    vec3 p = rot_y * rot_x * pos * scale;
    
    // Mieszanie triplanar (bezszwowe)
    vec3 w = abs(normalize(pos)); // Wagi na podstawie normalnej
    w = pow(w, vec3(4.0)); // Wyostrzamy przejścia
    w = w / (w.x + w.y + w.z);
    
    float t = time * speed;
    
    // Szum na 3 płaszczyznach
    float pat_x = fbm(p.yz + vec2(t * 0.05, t * 0.03));
    float pat_y = fbm(p.xz + vec2(-t * 0.04, t * 0.06));
    float pat_z = fbm(p.xy + vec2(t * 0.03, -t * 0.05));
    
    return pat_x * w.x + pat_y * w.y + pat_z * w.z;
}

void vertex() {
    v_local_pos = VERTEX; // Przekazujemy pozycję do fragment shadera
    
    // Dodajemy lekkie wypychanie (bąblowanie)
    float pattern = get_pattern(VERTEX, TIME);
    float displacement = smoothstep(0.4, 0.8, pattern) * displacement_strength;
    VERTEX += NORMAL * displacement;
}

void fragment() {
    // Używamy pozycji z vertex shadera (naprawia patrzenie w kamerę)
    float pattern = get_pattern(v_local_pos, TIME);
    
    vec3 final_color;
    float emission_mask = 0.0;
    
    // Logika kolorów - twardsze przejścia dla lepszego kontrastu
    if(pattern > 0.6) {
        // Bardzo gorące (żółte)
        float t = (pattern - 0.6) / 0.4;
        final_color = mix(medium_color.rgb, hot_color.rgb, t);
        emission_mask = 1.0; // Świeci mocno
    } else if(pattern > 0.35) {
        // Lawa (czerwona)
        float t = (pattern - 0.35) / 0.25;
        final_color = mix(cool_color.rgb, medium_color.rgb, t);
        emission_mask = t * 0.5; // Świeci średnio
    } else {
        // Skała (czarna)
        final_color = cool_color.rgb;
        emission_mask = 0.0; // Nie świeci w ogóle!
    }
    
    ALBEDO = final_color;
    // Emisja tylko tam, gdzie lawa jest gorąca
    EMISSION = final_color * emission_strength * emission_mask;
    
    // Skała matowa, lawa błyszcząca
    ROUGHNESS = mix(0.9, 0.2, emission_mask); 
}
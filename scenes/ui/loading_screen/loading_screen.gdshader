shader_type canvas_item;

// Define a threshold value (0.5 is standard)
// Anything darker than grey becomes invisible; anything lighter becomes solid.
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 1. Get the color from the LEFT half
    vec2 uv_color = vec2(UV.x * 0.5, UV.y);
    vec4 color_tex = texture(TEXTURE, uv_color);

    // 2. Get the mask from the RIGHT half
    vec2 uv_mask = vec2((UV.x * 0.5) + 0.5, UV.y);
    vec4 mask_tex = texture(TEXTURE, uv_mask);

    // 3. Apply the threshold to create a hard edge
    // "step(edge, x)" returns 0.0 if x < edge, and 1.0 if x >= edge
    float hard_alpha = step(threshold, mask_tex.r);

    // 4. Output the result
    COLOR = vec4(color_tex.rgb, hard_alpha);
}
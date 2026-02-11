shader_type spatial;
render_mode unshaded;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture,
                                   filter_nearest;

uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;
uniform vec4 tintColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tintStrength = 0.0;

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

float NormalEdgeIndicator(vec3 normalEdgeBias, vec3 normal, vec3 neighborNormal,
                          float depthDifference) {
  float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
  float normalIndicator =
      clamp(smoothstep(-0.01, 0.01, normalDifference), 0.0, 1.0);
  float depthIndicator = clamp(sign(depthDifference * 0.25 + 0.0025), 0.0, 1.0);
  return (1.0 - dot(normal, neighborNormal)) * depthIndicator * normalIndicator;
}

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

void fragment() {
  vec2 texelSize = 1.0 / VIEWPORT_SIZE.xy;

  // Skaluj sampling z głębokością — dalsze obiekty dostają szerszy offset
  float depth = GetLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
  float depthScale = clamp(depth / 15.0, 1.0, 2.0);
  vec2 scaledTexel = texelSize * depthScale;

  vec2 UVOffsets[4];
  UVOffsets[0] = SCREEN_UV + vec2(0.0, -1.0) * scaledTexel;
  UVOffsets[1] = SCREEN_UV + vec2(0.0, 1.0) * scaledTexel;
  UVOffsets[2] = SCREEN_UV + vec2(1.0, 0.0) * scaledTexel;
  UVOffsets[3] = SCREEN_UV + vec2(-1.0, 0.0) * scaledTexel;

  float depthDifference = 0.0;
  float invDepthDifference = 0.5;
  float safeDepth = depth + 0.0001;

  for (int i = 0; i < UVOffsets.length(); i++) {
    float dOff =
        GetLinearDepth(UVOffsets[i], DEPTH_TEXTURE, INV_PROJECTION_MATRIX);

    float relativeDiff = (dOff - depth) / safeDepth;

    depthDifference += clamp(relativeDiff, 0.0, 1.0);

    invDepthDifference += depth - dOff;
  }
  invDepthDifference = clamp(invDepthDifference, 0.0, 1.0);
  invDepthDifference =
      clamp(smoothstep(0.9, 0.9, invDepthDifference) * 10.0, 0.0, 1.0);

  depthDifference = smoothstep(0.25, 0.3, depthDifference);

  float normalDifference = 0.0;
  vec3 normal = GetNormal(SCREEN_UV, NORMAL_TEXTURE);
  vec3 normalEdgeBias = (vec3(1.0, 1.0, 1.0));
  for (int i = 0; i < UVOffsets.length(); i++) {
    vec3 nOff = GetNormal(UVOffsets[i], NORMAL_TEXTURE);
    normalDifference +=
        NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference);
  }
  normalDifference = smoothstep(0.2, 0.25, normalDifference);
  normalDifference = clamp(normalDifference - invDepthDifference, 0.0, 1.0);

  float innerLines = clamp(normalDifference - depthDifference, 0.0, 1.0);
  ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

  ALBEDO += innerLines * lineHighlight;

  // Cienie blendują do ciemnej wersji tintColor zamiast do czystej czerni
  vec3 shadowTarget = tintColor.rgb * 0.15;
  ALBEDO = mix(ALBEDO, shadowTarget, depthDifference * lineShadow);

  // Tint — zastępuje ambient light od sky, stały niezależnie od pozycji kamery
  ALBEDO = mix(ALBEDO, ALBEDO * tintColor.rgb, tintStrength);
}

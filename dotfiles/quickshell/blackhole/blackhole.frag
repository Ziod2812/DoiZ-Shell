#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float grow;
    float collapse;
    vec4 hotColor;
    vec4 midColor;
    vec4 outerColor;
    vec4 glowColor;
};

const float TAU = 6.2831853;
const float R = 0.22;
const float PETALS = 14.0;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(float x, float period) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash(vec2(mod(i, period), 1.0)), hash(vec2(mod(i + 1.0, period), 1.0)), f);
}

float vertexR(float k) {
    float h = hash(vec2(mod(k, PETALS), 2.0));
    return R * (0.50 + 0.95 * h * h);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(p);
    float px = max(fwidth(r), 0.0005);

    float c = clamp(collapse, 0.0, 1.0);
    float a = atan(p.y, p.x) / TAU + 0.5;
    a += (0.25 + 1.8 * c) * exp(-4.0 * r) + 0.02 * time * exp(-2.0 * r);

    float x = a * PETALS + 0.20 * (vnoise(a * PETALS * 1.7, PETALS) - 0.5);
    float s = floor(x);
    float fx = x - s;
    float edgeR = mix(vertexR(s), vertexR(s + 1.0), fx);
    float hp = hash(vec2(mod(s, PETALS), 5.0));
    float hq = hash(vec2(mod(s, PETALS), 8.0));
    float outerR = edgeR * (1.35 + 0.95 * hq);

    vec3 hot = mix(hotColor.rgb, vec3(1.0), 0.45);
    float flare = 1.0 + 1.2 * c;

    vec3 col = vec3(0.0);
    float al = 0.0;

    float well = 0.60 * exp(-max(r - R, 0.0) / (R * 1.1)) * smoothstep(R * 3.2, R * 0.6, r);
    al = well;

    float inPetal = smoothstep(edgeR - px, edgeR + px, r) * (1.0 - smoothstep(outerR - px, outerR + px, r));
    float t = clamp((r - edgeR) / max(outerR - edgeR, 0.001), 0.0, 1.0);
    vec3 petalCol = mix(glowColor.rgb, hot, hp) * (0.10 + 0.20 * hp) * (1.0 - 0.5 * t);
    float petalA = (0.20 + 0.18 * hp) * inPetal;
    col = col * (1.0 - petalA) + petalCol * inPetal;
    al = al + petalA * (1.0 - al);

    float seam = min(fx, 1.0 - fx) * TAU * r / PETALS;
    float seamL = (1.0 - smoothstep(px * 0.5, px * 1.6, seam)) * inPetal;
    float borderL = 1.0 - smoothstep(px * 0.6, px * 1.8, abs(r - outerR));
    float lines = max(seamL * 0.7, borderL * 0.9);
    col += mix(glowColor.rgb, hot, 0.6) * lines * 0.8;
    al = max(al, lines * 0.85);

    float mouth = 1.0 - smoothstep(edgeR - px * 1.2, edgeR + px * 0.4, r);
    float rim = exp(-pow((r - edgeR) / (px * 1.7 + 0.002), 2.0));
    float rimWide = exp(-pow((r - edgeR) / (R * 0.22), 2.0));

    float rn = clamp(r / max(edgeR, 0.001), 0.0, 1.0);
    float z = 1.0 / (rn + 0.18);
    float ring = pow(0.5 + 0.5 * sin(z * 5.5 - time * 2.4 + a * TAU * 2.0), 6.0);
    float tunnel = ring * smoothstep(0.08, 0.95, rn) * (0.14 + 0.12 * c);
    vec3 inner = mix(midColor.rgb, glowColor.rgb, 0.5) * tunnel;
    inner += hot * exp(-rn * rn * 26.0) * (0.05 + 0.20 * c);

    col = col * (1.0 - mouth) + inner * mouth;
    al = al * (1.0 - mouth) + mouth;

    col += hot * rim * 0.80 * flare;
    col += mix(glowColor.rgb, outerColor.rgb, 0.4) * rimWide * 0.30 * flare;
    al = max(al, max(rim * 0.95, rimWide * 0.30));

    float g = clamp(grow, 0.0, 1.0);
    vec3 rgb = min(col, vec3(1.0));
    fragColor = vec4(rgb, min(al, 1.0)) * qt_Opacity * smoothstep(0.0, 0.08, g);
}

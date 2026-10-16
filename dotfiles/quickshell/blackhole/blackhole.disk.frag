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
const float R = 0.20;
const float RIN = 1.18;
const float ROUT = 4.2;
const float TILT = 0.20;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(vec2(mod(i.x, period), i.y));
    float b = hash(vec2(mod(i.x + 1.0, period), i.y));
    float c = hash(vec2(mod(i.x, period), i.y + 1.0));
    float d = hash(vec2(mod(i.x + 1.0, period), i.y + 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, float period) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 3; i++) {
        v += a * vnoise(p, period);
        p = vec2(p.x * 2.0, p.y * 2.13 + 3.7);
        period *= 2.0;
        a *= 0.5;
    }
    return v;
}

float gas(float phi, float rd, float t) {
    float omega = 0.20 * pow(RIN * R / max(rd, 0.01), 1.5);
    float u = phi - t * omega;
    return fbm(vec2(u * 10.0, rd * 22.0), 10.0);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(p);
    float px = max(fwidth(r), 0.0005);

    float g = clamp(grow, 0.0, 1.0);
    float c = clamp(collapse, 0.0, 1.0);
    float ang = atan(p.y, p.x);
    float a01 = ang / TAU + 0.5;

    float tear = (vnoise(vec2(a01 * 11.0, 1.3), 11.0) - 0.5) * 2.0;
    float Rh = R * (1.0 + 0.45 * pow(1.0 - g, 2.0) * tear);

    float se = mix(TILT, 0.34, c * c);
    float Z = p.y / se;
    float rd = length(vec2(p.x, Z));
    float aw = max(fwidth(rd), 1e-4);
    float phi = atan(Z, p.x) / TAU + 0.5;

    float edge = 1.0 - smoothstep(0.78, 0.98, r);
    float diskAmt = smoothstep(0.30, 0.90, g);
    float flare = 1.0 + 0.8 * c;

    vec3 hotW = mix(hotColor.rgb, vec3(1.0), 0.42);
    vec3 warm = mix(glowColor.rgb, hotColor.rgb, 0.5);
    vec3 cool = mix(midColor.rgb, outerColor.rgb, 0.45);

    vec3 col = vec3(0.0);
    float al = 0.0;

    float well = 0.55 * exp(-max(r - Rh, 0.0) / (Rh * 1.4)) * smoothstep(Rh * 4.6, Rh * 0.8, r) * edge;
    al = well;

    float b = max(r - Rh, 0.0) / Rh;
    float halo = exp(-b / 0.40);
    col += mix(warm, hotW, 0.4) * halo * 0.14 * diskAmt * flare * edge;

    float dopL = pow(clamp(1.0 - 0.45 * cos(ang), 0.2, 2.0), 2.0);
    float topw = 0.30 + 0.70 * pow(abs(sin(ang)), 0.7);
    float nL = gas(a01, Rh * (RIN + 2.2 * b), time);
    float gl = clamp((nL - 0.22) * 1.9, 0.0, 1.5);
    float lens = (0.80 * exp(-b / 0.13) + 0.22 * exp(-b / 0.38)) * topw * dopL * (0.35 + 0.85 * gl);
    col += mix(hotW, warm, smoothstep(0.0, 0.7, b)) * lens * 0.80 * diskAmt * flare * edge;

    float pr = exp(-pow((r - Rh * 1.012) / (px * 1.6 + Rh * 0.010), 2.0));
    col += hotW * pr * (0.55 + 0.55 * dopL) * (0.5 + 0.5 * diskAmt) * flare * edge;

    float inside = 1.0 - smoothstep(Rh - px, Rh + px * 0.6, r);
    col *= 1.0 - inside;
    al = mix(al, 1.0, inside);

    float near = step(0.0, p.y);
    float vis = mix(smoothstep(Rh * 0.98, Rh * 1.02 + px, r), 1.0, near);
    float inner = smoothstep(RIN * Rh - aw, RIN * Rh + aw, rd);
    float outer = 1.0 - smoothstep(ROUT * Rh * 0.7, ROUT * Rh, rd);
    float m = inner * outer * vis * diskAmt * edge;

    float x = clamp((rd - RIN * Rh) / ((ROUT - RIN) * Rh), 0.0, 1.0);
    float tt = pow(1.0 - x, 1.15);
    float n = gas(phi, rd, time);
    float gn = clamp((n - 0.22) * 1.9, 0.0, 1.5);
    float rings = 0.94 + 0.06 * sin(rd * 150.0 + 7.0 * n);
    float emis = (0.16 + 1.05 * tt) * (0.30 + 0.95 * gn) * rings;

    float vorb = 0.55 * sqrt(RIN * Rh / max(rd, 0.01));
    float bm = 1.0 - vorb * (p.x / max(rd, 1e-3));
    float dop = pow(clamp(bm, 0.3, 2.0), 2.5);

    vec3 dc = mix(cool, warm, smoothstep(0.0, 0.55, tt));
    dc = mix(dc, hotW, smoothstep(0.45, 1.0, tt));
    dc = mix(dc, hotW, clamp(bm - 1.0, 0.0, 1.0) * 0.5);
    vec3 diskRGB = dc * emis * dop * flare;
    float diskA = clamp(0.55 + 0.45 * tt, 0.0, 1.0) * m;
    col = col * (1.0 - diskA) + diskRGB * m;
    al = diskA + al * (1.0 - diskA);

    float ax = abs(p.x);
    float bx = clamp((ax - RIN * Rh) / ((ROUT - RIN) * Rh), 0.0, 1.0);
    float prof = pow(1.0 - bx, 1.6) * smoothstep(RIN * Rh * 0.6, RIN * Rh, ax);
    float band = exp(-abs(p.y) / 0.040) * prof;
    col += mix(warm, hotW, 0.5) * band * 0.22 * diskAmt * flare * edge * (1.0 - 0.85 * inside);

    vec3 rgb = min(col, vec3(1.0));
    float outA = clamp(max(al, max(rgb.r, max(rgb.g, rgb.b)) * 0.85), 0.0, 1.0);
    fragColor = vec4(rgb, outA) * qt_Opacity * smoothstep(0.0, 0.08, g);
}

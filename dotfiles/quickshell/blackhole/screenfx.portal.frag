#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float grow;
    float collapse;
    float pop;
    float reveal;
    float breakAmt;
    float openAmt;
    float snapAmt;
    float goldMix;
    vec2 resolution;
    vec4 hotColor;
    vec4 glowColor;
    vec4 bgColor;
};

layout(binding = 1) uniform sampler2D snap;

const float PI = 3.14159265;
const float TAU = 6.2831853;

const float R0 = 0.74;
const float KX = 0.60;
const float TILT = 0.13;
const float SHOT = 0.28;
const float ZOOM = 3.0;
const float ROLL = 0.35;
const float ZBLUR = 0.03;

const vec3 LIME = vec3(0.45, 1.00, 0.20);
const vec3 LIME_HOT = vec3(0.82, 1.00, 0.55);
const vec3 LIME_DEEP = vec3(0.08, 0.50, 0.12);
const int SHOT_STYLE = 1;
const vec3 BEAM = vec3(0.74, 0.97, 0.08);

vec3 toGold(vec3 c) {
    return vec3(c.g, c.g * 0.72 + c.r * 0.25, c.b * 0.8);
}

vec3 gmix(vec3 c) {
    return mix(c, toGold(c), goldMix);
}

vec2 rot(vec2 v, float a) {
    float co = cos(a);
    float si = sin(a);
    return vec2(co * v.x - si * v.y, si * v.x + co * v.y);
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vn(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        s += a * vn(p);
        p = vec2(1.6 * p.x + 1.2 * p.y, -1.2 * p.x + 1.6 * p.y);
        a *= 0.5;
    }
    return s / 0.9375;
}

float ringShape(float r, float radius, float width) {
    float d = (r - radius) / width;
    return exp(-d * d);
}

float easeOutBack(float t) {
    float c1 = 1.70158;
    float c3 = c1 + 1.0;
    float u = t - 1.0;
    return 1.0 + c3 * u * u * u + c1 * u * u;
}

float wobble(vec2 dir, float a, float amp) {
    float t = time;
    float w = 0.035 * sin(a * 2.0 + t * 1.3)
            + 0.030 * sin(a * 3.0 - t * 1.9 + 1.3)
            + 0.022 * sin(a * 5.0 + t * 2.7 + 2.7)
            + 0.13 * (fbm(dir * 1.3 + vec2(t * 0.35, -t * 0.25)) - 0.5);
    return 1.0 + amp * w;
}

float dots(vec2 qc, float edgeR, float rho) {
    vec2 g = rot(qc / max(edgeR, 0.05), time * 0.22) * 6.0;
    vec2 gi = floor(g);
    vec2 gf = fract(g) - 0.5;
    float acc = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 id = gi + vec2(float(i), float(j));
            float h = hash(id + 1.3);
            float ph = hash(id + 8.1);
            vec2 off = (vec2(hash(id + 3.7), hash(id + 5.9)) - 0.5) * 0.7;
            float rad = mix(0.05, 0.25, pow(hash(id + 9.9), 2.2)) * (0.85 + 0.15 * sin(time * 2.5 + ph * 30.0));
            float keep = step(mix(0.74, 0.38, smoothstep(0.55, 0.95, rho)), h);
            vec2 dv = gf - vec2(float(i), float(j)) - off;
            acc = max(acc, keep * (1.0 - smoothstep(rad, rad + 0.025, length(dv))));
        }
    }
    return acc;
}

vec3 portalInterior(vec2 q, float re, float edgeR, float zs, float zoom) {
    float er = max(edgeR, 1e-3);
    float rho = clamp(re / er, 0.0, 1.3);
    vec2 qc = q - vec2(0.06, 0.03) * er;
    float rc = length(qc) / er;
    float an = atan(qc.y, qc.x);
    float spd = 1.0 + 4.0 * zs;
    float wn = fbm(qc / max(edgeR, 0.05) * 2.4 + vec2(0.0, time * 0.25));
    float ph = an * 2.0 + 6.0 * sqrt(rc) - time * 1.3 * spd + wn * 2.6;
    float b1 = 0.5 + 0.5 * sin(ph);
    float b2 = 0.5 + 0.5 * sin(an * 3.0 + 10.0 * sqrt(rc) - time * 1.7 * spd + 1.9 + wn * 3.0);
    float b3 = 0.5 + 0.5 * sin(an * 5.0 + 15.0 * sqrt(rc) - time * 2.1 * spd - 0.8 + wn * 4.0);
    float w = 0.05;

    vec3 mid = vec3(0.35, 0.80, 0.10);
    vec3 dark = vec3(0.17, 0.48, 0.10);
    vec3 light = vec3(0.56, 0.95, 0.14);
    vec3 yel = vec3(0.80, 1.00, 0.32);

    float dk = smoothstep(0.16, 0.30, rc) * (1.0 - smoothstep(0.74, 0.88, rc));
    vec3 col = mid;
    col = mix(col, dark, smoothstep(0.50 - w, 0.50 + w, b1) * dk);
    col = mix(col, light, smoothstep(0.78 - w, 0.78 + w, b2) * (1.0 - 0.5 * dk));
    col = mix(col, yel, smoothstep(0.90 - w * 0.6, 0.90 + w * 0.6, b3) * 0.85 * smoothstep(0.1, 0.35, rc));
    col = mix(col, light, exp(-rc * rc * 40.0) * 0.8);
    col = mix(col, yel, exp(-rc * rc * 300.0) * 0.7);

    float rimLine = rho + (wn - 0.5) * 0.08;
    col = mix(col, light, smoothstep(0.77, 0.81, rimLine));
    col = mix(col, vec3(0.62, 1.00, 0.22), smoothstep(0.91, 0.94, rimLine));
    col = mix(col, yel, smoothstep(0.965, 0.985, rimLine) * 0.8);

    float gv = 0.5 + 0.5 * sin(an + 5.0 * sqrt(rc) - time * 0.5 + wn * 2.2);
    float gt = mix(1.08, -0.08, goldMix);
    float gm = smoothstep(gt - 0.06, gt + 0.06, gv);
    col = mix(col, toGold(col), gm);
    col = mix(col, vec3(0.96, 1.00, 0.90), dots(qc, edgeR, rho) * (1.0 - smoothstep(0.93, 0.985, rho)) * (1.0 - smoothstep(1.5, 4.0, zoom)));
    return col;
}

vec3 sheet(vec2 dirq, float rq, float Rm, float sh, float go, float aspect, vec3 voidCol, float jit) {
    float dd = max(rq - Rm, 0.0);
    float rs = rq + 0.014 * sin(PI * go) * sin(dd * 34.0 - time * 10.0) * exp(-dd * 2.2);
    float bl = ZBLUR * smoothstep(0.05, 0.5, sh) * (1.0 - smoothstep(0.9, 1.0, sh));
    vec2 invAsp = 1.0 / (vec2(aspect, 1.0) * 2.0);
    vec3 acc = vec3(0.0);
    float valid = 0.0;
    for (int k = -3; k <= 3; k++) {
        vec2 sp = rot(dirq * rs * (1.0 + (float(k) + jit) * bl * 0.5) * vec2(KX, 1.0), -TILT);
        vec2 uv = sp * invAsp + 0.5;
        float inb = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
        acc += texture(snap, clamp(uv, 0.0, 1.0)).rgb * inb;
        valid += inb;
    }
    vec3 img = valid > 0.5 ? acc / valid : voidCol;
    float cover = valid / 7.0;
    return mix(voidCol, img, smoothstep(0.0, 1.0, cover));
}

void main() {
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) * 2.0;
    float r = length(p);
    float snapOn = step(0.5, snapAmt);

    float gAll = clamp(grow, 0.0, 1.0);
    float shotT = clamp(gAll / SHOT, 0.0, 1.0);
    float go = clamp((gAll - SHOT) / (1.0 - SHOT), 0.0, 1.0);
    float cc = clamp(collapse, 0.0, 1.0);
    float sh = clamp(breakAmt, 0.0, 1.0);
    float popRamp = smoothstep(0.0, 0.04, pop);
    float pk = pop;
    float revLive = smoothstep(0.0, 0.06, reveal) * (1.0 - smoothstep(0.82, 1.0, reveal));

    float corner = length(vec2(aspect, 1.0));
    float rv = clamp(reveal, 0.0, 1.0);
    float re = rv * rv * (3.0 - 2.0 * rv);
    const float REV_EDGE = 0.9;
    float revR = mix(-REV_EDGE, corner, re);
    float darkRemain = smoothstep(revR, revR + REV_EDGE, r);

    float zs = pow(sh, 1.7);
    float zoom = exp(ZOOM * zs);
    vec2 pz = rot(p, ROLL * zs) / zoom;
    vec2 q = rot(pz, TILT) / vec2(KX, 1.0);
    float rq = length(q);
    vec2 dirq = q / max(rq, 1e-4);
    float a = atan(q.y, q.x);
    float ang01 = a / TAU + 0.5;

    float openR = R0 * easeOutBack(go);
    float amp = 0.9 + 2.2 * (1.0 - smoothstep(0.0, 0.7, go));
    float edgeR = openR * wobble(dirq, a, amp);
    float d = rq - edgeR;
    float pOpen = smoothstep(0.0, 0.12, go);
    float live = step(0.004, openR);

    float dd = max(rq - openR, 0.0);
    vec3 voidCol = bgColor.rgb * 0.22 + gmix(LIME_DEEP) * exp(-dd * 1.4) * 0.45 * pOpen;

    vec4 base;
    if (snapOn > 0.5) {
        float jit = hash(qt_TexCoord0 * resolution + fract(time) * 17.0) - 0.5;
        base = vec4(sheet(dirq, rq, openR, sh, go, aspect, voidCol, jit), 1.0);
    } else {
        float vig = smoothstep(0.45, 1.6, r);
        float dim = (0.10 + 0.40 * vig) * go;
        base = vec4(bgColor.rgb * dim, dim);
    }

    float fw = max(fwidth(d), 1e-4);
    float inside = (1.0 - smoothstep(-fw, fw, d)) * live;
    float glow = exp(-max(d, 0.0) * 8.0) * pOpen * live;
    base.rgb += gmix(LIME) * glow * 0.30 * (1.0 - inside);
    base.a = max(base.a, glow * 0.5 * (1.0 - inside));

    vec3 pc = portalInterior(q, rq, edgeR, zs, zoom);
    base = vec4(base.rgb * (1.0 - inside) + pc * inside, base.a * (1.0 - inside) + inside);

    float wc = smoothstep(0.0, 0.85, cc);
    float haze = 1.0 - smoothstep(0.0, 0.9, rv);
    vec3 flashCol = mix(gmix(LIME_HOT), vec3(1.0), 0.6);
    base.rgb = mix(base.rgb, flashCol * haze, wc);
    base.a = mix(base.a, haze, wc);
    base *= darkRemain;

    vec3 light = vec3(0.0);

    float shotVis = step(0.0005, shotT) * (1.0 - smoothstep(0.08, 0.15, go)) * (SHOT_STYLE == 0 ? 1.0 : 0.0);
    if (shotVis > 0.001) {
        vec2 A = vec2(-aspect * 1.12, 0.38);
        vec2 ab = -A;
        float L = length(ab);
        vec2 tv = ab / L;
        vec2 nv = vec2(-tv.y, tv.x);
        float hs = L * pow(shotT, 1.7);
        float tl = 1.3 * (0.4 + 0.6 * sqrt(shotT));
        float ts = mix(max(0.0, hs - tl), hs, smoothstep(0.0, 0.14, go));
        vec2 rel = p - A;
        float sA = dot(rel, tv);
        float nA = dot(rel, nv);
        float seg = clamp(sA, ts, hs);
        float dseg = length(vec2(sA - seg, nA));
        float along = clamp((seg - ts) / max(hs - ts, 1e-3), 0.0, 1.0);
        float bw = mix(0.010, 0.048, along) * (1.0 + 0.12 * sin(sA * 45.0 - time * 40.0));
        float aaB = max(fwidth(dseg), 1e-4);
        float body = 1.0 - smoothstep(bw - aaB, bw + aaB, dseg);
        float cor = 1.0 - smoothstep(bw * 0.4 - aaB, bw * 0.4 + aaB, dseg);
        float halo = exp(-dseg * 11.0) * 0.55;
        float dh = length(vec2(sA - hs, nA));
        float knob = 1.0 - smoothstep(0.050, 0.060, dh);
        float knobW = exp(-dh * dh / 0.0009);
        float vis = shotVis * smoothstep(0.0, 0.05, shotT);
        vec3 beamCol = mix(gmix(BEAM), gmix(LIME_HOT), cor);
        beamCol = mix(beamCol, vec3(1.0), max(knob * 0.6, knobW));
        float bm = max(body, knob) * vis;
        base.rgb = mix(base.rgb, beamCol, bm);
        base.a = max(base.a, bm);
        light += gmix(BEAM) * halo * vis * 0.6;
    }

    float fVis = step(0.0005, shotT) * (1.0 - smoothstep(0.08, 0.15, go)) * (SHOT_STYLE == 1 ? 1.0 : 0.0);
    if (fVis > 0.001) {
        vec2 A = vec2(-aspect * 1.12, 0.38);
        vec2 ab = -A;
        float L = length(ab);
        vec2 tv = ab / L;
        vec2 nv = vec2(-tv.y, tv.x);
        float hs = L * pow(shotT, 1.7);
        float tl = 1.2 * (0.4 + 0.6 * sqrt(shotT));
        float ts = mix(max(0.0, hs - tl), hs, smoothstep(0.0, 0.14, go));
        vec2 rel = p - A;
        float sA = dot(rel, tv);
        float nS = dot(rel, nv) - 0.02 * sin(sA * 8.0 - time * 10.0);
        float seg = clamp(sA, ts, hs);
        float along = clamp((seg - ts) / max(hs - ts, 1e-3), 0.0, 1.0);
        float lump = 1.0 + 0.30 * sin(sA * 26.0 - time * 18.0) + 0.15 * sin(sA * 11.0 - time * 7.0);
        float bw = mix(0.018, 0.058, along) * lump;
        float dseg = length(vec2(sA - seg, nS));
        float aaF = max(fwidth(dseg), 1e-4);
        float body = 1.0 - smoothstep(bw - aaF, bw + aaF, dseg);
        float dh = length(vec2(sA - hs, nS));
        float head = 1.0 - smoothstep(0.075 - aaF, 0.075 + aaF, dh);
        float sm = max(body, head);

        float rel2 = nS / max(bw, 1e-3);
        vec3 fc = mix(gmix(vec3(0.30, 0.78, 0.07)), gmix(vec3(0.62, 0.98, 0.20)), smoothstep(0.1, 0.8, rel2) * 0.85);
        fc = mix(fc, gmix(vec3(0.92, 1.00, 0.72)), exp(-pow((rel2 - 0.45) / 0.14, 2.0)) * 0.7 * body);
        fc = mix(fc, gmix(vec3(0.08, 0.38, 0.08)), smoothstep(0.72, 1.0, abs(rel2)) * 0.7 * (1.0 - head));
        fc = mix(fc, gmix(vec3(0.70, 1.00, 0.30)), exp(-dh * dh / 0.0025) * 0.6);

        float drop = 0.0;
        float ci = floor((sA - ts) / 0.11);
        for (int k = -1; k <= 1; k++) {
            float id = ci + float(k);
            float h1 = hash(vec2(id, 3.1));
            float h2 = hash(vec2(id, 7.7));
            float h3 = hash(vec2(id, 1.9));
            float pos = ts + (id + h1) * 0.11;
            float lat = (h2 - 0.5) * 2.0 * (0.06 + 0.14 * along) * (0.7 + 0.3 * sin(time * 6.0 + h3 * 20.0));
            float rr = mix(0.010, 0.026, h3);
            float valid = step(ts, pos) * step(pos, hs - 0.02);
            float dd = length(vec2(sA - pos, nS - lat));
            drop = max(drop, valid * (1.0 - smoothstep(rr - aaF, rr + aaF, dd)));
        }
        vec3 outc = (sm >= drop) ? fc : gmix(vec3(0.34, 0.85, 0.10));
        float vis = fVis * smoothstep(0.0, 0.05, shotT);
        float fm = max(sm, drop) * vis;
        base.rgb = mix(base.rgb, outc, fm);
        base.a = max(base.a, fm);
        light += gmix(vec3(0.4, 1.0, 0.2)) * exp(-dseg * 9.0) * 0.22 * vis;
    }

    if (SHOT_STYLE == 1 && go > 0.001 && go < 0.7) {
        float tS = clamp(go / 0.5, 0.0, 1.0);
        float e = 1.0 - pow(1.0 - tS, 2.5);
        float fade = 1.0 - smoothstep(0.35, 0.7, go);
        float acc = 0.0;
        float yel = 0.0;
        for (int i = 0; i < 16; i++) {
            float fi = float(i);
            float ang = TAU * (fi + hash(vec2(fi, 4.4)) * 0.8) / 16.0;
            float reach = 0.18 + 0.55 * pow(hash(vec2(fi, 8.8)), 1.5);
            vec2 dir = vec2(cos(ang), sin(ang));
            vec2 pe = dir * reach * e;
            vec2 ps = pe * 0.8;
            vec2 pa = p - ps;
            vec2 ba = pe - ps;
            float t = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
            float rr = mix(0.022, 0.058, hash(vec2(fi, 2.2))) * (1.0 - 0.4 * tS);
            float dd = length(pa - ba * t);
            float m = 1.0 - smoothstep(rr * 0.9, rr, dd);
            acc = max(acc, m);
            yel = max(yel, m * step(0.5, hash(vec2(fi, 6.6))));
        }
        vec3 sc = mix(gmix(vec3(0.30, 0.78, 0.08)), gmix(vec3(0.62, 0.92, 0.14)), yel);
        float spm = acc * fade;
        base.rgb = mix(base.rgb, sc, spm);
        base.a = max(base.a, spm);
    }

    float sparkVis = smoothstep(0.05, 0.25, go) * (1.0 - smoothstep(0.0, 0.25, sh)) * live;
    if (sparkVis > 0.001 && d > 0.0) {
        float u = ang01 * 90.0;
        float v = d * 7.0 - time * 3.0;
        float cu = floor(u);
        float cv = floor(v);
        float fu = fract(u) - 0.5;
        float fv = fract(v);
        float cuw = mod(cu, 90.0);
        float h = hash(vec2(cuw, cv));
        float h2 = hash(vec2(cuw * 1.7 + 3.1, cv * 2.3 + 5.7));
        float on = step(0.90, h);
        float w = mix(0.04, 0.11, h2);
        float aa = fwidth(u) + 0.02;
        float sline = 1.0 - smoothstep(w, w + aa, abs(fu));
        float along = pow(smoothstep(0.0, 0.5, fv), 1.5) * (1.0 - fv);
        float fadeOut = exp(-d * 1.6) * smoothstep(0.0, 0.05, d);
        light += mix(gmix(LIME), gmix(LIME_HOT), 0.5) * on * sline * along * fadeOut * 0.45 * sparkVis;
    }

    float zl = smoothstep(0.08, 0.40, sh) * (1.0 - smoothstep(0.35, 0.9, cc)) * live;
    if (zl > 0.001) {
        float lr = log(rq + 0.05);
        float N = 72.0;
        float u = ang01 * N;
        float v = lr * 4.0 - time * (2.0 + 6.0 * zs);
        float cu = floor(u);
        float cv = floor(v);
        float fu = fract(u) - 0.5;
        float fv = fract(v);
        float cuw = mod(cu, N);
        float h = hash(vec2(cuw, cv));
        float h2 = hash(vec2(cuw * 1.7 + 3.1, cv * 2.3 + 5.7));
        float on = step(0.80, h);
        float w = mix(0.05, 0.14, h2);
        float aa = fwidth(u) + 0.02;
        float sline = 1.0 - smoothstep(w, w + aa, abs(fu));
        float along = pow(smoothstep(0.0, 0.8, fv), 2.0) * (1.0 - smoothstep(0.92, 1.0, fv));
        float radial = 0.35 + 0.65 * smoothstep(0.2, 1.6, rq);
        light += mix(gmix(LIME), vec3(1.0), 0.5) * on * sline * along * radial * 0.55 * zl;
    }

    float impact = exp(-r * r * 60.0) * pow(1.0 - go, 3.0) * smoothstep(0.0, 0.03, go);
    light += mix(gmix(LIME_HOT), vec3(1.0), 0.5) * impact * 1.1;
    float burstT = smoothstep(0.0, 0.4, go);
    if (go > 0.0005 && go < 0.45) {
        float ab01 = atan(p.y, p.x) / TAU + 0.5;
        float u = ab01 * 56.0;
        float cu = mod(floor(u), 56.0);
        float fu = fract(u) - 0.5;
        float h = hash(vec2(cu, 7.7));
        float reach = (0.15 + 0.95 * h) * (1.0 - pow(1.0 - burstT, 2.0));
        float wsp = 0.05 * (1.0 - clamp(r / max(reach, 0.01), 0.0, 1.0)) + 0.01;
        float spoke = step(0.35, h) * (1.0 - smoothstep(wsp, wsp + 0.03, abs(fu))) * step(0.03, r) * (1.0 - smoothstep(reach * 0.7, reach, r));
        light += mix(gmix(LIME), gmix(LIME_HOT), 0.6) * spoke * pow(1.0 - burstT, 1.5) * 1.1;
    }
    float rippleR = 0.05 + 2.2 * pow(go, 0.8);
    light += gmix(LIME) * ringShape(r, rippleR, 0.035 + 0.05 * go) * (1.0 - smoothstep(0.55, 1.0, go)) * smoothstep(0.0, 0.05, go) * 0.28;

    float flashCore = exp(-r * r * 18.0) * pow(1.0 - pk, 2.2) * popRamp;
    float flashGlow = exp(-r * 2.2) * pow(1.0 - pk, 3.0) * 0.6 * popRamp;
    light += mix(gmix(LIME_HOT), vec3(1.0), 0.6) * (flashCore * 1.6 + flashGlow);

    float rs = 0.1 + 2.6 * (1.0 - pow(1.0 - pk, 2.0));
    float wid = 0.03 + 0.10 * pk;
    float sI = pow(1.0 - pk, 1.4) * popRamp;
    vec3 shock = vec3(ringShape(r, rs * 1.012, wid),
                      ringShape(r, rs, wid),
                      ringShape(r, rs * 0.988, wid)) * sI;
    light += shock * mix(gmix(LIME), vec3(1.0), 0.2) * 0.9;

    float pk2 = clamp((pk - 0.12) / 0.88, 0.0, 1.0);
    float rs2 = 0.05 + 2.3 * (1.0 - pow(1.0 - pk2, 2.0));
    float sI2 = pow(1.0 - pk2, 1.6) * 0.4 * smoothstep(0.0, 0.05, pk2);
    light += gmix(LIME_DEEP) * 2.0 * ringShape(r, rs2, 0.04 + 0.08 * pk2) * sI2;

    float edgeBand = ringShape(r, revR + 0.45 * REV_EDGE, 0.28) * revLive;
    float spark = step(0.82, hash(floor(qt_TexCoord0 * resolution / 3.0) + floor(time * 9.0) * 3.7));
    light += gmix(LIME) * ringShape(r, revR + 0.45 * REV_EDGE, 0.22) * revLive * 0.28;
    light += gmix(LIME_HOT) * edgeBand * spark * 0.35;

    vec3 rgb = min(base.rgb + light, vec3(1.0));
    float al = max(base.a, max(rgb.r, max(rgb.g, rgb.b)) * 0.7);
    fragColor = vec4(rgb, min(al, 1.0)) * qt_Opacity;
}

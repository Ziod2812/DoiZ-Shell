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
const int NS = 14;
const int NC = 14;
const float SLIDE = 0.07;

const vec3 CYAN = vec3(0.25, 0.85, 1.00);
const vec3 PINK = vec3(1.00, 0.35, 0.80);
const vec3 ICE_HOT = vec3(0.82, 0.95, 1.00);
const vec3 ICE_DEEP = vec3(0.012, 0.035, 0.085);
const vec3 SPARK = vec3(1.00, 0.86, 0.45);

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float h11(float x) {
    return fract(sin(x * 127.1 + 311.7) * 43758.5453);
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

vec2 rot(vec2 v, float a) {
    float co = cos(a);
    float si = sin(a);
    return vec2(co * v.x - si * v.y, si * v.x + co * v.y);
}

void slashGeom(float fi, float aspect, out vec2 c, out vec2 dir) {
    float h1 = h11(fi + 1.0);
    float h2 = h11(fi + 21.0);
    float h3 = h11(fi + 41.0);
    float h4 = h11(fi + 61.0);
    float h5 = fract(h1 * 37.7 + h2 * 11.3);
    float h7 = fract(h3 * 29.3 + h4 * 17.1);
    float h8 = fract(h4 * 41.9 + h1 * 5.3);
    float h9 = fract(h5 * 71.3 + h7 * 3.7);
    vec2 v = vec2(h1, h2) * 2.0 - 1.0;
    c = v * vec2(aspect * 0.95, 0.92);
    float sgn = h4 > 0.5 ? 1.0 : -1.0;
    float ang = h3 < 0.50 ? (h9 * 2.0 - 1.0) * 0.26
              : h3 < 0.95 ? sgn * (0.28 + 0.52 * h8)
              : sgn * (0.85 + 0.25 * h9);
    dir = vec2(cos(ang), sin(ang));
}

float ringShape(float r, float radius, float width) {
    float d = (r - radius) / width;
    return exp(-d * d);
}

struct Reg {
    float code;
    vec2 dir;
    float dmin;
};

Reg region(vec2 q) {
    Reg r;
    r.code = 0.0;
    r.dir = vec2(0.0);
    r.dmin = 9.0;
    float asp = resolution.x / max(resolution.y, 1.0);
    for (int i = 0; i < NC; i++) {
        vec2 c;
        vec2 dr;
        slashGeom(float(i), asp, c, dr);
        vec2 n = vec2(-dr.y, dr.x);
        float d = dot(q - c, n);
        float sg = step(0.0, d);
        r.code = r.code * 2.0 + sg;
        r.dir += (sg * 2.0 - 1.0) * n;
        r.dmin = min(r.dmin, abs(d));
    }
    return r;
}

vec2 pieceOff(Reg r, float t) {
    float h1 = h11(r.code);
    float h2 = h11(r.code + 31.7);
    vec2 dn = normalize(r.dir + (vec2(h1, h2) - 0.5) * 2.0 + vec2(0.001));
    float tp = clamp((t - 0.25 * h1) / 0.75, 0.0, 2.0);
    float e = tp <= 1.0 ? 1.0 - pow(1.0 - tp, 2.5) : 1.0 + (tp - 1.0) * 0.8;
    return dn * (0.05 + 0.30 * h2) * SLIDE * 3.0 * e;
}

vec2 sourceOf(vec2 p, float t, out Reg rg, out float hit) {
    hit = 0.0;
    rg = region(p);
    vec2 s = p;
    vec2 cand = p;
    for (int k = 0; k < 4; k++) {
        Reg c = region(cand);
        vec2 sc = p - pieceOff(c, t);
        Reg rs = region(sc);
        if (abs(rs.code - c.code) < 0.5) {
            hit = 1.0;
            rg = rs;
            s = sc;
            break;
        }
        cand = sc;
    }
    return s;
}

float nearestCut(vec2 p) {
    float m = 9.0;
    float asp = resolution.x / max(resolution.y, 1.0);
    for (int i = 0; i < NC; i++) {
        vec2 c;
        vec2 dr;
        slashGeom(float(i), asp, c, dr);
        m = min(m, abs(dot(p - c, vec2(-dr.y, dr.x))));
    }
    return m;
}

vec2 glitchUV(vec2 q, float gl) {
    float tt = floor(time * 14.0);
    float row = floor((q.y * 0.5 + 0.5) * 34.0);
    float hb = hash(vec2(row, tt));
    q.x += (hb - 0.5) * 0.40 * step(0.74, hb) * gl;
    vec2 blk = floor(q * vec2(5.0, 9.0));
    float hk = hash(blk + tt);
    q += (vec2(hash(blk + 3.1 + tt), hash(blk + 7.7 + tt)) - 0.5) * 0.16 * step(0.88, hk) * gl;
    return q;
}

vec3 shot(vec2 q, float aspect) {
    vec2 uv = q / (vec2(aspect, 1.0) * 2.0) + 0.5;
    return texture(snap, clamp(uv, 0.0, 1.0)).rgb;
}

vec3 pickup(vec2 q, float aspect, float blur, float split, vec2 jitter) {
    vec3 acc = vec3(0.0);
    float n = 0.0;
    for (int k = 0; k < 8; k++) {
        float f = (float(k) + jitter.x) / 8.0;
        vec2 qq = q * (1.0 - blur * f);
        vec3 c;
        c.r = shot(qq + vec2(split, 0.0), aspect).r;
        c.g = shot(qq, aspect).g;
        c.b = shot(qq - vec2(split, 0.0), aspect).b;
        acc += c;
        n += 1.0;
    }
    return acc / n;
}

vec3 gradeMono(vec3 c, float drain, vec2 pix) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    float cr = pow(smoothstep(0.03, 0.78, l), 1.25);
    vec3 mono = mix(vec3(0.0, 0.010, 0.032), vec3(0.76, 0.93, 1.0), cr);
    mono += vec3(0.01, 0.07, 0.11) * smoothstep(0.0, 0.35, l) * (1.0 - cr) * 0.7;
    float grain = hash(pix + fract(time) * 31.0) - 0.5;
    mono *= 1.0 + grain * 0.22;
    return mix(c, mono, drain);
}

vec2 slashes(vec2 p, float u, float aspect) {
    float core = 0.0;
    float glow = 0.0;
    float aa = 2.2 / max(resolution.y, 1.0);
    float tick = floor(time * 22.0);
    for (int i = 0; i < NS; i++) {
        float fi = float(i);
        float h1 = h11(fi + 1.0);
        float h2 = h11(fi + 21.0);
        float h3 = h11(fi + 41.0);
        float h4 = h11(fi + 61.0);
        float h5 = fract(h1 * 37.7 + h2 * 11.3);
        float h6 = fract(h2 * 53.1 + h3 * 7.9);
        float h7 = fract(h3 * 29.3 + h4 * 17.1);
        float h8 = fract(h4 * 41.9 + h1 * 5.3);
        float h9 = fract(h5 * 71.3 + h7 * 3.7);

        float wave = min(floor(h6 * 3.0), 2.0);
        float ts = 0.20 + 0.23 * wave + 0.07 * h7 + 0.015 * h9;
        float age = u - ts;
        if (age < 0.0)
            continue;

        vec2 c;
        vec2 dir;
        slashGeom(fi, aspect, c, dir);
        vec2 nrm = vec2(-dir.y, dir.x);

        float hl = mix(1.5, 3.2, pow(h5, 0.7));

        float fat = 0.0;
        vec2 rel = p - c;
        float s = dot(rel, dir);
        float d = dot(rel, nrm);
        if (abs(d) > 0.25 || abs(s) > hl + 0.06)
            continue;

        float way = h7 > 0.5 ? 1.0 : -1.0;
        float sw = s * way;
        float q = clamp(age / 0.040, 0.0, 1.0);
        float reach = mix(-hl, hl, 1.0 - pow(1.0 - q, 3.0));
        float inLen = step(-hl, sw) * (1.0 - smoothstep(reach - 0.03, reach, sw));

        float tp = 1.0 - clamp(abs(s) / hl, 0.0, 1.0);
        float taper = smoothstep(0.0, 0.30, tp);
        float thick = fat > 0.5 ? 0.0065 + 0.0075 * h5 : 0.0012 + 0.0020 * h9 * h9;
        float rough = 0.80 + 0.40 * vn(vec2(s * 38.0, fi * 3.1));
        float flare = exp(-max(age - 0.040, 0.0) * 9.0);
        float w = thick * rough * (0.12 + 0.88 * taper) * (1.0 + 1.6 * flare);

        float soft = fat > 0.5 ? 0.55 : 0.0;
        float c0 = (1.0 - smoothstep(w * (1.0 - soft), w + aa, abs(d))) * inLen;
        c0 *= fat > 0.5 ? 0.55 : 1.0;
        float g0 = (exp(-abs(d) * (fat > 0.5 ? 24.0 : 85.0)) * 0.22 + exp(-abs(d) * 8.0) * 0.006)
                 * inLen * (0.35 + 0.65 * taper);
        float head = exp(-pow((sw - reach) / 0.035, 2.0)) * exp(-abs(d) * 90.0)
                   * (1.0 - smoothstep(0.6, 1.0, q)) * 0.9;

        float flick = 0.86 + 0.14 * step(0.25, h11(fi + tick * 3.17));
        core = max(core, c0 * flick);
        glow += (g0 * (1.0 + flare * 1.3) + head) * flick;
    }
    return vec2(core, 1.0 - exp(-glow * 1.15));
}

float arcDist(vec2 p, vec2 a, vec2 b, float seed) {
    vec2 ab = b - a;
    vec2 nv = normalize(vec2(-ab.y, ab.x));
    float tk = floor(time * 16.0);
    vec2 prev = a;
    float m = 9.0;
    for (int k = 1; k <= 7; k++) {
        float t = float(k) / 7.0;
        float off = (h11(seed + float(k) * 3.7 + tk * 1.3) - 0.5) * 0.16 * sin(PI * t);
        vec2 cur = mix(a, b, t) + nv * off;
        vec2 e = cur - prev;
        float tt = clamp(dot(p - prev, e) / max(dot(e, e), 1e-6), 0.0, 1.0);
        m = min(m, length(p - prev - e * tt));
        prev = cur;
    }
    return m;
}

void main() {
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) * 2.0;
    float r = length(p);
    vec2 pix = qt_TexCoord0 * resolution;
    float snapOn = step(0.5, snapAmt);

    float gAll = clamp(grow, 0.0, 1.0);
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

    float started = step(0.001, gAll);
    float burst0 = (1.0 - smoothstep(0.0, 0.15, gAll)) * started;
    float gl = smoothstep(0.07, 0.13, gAll) * (1.0 - smoothstep(0.26, 0.36, gAll)) + 0.35 * exp(-sh * 6.0) * step(0.001, sh);
    float drain = smoothstep(0.10, 0.34, gAll);
    float zoomC = 0.0;
    float fall = smoothstep(0.0, 0.9, cc);
    float u = gAll + 0.9 * sh;

    float shakeAmp = 0.0;
    shakeAmp += exp(-max(gAll - 0.22, 0.0) * 55.0) * step(0.22, gAll);
    shakeAmp += exp(-max(gAll - 0.46, 0.0) * 55.0) * step(0.46, gAll);
    shakeAmp += exp(-max(gAll - 0.70, 0.0) * 55.0) * step(0.70, gAll);
    shakeAmp += exp(-sh * 9.0) * step(0.001, sh) * 1.4;
    float shakeT = floor(time * 36.0);
    vec2 shk = (vec2(h11(shakeT), h11(shakeT + 9.0)) - 0.5) * 0.030 * shakeAmp;
    vec2 p2 = p + shk;

    float slideT = smoothstep(0.0, 0.85, sh) + 1.7 * fall;
    float lineFade = (1.0 - 0.55 * smoothstep(0.55, 1.0, sh)) * (1.0 - smoothstep(0.0, 0.55, cc));

    vec3 tint = mix(CYAN, glowColor.rgb, 0.2);

    float dP = nearestCut(p2);
    float leak = exp(-dP * 14.0) * smoothstep(0.0, 0.25, sh);
    vec3 voidCol = ICE_DEEP * (0.7 + 0.8 * exp(-r * 0.9))
                 + tint * leak * 0.16
                 + ICE_HOT * exp(-dP * 110.0) * leak * 0.28;

    vec4 base;
    if (snapOn > 0.5) {
        Reg rg;
        float hit = 1.0;
        vec2 src = p2;
        if (sh > 0.001)
            src = sourceOf(p2, slideT, rg, hit);
        else
            rg = region(p2);
        vec2 dsp = p2 - src;
        vec2 pgl = glitchUV(src, gl);
        float blur = 0.10 * burst0 + 0.50 * zoomC;
        float split = 0.006 * gl + 0.010 * burst0 + 0.55 * length(dsp) * 0.05 + 0.012 * zoomC;
        float jit = hash(pix + fract(time) * 17.0);
        vec3 col = pickup(pgl, aspect, blur, split, vec2(jit, 0.0));
        vec2 uvn = qt_TexCoord0;
        float tt = floor(time * 14.0);
        vec2 blk = floor(uvn * vec2(14.0, 22.0));
        float hk = hash(blk + tt * 1.7);
        float blkOn = step(0.935, hk) * gl;
        vec3 blkCol = mix(vec3(1.0, 0.25, 0.75), vec3(0.45, 1.0, 0.25), step(0.5, hash(blk + 5.0 + tt)));
        col = mix(col, blkCol * (0.6 + 0.6 * hash(blk + tt)), blkOn * 0.85);
        for (int b = 0; b < 5; b++) {
            float fb = float(b);
            float by = (h11(fb + 77.0 + tt * 1.9) * 2.0 - 1.0);
            float bw = 0.004 + 0.012 * h11(fb + 88.0 + tt);
            float bm = (1.0 - smoothstep(bw, bw * 1.8, abs(p.y - by))) * step(0.35, h11(fb + 99.0 + tt * 0.7));
            col += mix(CYAN, vec3(1.0), 0.5) * bm * gl * 1.3;
        }
        col = gradeMono(col, drain, pix);
        col *= 1.0 - 0.50 * smoothstep(0.20, 0.34, gAll) * (1.0 - smoothstep(0.0, 0.35, sh));
        float seamAmt = 1.0 - 0.5 * smoothstep(0.1, 0.9, sh);
        float edge = exp(-rg.dmin * 90.0) * seamAmt * step(0.001, sh);
        float edgeCore = (1.0 - smoothstep(0.003, 0.003 + fwidth(rg.dmin) + 1e-4, rg.dmin)) * seamAmt * step(0.001, sh);
        col += mix(tint, ICE_HOT, 0.6) * edge * 0.30;
        col = mix(col, vec3(1.0), edgeCore * 0.30);
        float inb = 1.0;
        base = vec4(mix(voidCol, col, hit * inb * (1.0 - smoothstep(0.15, 0.85, cc))), 1.0);
    } else {
        float dim = 0.40 * smoothstep(0.0, 0.5, gAll);
        base = vec4(bgColor.rgb * dim, dim);
        float k = smoothstep(0.0, 0.3, sh);
        base = vec4(mix(base.rgb, voidCol, k), mix(base.a, 1.0, k));
    }

    vec3 light = vec3(0.0);

    light += mix(CYAN, vec3(1.0), 0.35) * burst0 * exp(-r * 1.3) * 1.4;
    light += PINK * burst0 * smoothstep(0.1, 0.9, p.y) * exp(-r * 0.8) * 0.8;
    float hz = ringShape(p.y, -0.15, 0.09) * burst0 * 0.9;
    light += mix(CYAN, vec3(1.0), 0.6) * hz;

    vec2 sl = slashes(p2, u, aspect);
    vec2 wp = vec2(0.0);
    float core = max(sl.x, wp.x) * lineFade;
    float glw = (sl.y + wp.y) * lineFade;
    light += mix(tint, ICE_HOT, 0.5) * glw;
    base.rgb = mix(base.rgb, vec3(1.0), core);
    base.a = max(base.a, core);
    base.a = max(base.a, min(glw, 1.0) * 0.6);

    float impact = exp(-sh * 10.0) * smoothstep(0.0, 0.012, sh);
    light += mix(ICE_HOT, vec3(1.0), 0.6) * impact * (0.30 + 1.0 * exp(-r * r * 2.0));

    float wc = smoothstep(0.0, 0.8, cc);
    float haze = 1.0 - smoothstep(0.0, 0.9, rv);
    vec3 flashCol = mix(CYAN, vec3(1.0), 0.8);
    float abin = atan(p.y, p.x) / TAU * 46.0;
    float burstRays = (0.25 + 0.75 * hash(vec2(floor(abin), floor(time * 18.0)))) * smoothstep(0.0, 0.35, 0.5 - abs(fract(abin) - 0.5)) * exp(-r * 0.4);
    vec3 zoomTint = mix(vec3(0.20, 0.70, 1.0), vec3(1.0, 0.45, 0.85), smoothstep(-0.1, 0.9, p.y));
    base.rgb = mix(base.rgb, base.rgb * zoomTint * 1.7 + zoomTint * 0.18, zoomC * 0.8);
    light += zoomTint * burstRays * zoomC * 0.55 * (1.0 - smoothstep(0.0, 0.25, rv));
    float wf = smoothstep(0.55, 1.0, cc);
    vec3 flashFull = flashCol;
    base.rgb = mix(base.rgb, flashFull * haze, wf);
    base.a = mix(base.a, haze, wf);
    base *= darkRemain;

    float flashCore = exp(-r * r * 14.0) * pow(1.0 - pk, 2.0) * popRamp;
    float flashGlow = exp(-r * 1.8) * pow(1.0 - pk, 3.0) * 0.6 * popRamp;
    light += mix(CYAN, vec3(1.0), 0.6) * (flashCore * 1.5 + flashGlow);

    float rs = 0.1 + 2.6 * (1.0 - pow(1.0 - pk, 2.0));
    float wid = 0.03 + 0.10 * pk;
    float sI = pow(1.0 - pk, 1.4) * popRamp;
    vec3 shock = vec3(ringShape(r, rs * 1.012, wid),
                      ringShape(r, rs, wid),
                      ringShape(r, rs * 0.988, wid)) * sI;
    light += shock * mix(tint, vec3(1.0), 0.3) * 0.9;

    float mist = fbm(p * 1.5 + vec2(time * 0.12, -time * 0.07));
    float mistOn = smoothstep(0.0, 0.12, rv) * (1.0 - smoothstep(0.45, 1.0, rv));
    light += mix(vec3(0.10, 0.38, 0.52), vec3(0.45, 0.80, 0.95), mist) * mist * mistOn * 0.55 * (1.0 - darkRemain * 0.5);
    base.a = max(base.a, mist * mistOn * 0.35 * step(0.001, rv));

    float edgeBand = ringShape(r, revR + 0.45 * REV_EDGE, 0.28) * revLive;
    float spark = step(0.82, hash(floor(pix / 3.0) + floor(time * 9.0) * 3.7));
    light += tint * ringShape(r, revR + 0.45 * REV_EDGE, 0.22) * revLive * 0.28;
    light += ICE_HOT * edgeBand * spark * 0.35;

    vec3 rgb = min(base.rgb + light, vec3(1.0));
    float al = max(base.a, max(rgb.r, max(rgb.g, rgb.b)) * 0.7);
    fragColor = vec4(rgb, min(al, 1.0)) * qt_Opacity;
}

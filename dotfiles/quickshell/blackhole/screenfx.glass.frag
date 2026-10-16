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
    vec2 resolution;
    vec4 hotColor;
    vec4 glowColor;
    vec4 bgColor;
};

layout(binding = 1) uniform sampler2D snap;

const float PI = 3.14159265;
const float TAU = 6.2831853;

const float SECT = 14.0;
const float RING0 = 0.17;
const float RINGG = 1.5;
const float LOGG = 0.405465;

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

float ringShape(float r, float radius, float width) {
    float d = (r - radius) / width;
    return exp(-d * d);
}

float hmod(float x) {
    return mod(x, SECT);
}

float hs(float cid, float k) {
    float m = hmod(cid);
    return hash(vec2(m * 0.77 + k, m * 1.31 + k * 2.0));
}

float crackPath(float cid, float rw) {
    float m = hmod(cid);
    float t = rw * 7.0;
    float i = floor(t);
    float f = t - i;
    float a = hash(vec2(m * 1.7 + 2.0, i + 1.0));
    float b = hash(vec2(m * 1.7 + 2.0, i + 2.0));
    return 0.30 * (mix(a, b, f) - 0.5) * min(1.0, rw * 3.0);
}

void sector(float a01, float rt, out float s, out float fx, out float wU)
{
    float x = a01 * SECT;
    x += 0.9 * (vnoise(vec2(x, 3.7), SECT) - 0.5);
    float s0 = floor(x);
    float xl0 = s0 + crackPath(s0, rt);
    float xr0 = s0 + 1.0 + crackPath(s0 + 1.0, rt);
    s = (x < xl0) ? s0 - 1.0 : s0;
    if (x >= xr0)
        s = s0 + 1.0;
    float xl = s + crackPath(s, rt);
    float xr = s + 1.0 + crackPath(s + 1.0, rt);
    fx = clamp((x - xl) / max(xr - xl, 1e-3), 0.0, 1.0);
    wU = max(xr - xl, 0.2);
}

float ringBound(float s, float j, float fx) {
    float m = hmod(s);
    float rj = RING0 * exp(LOGG * (j + (hash(vec2(m * 1.3 + 0.5, j * 2.1 + 4.0)) - 0.5) * 0.8));
    float tilt = (hash(vec2(m + 3.3, j + 1.1)) - 0.5) * 0.4;
    return rj * (1.0 + tilt * (fx - 0.5) * 0.9);
}

float shardFall(float s, float j, float c) {
    float h = hash(vec2(hmod(s) * 1.7 + 3.0, j * 2.9 + 1.0));
    float td = 0.030 * (j + 5.0) + 0.14 * h;
    float u = clamp((c - td) / 0.5, 0.0, 1.0);
    return u * u;
}

void shatter(vec2 pt, float c, out vec2 q, out float alive, out float fall, out float ratio)
{
    q = pt;
    ratio = 1.0;
    alive = 1.0;
    fall = 0.0;
    if (c <= 0.0)
        return;
    alive = 0.0;

    float s0;
    float fx0;
    float wU0;
    sector(atan(pt.y, pt.x) / TAU + 0.5, length(pt), s0, fx0, wU0);
    float best = 1.0e9;
    for (int ds = -1; ds <= 1; ds++) {
        float sk = s0 + float(ds);
        float ac = ((sk + 0.5) / SECT - 0.5) * TAU;
        vec2 dir = vec2(cos(ac), sin(ac));
        for (int i = 0; i < 14; i++) {
            float j = float(i) - 5.0;
            float fl = shardFall(sk, j, c);
            float inv = 1.0 / (1.0 - 0.985 * fl);
            if (inv >= best)
                continue;
            float lo = (i == 0) ? 0.0 : ringBound(sk, j, 0.5);
            float hi = (i == 13) ? 1000.0 : ringBound(sk, j + 1.0, 0.5);
            float rlo = (i == 0) ? 0.5 * hi : lo;
            float rhi = (i == 13) ? 1.4 * lo : hi;
            float rc = sqrt(rlo * rhi);
            float ext = 0.6 * length(vec2(rhi - rlo, rc * TAU / SECT * 1.5));
            vec2 cc = dir * rc;
            vec2 d = pt - cc / inv;
            if (length(d) > ext / inv)
                continue;
            float th = (hash(vec2(hmod(sk) * 2.3 + 7.0, j * 1.9 + 5.0)) - 0.5) * 2.4 * fl;
            float co = cos(th);
            float si = sin(th);
            vec2 qq = cc + inv * vec2(co * d.x + si * d.y, -si * d.x + co * d.y);

            float s1;
            float fx1;
            float wU1;
            sector(atan(qq.y, qq.x) / TAU + 0.5, length(qq), s1, fx1, wU1);
            float qr = max(length(qq) * cos((fx1 - 0.5) * TAU / SECT), 0.001);
            float t0 = floor(log(qr / RING0) / LOGG);
            float band = -5.0;
            for (int k = -1; k <= 1; k++) {
                float jj = t0 + float(k);
                if (jj >= -4.0 && qr >= ringBound(s1, jj, fx1))
                    band = jj;
            }
            if (hmod(s1) == hmod(sk) && band == j) {
                best = inv;
                q = qq;
                fall = fl;
                ratio = inv;
                alive = 1.0 - smoothstep(0.55, 0.95, fl);
            }
        }
    }
}

float glass(vec2 q, float psP, float reach, float tw, float rt, float full,
            out float halo, out float fh, out float fh2, out float fx, out float dist)
{
    float r = length(q);
    float a = atan(q.y, q.x) / TAU + 0.5 + tw * exp(-1.6 * rt) / TAU;
    float s;
    float wU;
    sector(a, rt, s, fx, wU);
    float arc = TAU * r / SECT * wU;
    float m = hmod(s);
    float d = 1000.0;

    for (int side = 0; side < 2; side++) {
        float cid = s + float(side);
        float lim = reach * (0.6 + 0.8 * hs(cid, 1.7));
        bool on = full > 0.5 || (r <= lim && r < 1.5 + 1.8 * hs(cid, 6.1));
        float dist = ((side == 0) ? fx : 1.0 - fx) * arc;
        float tip = (full > 0.5) ? 1.0 : clamp((lim - r) / (0.12 + 0.25 * lim), 0.2, 1.0);
        if (on)
            d = min(d, dist / tip);
    }

    for (int side = 0; side < 2; side++) {
        for (int k = 0; k < 2; k++) {
            float cid = s + float(side);
            float fk = float(k);
            float hb = hs(cid, 10.0 + fk * 3.1 + float(side) * 5.0);
            float rb = 0.22 + 1.1 * hs(cid, 20.0 + fk * 1.9 + float(side) * 2.3);
            float ln = 0.25 + 0.9 * hs(cid, 30.0 + fk * 2.7);
            float ang = 0.30 + 0.45 * hs(cid, 40.0 + fk);
            if (hb > 0.38 && r > rb && r < rb + ln && r < reach * 0.95) {
                float lat = ((side == 0) ? fx : 1.0 - fx) * arc;
                float dist = abs(lat - (r - rb) * ang) * inversesqrt(1.0 + ang * ang);
                float tp = clamp((rb + ln - r) / (0.3 * ln + 0.03), 0.2, 1.0);
                d = min(d, dist / tp);
            }
        }
    }

    float cs = cos((fx - 0.5) * TAU / SECT);
    float qr = max(r * cs, 0.001);
    float t0 = floor(log(qr / RING0) / LOGG);
    float band = -5.0;
    for (int k = -1; k <= 1; k++) {
        float jj = t0 + float(k);
        if (jj >= -4.0 && qr >= ringBound(s, jj, fx))
            band = jj;
    }
    for (int k = -1; k <= 2; k++) {
        float jj = t0 + float(k);
        if (jj < -4.0)
            continue;
        bool on = full > 0.5
            || (hash(vec2(m * 1.37 + jj * 0.9, jj * 1.7 + m * 0.3)) > 0.25 + 0.07 * max(jj, 0.0)
                && r < reach * (0.8 + 0.4 * hash(vec2(m, 2.2))));
        if (on)
            d = min(d, abs(qr - ringBound(s, jj, fx)));
    }

    fh = hash(vec2(m * 1.31 + 0.5, band * 2.17 + 0.5));
    fh2 = hash(vec2(m + 11.0, band + 3.0));

    float lw = psP * (0.45 + 1.3 * exp(-2.4 * r));
    dist = d / max(psP, 1e-6);
    halo = exp(-d / (psP * 7.0));
    return 1.0 - smoothstep(lw - 0.6 * psP, lw + 0.6 * psP, d);
}

const float HORIZON = 0.11;

vec3 wormhole(vec2 p, float r, float open, vec3 hot, vec3 glow) {
    float vr = max(r, 0.002);
    float va = atan(p.y, p.x);
    float zd = 1.0 / (vr * 1.4 + 0.12);
    float sp = va - 1.1 * log(vr + 0.05) + time * 0.25;

    float arms = pow(0.5 + 0.5 * sin(sp * 3.0 + zd * 0.9 - time * 1.4), 3.0);
    float fil = pow(0.5 + 0.5 * sin(sp * 11.0 - time * 2.0 + zd * 2.0), 12.0);
    float fade = exp(-vr * 1.5);

    vec3 col = bgColor.rgb * 0.06;
    col += glow * arms * 0.20 * fade;
    col += mix(glow, hot, 0.5) * fil * 0.18 * fade * smoothstep(0.10, 0.45, vr);

    float rh = HORIZON * smoothstep(0.0, 0.35, open);
    float side = 0.65 + 0.35 * sin(va + time * 0.6);
    col += mix(glow, hot, 0.45) * exp(-max(vr - rh, 0.0) * 9.0) * 0.30 * side * step(rh, vr) * open;
    float ring = exp(-pow((vr - rh * 1.08) / (0.010 + 0.016 * vr), 2.0));
    col += hot * ring * 0.85 * side * open;
    return col * smoothstep(rh * 0.86, rh * 1.0, vr);
}

void main() {
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0) * 2.0;
    float r = length(p);
    float ang01 = atan(p.y, p.x) / TAU + 0.5;
    float ps = 2.0 / max(resolution.y, 1.0);
    float snapOn = step(0.5, snapAmt);

    float g = clamp(grow, 0.0, 1.0);
    float c = clamp(collapse, 0.0, 1.0);
    float sh = clamp(breakAmt, 0.0, 1.0);
    float op = clamp(openAmt, 0.0, 1.0);
    float popRamp = smoothstep(0.0, 0.04, pop);
    float pk = pop;
    float revLive = smoothstep(0.0, 0.06, reveal) * (1.0 - smoothstep(0.82, 1.0, reveal));

    float tw = 0.5 * g + 3.2 * pow(sh, 1.4) + (1.0 - snapOn) * 0.05 * time;
    float ratio;
    float alive;
    float fall;
    float twist = tw * exp(-1.6 * r);
    vec2 pt = rot(p, twist);
    vec2 q;
    shatter(pt, sh, q, alive, fall, ratio);

    float rv = clamp(reveal, 0.0, 1.0);
    float re = rv * rv * (3.0 - 2.0 * rv);
    float corner = length(vec2(aspect, 1.0));
    const float REV_EDGE = 0.9;
    float revR = mix(-REV_EDGE, corner, re);
    float darkRemain = smoothstep(revR, revR + REV_EDGE, r);

    vec3 hot = mix(hotColor.rgb, vec3(1.0), 0.35);
    vec3 lineCol = mix(hot, vec3(1.0), 0.45);
    float tick = floor(time * 9.0);

    float reach = 0.10 + 2.4 * g;
    float halo;
    float fh;
    float fh2;
    float fx;
    float dpx;
    float line = glass(q, ps * ratio, reach, 0.0, length(q), step(0.001, sh), halo, fh, fh2, fx, dpx);
    float rq = length(q);
    float brk = smoothstep(0.0, 0.02, sh) * (1.0 - smoothstep(0.02, 0.30, sh));

    vec4 outc;
    vec3 light = vec3(0.0);

    if (snapOn > 0.5) {
        vec2 invAsp = 1.0 / (vec2(aspect, 1.0) * 2.0);

        vec2 qi = rot(q, -0.5 * g * exp(-1.6 * rq));
        float trem = clamp(fall * 5.0, 0.0, 1.0) * (1.0 - fall);
        qi += 0.010 * trem * vec2(sin(time * 47.0 + fh * 40.0), cos(time * 61.0 + fh2 * 40.0));

        float gv = smoothstep(0.0, 0.08, g);
        vec2 shift = ((vec2(fh, fh2) - 0.5) * 0.008 + (fx - 0.5) * (vec2(fh2, fh) - 0.5) * 0.012)
                     * halo * gv * ratio;
        vec2 uv0 = qi * invAsp + 0.5;
        vec2 ds = shift * invAsp;
        vec3 img = vec3(texture(snap, uv0 + ds * 1.30).r,
                        texture(snap, uv0 + ds).g,
                        texture(snap, uv0 + ds * 0.70).b);

        img *= 1.0 + (fh2 - 0.5) * 0.20 * halo * gv;
        float vig = smoothstep(0.45, 1.7, r);
        img *= 1.0 - (0.10 + 0.25 * sh) * vig * g;
        float depth = smoothstep(0.05, 1.0, fall);
        img *= 1.0 - 0.70 * depth;
        float heat = (1.0 - smoothstep(0.15, 1.3, r)) * smoothstep(0.0, 0.12, sh);

        float edgeSoft = 1.0 - smoothstep(0.8, 3.2, dpx);
        float crackOn = gv * smoothstep(0.015, 0.10, r);
        float rimSide = 0.35 + 0.65 * fh2;
        vec3 shard = img;
        shard += lineCol * line * (0.45 + 1.1 * brk) * crackOn;
        shard += mix(glowColor.rgb, hot, 0.5) * edgeSoft * (0.10 + 0.22 * rimSide) * step(0.001, sh) * crackOn;
        shard += mix(glowColor.rgb, hot, 0.7) * line * heat * 0.9 * crackOn * step(0.001, sh);
        shard *= 1.0 - pow(halo, 3.0) * 0.22 * (1.0 - line) * crackOn;
        float sheen = 4.0 * fall * (1.0 - fall) * (0.5 + 0.5 * sin(6.0 * fh2 + 9.0 * fall));
        shard += mix(glowColor.rgb, hot, 0.5) * sheen * 0.20;
        float swallowed = mix(1.0, smoothstep(HORIZON * 0.5, HORIZON * 1.4, r), smoothstep(0.0, 0.08, sh));
        float cover = alive * swallowed;

        vec3 voidCol = wormhole(p, r, smoothstep(0.0, 0.25, sh), hot, glowColor.rgb);
        vec3 scene = mix(voidCol, shard, cover);

        scene = mix(scene, bgColor.rgb * 0.9, 0.93 * smoothstep(0.15, 1.0, c));
        float sceneA = darkRemain;
        outc = vec4(scene * sceneA, sceneA);
    } else {
        float vig = smoothstep(0.45, 1.6, r);
        float dimBase = (0.10 + 0.50 * vig) * g * alive;
        float voidAmt = max(0.93 * smoothstep(0.15, 1.0, c), 0.40 * op * smoothstep(0.1, 1.4, r));
        float dim = 1.0 - (1.0 - dimBase) * (1.0 - voidAmt);
        dim *= darkRemain;
        outc = vec4(bgColor.rgb * dim, dim);

        float crackVis = smoothstep(0.0, 0.05, g) * darkRemain * smoothstep(0.015, 0.10, r) * alive;
        float inside = 1.0 - smoothstep(reach * 0.9, reach, rq);
        float front = ringShape(rq, reach, 0.09) * (1.0 - smoothstep(0.7, 1.0, g));
        float edgeBand = ringShape(r, revR + 0.45 * REV_EDGE, 0.28) * revLive;
        float spark = step(0.55, hash(vec2(fh * 31.0 + tick * 0.11, fh2)));

        float lit = smoothstep(0.66, 0.74, fh);
        float darkF = 1.0 - smoothstep(0.14, 0.22, fh);
        vec3 facetCol = mix(glowColor.rgb, hot, fh2);
        float glint = step(0.965, hash(vec2(fh * 57.0 + tick * 0.37, fh2 * 13.0)));

        float shadow = (pow(halo, 3.2) * 0.30 * (1.0 - line) + darkF * 0.13 * inside) * crackVis;
        outc.rgb *= 1.0 - shadow;
        outc.a = outc.a + shadow * (1.0 - outc.a);

        float calm = 1.0 - 0.7 * revLive;
        light += facetCol * lit * (0.035 + 0.05 * fx) * crackVis * inside * calm;
        light += hot * glint * (lit + 0.3) * 0.16 * crackVis * inside * calm;
        light += glowColor.rgb * halo * 0.20 * crackVis * inside;
        light += lineCol * line * (0.70 + 1.4 * front + 1.0 * edgeBand + 2.2 * brk) * crackVis;
        light += glowColor.rgb * halo * 0.5 * brk * crackVis;
        light += lineCol * edgeBand * spark * 0.30;
        float sheen = 4.0 * fall * (1.0 - fall) * (0.5 + 0.5 * sin(6.0 * fh2 + 9.0 * fall));
        light += mix(glowColor.rgb, hot, 0.5) * sheen * 0.14 * alive * smoothstep(0.0, 0.05, g);
    }

    float flowVis = op * (1.0 - smoothstep(0.35, 0.95, c)) * (1.0 - pk);
    if (flowVis > 0.001) {
        float lr = log(r + 0.06);
        float N = 64.0;
        float u = ang01 * N - 5.0 * lr + time * 0.35;
        float v = lr * 4.0 + time * 1.3;
        float cu = floor(u);
        float cv = floor(v);
        float fu = fract(u) - 0.5;
        float fv = fract(v);
        float h = hash(vec2(cu, cv));
        float h2 = hash(vec2(cu * 1.7 + 3.1, cv * 2.3 + 5.7));
        float on = step(0.82, h);
        float w = mix(0.04, 0.12, h2);
        float aa = fwidth(u) + 0.02;
        float sline = 1.0 - smoothstep(w, w + aa, abs(fu));
        float along = smoothstep(0.0, 0.08, fv) * pow(1.0 - fv, 2.0);
        float radial = smoothstep(0.2, 0.45, r) * exp(-r * 0.9);
        float streak = on * sline * along * radial;
        light += mix(glowColor.rgb, hot, 0.6) * streak * 0.25 * flowVis * (1.0 - 0.6 * snapOn);
    }

    float openRing = ringShape(r, 0.15 + 2.4 * g, 0.03 + 0.08 * g) * pow(1.0 - g, 1.3);
    float impact = exp(-r * r * 40.0) * pow(1.0 - g, 3.0) * smoothstep(0.0, 0.03, g);
    light += mix(glowColor.rgb, hot, 0.4) * openRing * 0.9 * (1.0 - 0.5 * snapOn);
    light += mix(hot, vec3(1.0), 0.6) * impact * 0.9;

    float inR = mix(1.6, 0.3, pow(c, 1.3));
    float inI = sin(PI * c) * (1.0 - pk);
    light += glowColor.rgb * ringShape(r, inR, 0.025 + 0.05 * (1.0 - c)) * inI * 0.45;

    float flashCore = exp(-r * r * 18.0) * pow(1.0 - pk, 2.2) * popRamp;
    float flashGlow = exp(-r * 2.2) * pow(1.0 - pk, 3.0) * 0.6 * popRamp;
    light += mix(hot, vec3(1.0), 0.7) * (flashCore * 1.6 + flashGlow);

    float rs = 0.1 + 2.6 * (1.0 - pow(1.0 - pk, 2.0));
    float wid = 0.03 + 0.10 * pk;
    float sI = pow(1.0 - pk, 1.4) * popRamp;
    vec3 shock = vec3(ringShape(r, rs * 1.03, wid),
                      ringShape(r, rs, wid),
                      ringShape(r, rs * 0.97, wid)) * sI;
    light += shock * mix(glowColor.rgb, vec3(1.0), 0.35) * 0.9;

    float pk2 = clamp((pk - 0.12) / 0.88, 0.0, 1.0);
    float rs2 = 0.05 + 2.3 * (1.0 - pow(1.0 - pk2, 2.0));
    float sI2 = pow(1.0 - pk2, 1.6) * 0.4 * smoothstep(0.0, 0.05, pk2);
    light += glowColor.rgb * ringShape(r, rs2, 0.04 + 0.08 * pk2) * sI2;

    light += mix(glowColor.rgb, hot, 0.35) * ringShape(r, revR + 0.45 * REV_EDGE, 0.22) * revLive * 0.28;

    vec3 rgb = min(outc.rgb + light, vec3(1.0));
    float a = max(outc.a, max(rgb.r, max(rgb.g, rgb.b)) * 0.7);
    fragColor = vec4(rgb, min(a, 1.0)) * qt_Opacity;
}

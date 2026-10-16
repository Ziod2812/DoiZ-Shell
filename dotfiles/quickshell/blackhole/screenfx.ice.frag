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

const float QS = 6.0;
const float SPIN = 2.2;
const float BLUR = 0.009;
const float REFRACT = 0.0025;
const float HORIZON = 0.11;

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

vec2 hash2(vec2 p) {
    return vec2(hash(p), hash(p + vec2(17.13, 91.71)));
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

float vnp(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(vec2(mod(i.x, period), i.y));
    float b = hash(vec2(mod(i.x + 1.0, period), i.y));
    float c = hash(vec2(mod(i.x, period), i.y + 1.0));
    float d = hash(vec2(mod(i.x + 1.0, period), i.y + 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        s += a * vn(p);
        p = vec2(1.6 * p.x + 1.2 * p.y, -1.2 * p.x + 1.6 * p.y);
        a *= 0.5;
    }
    return s / 0.875;
}

float ringShape(float r, float radius, float width) {
    float d = (r - radius) / width;
    return exp(-d * d);
}

vec2 warpQ(vec2 q) {
    return q + 0.55 * (vec2(vn(q * 0.8 + vec2(3.1, 1.7)), vn(q * 0.8 + vec2(7.4, 9.2))) - 0.5);
}

vec2 toQ(vec2 x) {
    return warpQ(x * (QS * inversesqrt(max(length(x), 1e-4))));
}

vec2 fromQ(vec2 q) {
    float m = length(q);
    float k = m / QS;
    return q / max(m, 1e-4) * (k * k);
}

vec2 featPt(vec2 cc) {
    return cc + 0.5 + (hash2(cc) - 0.5) * 0.85;
}

vec2 cellOf(vec2 qw) {
    vec2 ic = floor(qw);
    float best = 1e9;
    vec2 bc = ic;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 cc = ic + vec2(float(i), float(j));
            vec2 d = qw - featPt(cc);
            float dd = dot(d, d);
            if (dd < best) {
                best = dd;
                bc = cc;
            }
        }
    }
    return bc;
}

float edgeDist(vec2 qw, vec2 cc) {
    vec2 fc = featPt(cc);
    float md = 8.0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            if (i != 0 || j != 0) {
                vec2 fn = featPt(cc + vec2(float(i), float(j)));
                vec2 dv = fn - fc;
                md = min(md, dot(0.5 * (fc + fn) - qw, dv) / max(length(dv), 1e-4));
            }
        }
    }
    return md;
}

float findShard(vec2 P, float T, out vec2 x, out vec2 cid, out float ft, out float scl, out float facing) {
    x = P;
    cid = cellOf(toQ(P));
    ft = 0.0;
    scl = 1.0;
    facing = 1.0;
    if (T <= 0.0005) {
        return 1.0;
    }

    float rP = length(P);
    float rho = rP;
    float spinE = 0.0;
    for (int k = 0; k < 3; k++) {
        float st = 0.52 * smoothstep(0.0, 2.1, rho) + 0.055;
        float f = clamp((T - st) / 0.34, 0.0, 1.0);
        float pl = f * f;
        spinE = SPIN * pl;
        rho = rP / max(1.0 - pl, 0.08);
    }
    vec2 x0 = rot(P, -spinE) / max(rP, 1e-4) * rho;
    vec2 ic0 = floor(toQ(x0));

    float found = 0.0;
    float bestFt = 2.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 cc = ic0 + vec2(float(i), float(j));
            vec2 c = fromQ(featPt(cc));
            float rc = length(c);
            vec2 hh = hash2(cc + 5.3);
            vec2 hk = hash2(cc + 11.9);
            float st = 0.52 * smoothstep(0.0, 2.1, rc) + 0.03 + 0.05 * hh.x;
            float dur = 0.30 + 0.06 * hh.y;
            float f = clamp((T - st) / dur, 0.0, 1.0);
            if (f < 0.999) {
                float pl = f * f;
                float tm = smoothstep(st - 0.16, st, T) * (1.0 - smoothstep(st, st + 0.05, T));
                vec2 tv = 0.006 * tm * vec2(sin(time * 53.0 + hh.x * 40.0), cos(time * 67.0 + hh.y * 40.0));
                float s = 1.0 - 0.96 * pow(f, 1.3);
                float tum = (hk.x - 0.5) * 6.0 * pl;
                float cph = cos(hk.y * 5.0 * pl);
                float sx = max(abs(cph), 0.18);
                vec2 y = rot(P - tv, -SPIN * pl) - c * (1.0 - pl);
                vec2 u = rot(y / max(s, 0.04), -tum);
                vec2 xi = c + vec2(u.x / sx, u.y);
                if (f < bestFt && all(equal(cellOf(toQ(xi)), cc))) {
                    bestFt = f;
                    found = 1.0;
                    x = xi;
                    cid = cc;
                    ft = f;
                    scl = s;
                    facing = cph;
                }
            }
        }
    }
    return found;
}

void frost(vec2 x, float reach, out float cov, out float fern, out float thick, out vec2 grad) {
    cov = 0.0;
    fern = 0.0;
    thick = 0.0;
    grad = vec2(0.0);
    float r = length(x);
    if (r > reach * 1.55 + 0.45) {
        return;
    }
    vec2 d = x / max(r, 1e-3);
    float ang = atan(x.y, x.x) / TAU + 0.5;
    vec2 w = x + 0.22 * (vec2(vn(x * 1.9 + 3.1), vn(x * 1.9 - 7.7)) - 0.5);

    float needle = pow(vn(d * 6.0 + vec2(4.7, 1.3)), 2.2);
    float needle2 = pow(vn(d * 17.0 + r * vec2(2.0, -1.5) + vec2(2.2, 8.1)), 2.6);
    float lump = vn(d * 2.0 + vec2(1.9, 6.2));
    float rf = reach * (0.45 + 0.25 * lump + 0.55 * needle + 0.25 * needle2);
    float h = fbm3(w * 5.0);
    float df = r - rf + 0.26 * (h - 0.5) + 0.10 * (vn(x * 15.0 + 2.0) - 0.5);
    cov = 1.0 - smoothstep(-0.18, 0.02, df);
    if (cov < 0.002) {
        return;
    }

    float hx = fbm3((w + vec2(0.01, 0.0)) * 5.0);
    float hy = fbm3((w + vec2(0.0, 0.01)) * 5.0);
    grad = vec2(hx - h, hy - h) / 0.01;

    float clearPatch = smoothstep(0.30, 0.65, fbm3(w * 1.8 + 9.0));
    thick = cov * (0.50 + 0.30 * clearPatch);

    float ridged = 1.0 - abs(2.0 * fbm3(w * 11.0 + 5.0) - 1.0);
    float veins = pow(ridged, 6.0);
    float spokes = pow(vnp(vec2(ang * 64.0 + 4.0 * h, r * 2.4 + 2.0 * h), 64.0), 5.0)
                   * smoothstep(0.12, 0.40, r);
    float nearFront = 1.0 - smoothstep(0.0, 0.8, -df);
    fern = (0.80 * veins + 0.90 * spokes) * (0.35 + 0.65 * nearFront) * cov;
}

vec3 frozenImage(vec2 x, float thick, float fern, vec2 grad, vec2 shiftP, float aspect,
                 vec3 ice, vec3 iceDeep, float cold) {
    vec2 invAsp = 1.0 / (vec2(aspect, 1.0) * 2.0);
    vec2 uv0 = (x + shiftP) * invAsp + 0.5 + grad * REFRACT * thick;
    vec3 sharp = texture(snap, uv0).rgb;
    float rad = BLUR * thick;
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float rr = sqrt((fi + 0.5) / 8.0);
        float aa = fi * 2.39996;
        vec2 o = vec2(cos(aa), sin(aa)) * rr * rad * vec2(1.0 / aspect, 1.0);
        acc += texture(snap, uv0 + o).rgb;
    }
    vec3 img = mix(sharp, acc / 8.0, smoothstep(0.05, 0.6, thick));
    img *= 1.0 - 0.22 * thick;
    img = mix(img, ice * 0.9, 0.30 * thick);
    img *= mix(vec3(1.0), vec3(0.84, 0.94, 1.06), cold * thick);
    img = mix(img, iceDeep, 0.10 * thick * thick);
    img += vec3(0.85, 0.95, 1.0) * fern * 0.38;

    vec3 n = normalize(vec3(-grad * 0.20, 1.0));
    vec3 l = normalize(vec3(-0.45, 0.55, 0.70));
    img *= 1.0 + 0.40 * (dot(n, l) - 0.85) * thick;
    float spec = pow(max(dot(n, normalize(l + vec3(0.0, 0.0, 1.0))), 0.0), 60.0);
    img += vec3(1.0) * spec * 0.30 * thick;
    return img;
}

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

    float corner = length(vec2(aspect, 1.0));
    float rv = clamp(reveal, 0.0, 1.0);
    float re = rv * rv * (3.0 - 2.0 * rv);
    const float REV_EDGE = 0.9;
    float revR = mix(-REV_EDGE, corner, re);
    float darkRemain = smoothstep(revR, revR + REV_EDGE, r);

    vec3 hot = mix(hotColor.rgb, vec3(1.0), 0.35);
    vec3 ice = mix(vec3(0.72, 0.89, 1.0), glowColor.rgb, 0.15);
    vec3 iceDeep = mix(vec3(0.22, 0.52, 0.86), glowColor.rgb, 0.20);
    vec3 iceWhite = vec3(0.93, 0.98, 1.0);

    float fz = clamp(g / 0.78, 0.0, 1.0);
    float reach = 3.4 * pow(fz, 0.85);
    float cold = smoothstep(0.45, 1.0, g);

    vec2 x;
    vec2 cid;
    float ft;
    float scl;
    float facing;
    float alive = findShard(p, sh, x, cid, ft, scl, facing);

    vec3 shardCol = vec3(0.0);
    float shardA = 0.0;

    if (alive > 0.5) {
        float rx = length(x);
        float cov;
        float fern;
        float thick;
        vec2 grad;
        frost(x, reach, cov, fern, thick, grad);

        vec2 qw = toQ(x);
        float md = edgeDist(qw, cid);
        float lq = 4.5 * inversesqrt(max(rx, 0.04));
        float edgePx = md * scl / (ps * lq);
        float crackR = mix(-0.2, corner * 1.5, smoothstep(0.50, 1.0, g));
        float crackVis = max(1.0 - smoothstep(crackR - 0.25, crackR, rx), step(0.001, sh));
        float brk = smoothstep(0.0, 0.02, sh) * (1.0 - smoothstep(0.02, 0.28, sh));
        float crackL = (1.0 - smoothstep(0.35, 1.5, edgePx)) * crackVis;
        float bevel = exp(-edgePx / 5.0) * crackVis;

        float fh = hash(cid + 0.7);
        float fh2 = hash(cid + 9.1);
        float depth = smoothstep(0.08, 1.0, ft);
        float fade = 1.0 - smoothstep(0.1, 0.9, ft);

        if (snapOn > 0.5) {
            vec2 shiftP = (vec2(fh, fh2) - 0.5) * 0.008 * crackVis;
            vec3 shard = frozenImage(x, thick, fern, grad, shiftP, aspect, ice, iceDeep, cold);

            float gv = smoothstep(0.5, 0.9, g);
            shard *= 1.0 + (fh2 - 0.5) * 0.30 * gv;
            shard *= 1.0 - 0.20 * bevel * (1.0 - crackL);
            shard += mix(iceDeep, ice, 0.5) * exp(-edgePx / 3.0) * (0.10 + 0.35 * step(0.001, sh)) * crackVis;
            shard = mix(shard, iceWhite, crackL * (0.50 + 0.45 * brk) * 0.9);

            float flip = 1.0 - smoothstep(-0.1, 0.1, facing);
            shard = mix(shard, iceDeep * 0.55 + shard * 0.2, flip * 0.65);
            float sheen = 4.0 * ft * (1.0 - ft) * (0.5 + 0.5 * sin(6.0 * fh2 + 9.0 * ft));
            shard += mix(ice, vec3(1.0), 0.5) * sheen * 0.25;
            shard *= 1.0 - 0.75 * depth;

            float glit = step(0.9965, hash(floor(qt_TexCoord0 * resolution / 2.5) + floor(time * 6.0) * 7.13));
            shard += vec3(1.0) * glit * thick * (1.0 - depth);

            shardCol = shard;
            shardA = 1.0;
        } else {
            vec3 fc = ice * thick * 0.50
                    + iceWhite * (fern * 0.40 + crackL * 0.85)
                    + mix(iceDeep, ice, 0.5) * bevel * 0.06;
            shardCol = fc * fade;
            shardA = clamp(thick * 0.50 + fern * 0.35 + crackL * 0.80 + bevel * 0.06, 0.0, 1.0) * fade;
        }
    }

    vec4 outc;
    if (snapOn > 0.5) {
        float swallowed = mix(1.0, smoothstep(HORIZON * 0.5, HORIZON * 1.4, r), smoothstep(0.0, 0.08, sh));
        float cover = alive * swallowed;
        vec3 voidCol = wormhole(p, r, smoothstep(0.0, 0.25, sh), hot, glowColor.rgb);
        vec3 scene = mix(voidCol, shardCol, cover);
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
        float la = shardA * darkRemain;
        outc.rgb = shardCol * darkRemain + outc.rgb * (1.0 - la);
        outc.a = la + outc.a * (1.0 - la);
    }

    vec3 light = vec3(0.0);

    float flowVis = smoothstep(0.02, 0.15, sh) * (1.0 - smoothstep(0.35, 0.95, c)) * (1.0 - pk);
    if (flowVis > 0.001) {
        float lr = log(r + 0.06);
        float N = 64.0;
        float u = ang01 * N - 5.0 * lr + time * 0.35;
        float v = lr * 4.0 + time * 1.3;
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
        float along = smoothstep(0.0, 0.08, fv) * pow(1.0 - fv, 2.0);
        float radial = smoothstep(0.2, 0.45, r) * exp(-r * 0.9);
        float intoHole = smoothstep(HORIZON * 1.1, HORIZON * 2.6, r);
        float streak = on * sline * along * radial * intoHole;
        light += mix(ice, vec3(1.0), 0.5) * streak * 0.85 * flowVis;
    }

    float impact = exp(-r * r * 40.0) * pow(1.0 - g, 3.0) * smoothstep(0.0, 0.03, g);
    light += mix(ice, vec3(1.0), 0.55) * impact * 0.9;
    float frontRing = ringShape(r, reach * 0.62, 0.05 + 0.05 * fz) * (1.0 - smoothstep(0.55, 0.95, fz)) * smoothstep(0.0, 0.03, g);
    light += mix(iceDeep, ice, 0.6) * frontRing * 0.18;

    float inR = mix(1.6, 0.3, pow(c, 1.3));
    float inI = sin(PI * c) * (1.0 - pk);
    light += mix(iceDeep, ice, 0.5) * ringShape(r, inR, 0.025 + 0.05 * (1.0 - c)) * inI * 0.45;

    float flashCore = exp(-r * r * 18.0) * pow(1.0 - pk, 2.2) * popRamp;
    float flashGlow = exp(-r * 2.2) * pow(1.0 - pk, 3.0) * 0.6 * popRamp;
    light += mix(ice, vec3(1.0), 0.7) * (flashCore * 1.6 + flashGlow);

    float rs = 0.1 + 2.6 * (1.0 - pow(1.0 - pk, 2.0));
    float wid = 0.03 + 0.10 * pk;
    float sI = pow(1.0 - pk, 1.4) * popRamp;
    vec3 shock = vec3(ringShape(r, rs * 1.03, wid),
                      ringShape(r, rs, wid),
                      ringShape(r, rs * 0.97, wid)) * sI;
    light += shock * mix(ice, vec3(1.0), 0.35) * 0.9;

    float pk2 = clamp((pk - 0.12) / 0.88, 0.0, 1.0);
    float rs2 = 0.05 + 2.3 * (1.0 - pow(1.0 - pk2, 2.0));
    float sI2 = pow(1.0 - pk2, 1.6) * 0.4 * smoothstep(0.0, 0.05, pk2);
    light += ice * ringShape(r, rs2, 0.04 + 0.08 * pk2) * sI2;

    float edgeBand = ringShape(r, revR + 0.45 * REV_EDGE, 0.28) * revLive;
    float spark = step(0.55, hash(floor(qt_TexCoord0 * resolution / 3.0) + floor(time * 9.0) * 3.7));
    light += mix(ice, hot, 0.2) * ringShape(r, revR + 0.45 * REV_EDGE, 0.22) * revLive * 0.28;
    light += iceWhite * edgeBand * spark * 0.30;

    vec3 rgb = min(outc.rgb + light, vec3(1.0));
    float a = max(outc.a, max(rgb.r, max(rgb.g, rgb.b)) * 0.7);
    fragColor = vec4(rgb, min(a, 1.0)) * qt_Opacity;
}

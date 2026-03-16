// =============================================================
//  COMBINED GHOSTTY SHADER — 90s Retro Vibes
//  Effects: Cursor Trail | CRT | Chromatic Aberration | Bloom
//  Every effect has adjustable parameters below.
// =============================================================

// ─── CURSOR TRAIL PARAMETERS ─────────────────────────────────
// Main trail color (R, G, B, A)
const vec4 TRAIL_COLOR         = vec4(0.6, 0.85, 1.0, 1.0);
// Accent color at trail tip
const vec4 TRAIL_COLOR_ACCENT  = vec4(0.9, 0.4, 1.0, 1.0);
// Duration of the trail fade (seconds)
const float TRAIL_DURATION     = 0.45;
// Minimum cursor distance (in cursor-widths) before trail draws
const float TRAIL_THRESHOLD    = 0.5;
// Overall trail opacity [0.0 = invisible, 1.0 = full]
const float TRAIL_OPACITY      = 0.8;
// Hide trails for same-line jumps?
const bool  TRAIL_HIDE_SAME_LINE = false;

// ─── CRT PARAMETERS ─────────────────────────────────────────
// Screen curvature strength [0.0 = flat, 1.0 = heavy warp]
const float CRT_WARP           = 0.04;
// Scanline darkness [0.0 = none, 1.0 = very dark lines]
const float CRT_SCANLINE       = 0.12;
// Scanline period in pixels
const float CRT_SCANLINE_PERIOD = 3.0;
// Vignette strength [0.0 = none, 1.0 = full black corners]
const float CRT_VIGNETTE       = 0.15;
// Flicker strength [0.0 = none]
const float CRT_FLICKER        = 0.015;
// Flicker speed (Hz)
const float CRT_FLICKER_FREQ   = 15.0;

// ─── CHROMATIC ABERRATION PARAMETERS ─────────────────────────
// Base pixel offset for R/B channels [0.0 = none]
const float CA_STRENGTH        = 1.0;
// Animated wobble amount [0.0 = static offset]
const float CA_WOBBLE          = 0.3;
// Wobble speed multiplier
const float CA_WOBBLE_SPEED    = 1.0;

// ─── BLOOM / GLOW PARAMETERS ────────────────────────────────
// Bloom sample radius multiplier [0.0 = none]
const float BLOOM_RADIUS       = 0.1;
// Bloom intensity [0.0 = none, 0.3 = heavy]
const float BLOOM_INTENSITY    = 0.01;
// Luminance threshold — only pixels brighter than this glow
const float BLOOM_THRESHOLD    = 0.18;


// =============================================================
//  INTERNAL — you normally don't need to touch below here
// =============================================================

// ─── Golden-spiral bloom samples (from qwerasd205) ──────────
const vec3 bloomSamples[24] = vec3[24](
    vec3( 0.169376,  0.985551, 1.000000),
    vec3(-1.333071,  0.472146, 0.707107),
    vec3(-0.846439, -1.511139, 0.577350),
    vec3( 1.554156, -1.258809, 0.500000),
    vec3( 1.681364,  1.474115, 0.447214),
    vec3(-1.279516,  2.088741, 0.408248),
    vec3(-2.457585, -0.979937, 0.377964),
    vec3( 0.587464, -2.766746, 0.353553),
    vec3( 2.997716,  0.117049, 0.333333),
    vec3( 0.413608,  3.135112, 0.316228),
    vec3(-3.167150,  0.984460, 0.301511),
    vec3(-1.573671, -3.086026, 0.288675),
    vec3( 2.888203, -2.158306, 0.277350),
    vec3( 2.715078,  2.574559, 0.267261),
    vec3(-2.150407,  3.221141, 0.258199),
    vec3(-3.654886, -1.625364, 0.250000),
    vec3( 1.013078, -3.996708, 0.242536),
    vec3( 4.229724,  0.330814, 0.235702),
    vec3( 0.401078,  4.340407, 0.229416),
    vec3(-4.319125,  1.159812, 0.223607),
    vec3(-1.920904, -4.160544, 0.218218),
    vec3( 3.863912, -2.658981, 0.213201),
    vec3( 3.348623,  3.433180, 0.208514),
    vec3(-2.876973,  3.965227, 0.204124)
);

// ─── CURSOR TRAIL HELPERS ────────────────────────────────────

float trailEase(float x) {
    return pow(1.0 - x, 10.0);
}

float trailBlend(float t) {
    float sqr = t * t;
    return sqr / (2.0 * (sqr - t) + 1.0);
}

vec2 trailNorm(vec2 value, float isPos) {
    return (value * 2.0 - (iResolution.xy * isPos)) / iResolution.y;
}

float trailAA(float d) {
    return 1.0 - smoothstep(0.0, trailNorm(vec2(2.0), 0.0).x, d);
}

float sdfBox(vec2 p, vec2 xy, vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float trailSeg(vec2 p, vec2 a, vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);
    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allC = c0 * c1 * c2;
    float noneC = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    s *= mix(1.0, -1.0, step(0.5, allC + noneC));
    return d;
}

float sdfPara(vec2 p, vec2 v0, vec2 v1, vec2 v2, vec2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);
    d = trailSeg(p, v0, v3, s, d);
    d = trailSeg(p, v1, v0, s, d);
    d = trailSeg(p, v2, v1, s, d);
    d = trailSeg(p, v3, v2, s, d);
    return s * sqrt(d);
}

float trailVertexFactor(vec2 a, vec2 b) {
    float c1 = step(b.x, a.x) * step(a.y, b.y);
    float c2 = step(a.x, b.x) * step(b.y, a.y);
    return 1.0 - max(c1, c2);
}

vec2 rectCenter(vec4 r) {
    return vec2(r.x + r.z * 0.5, r.y - r.w * 0.5);
}


// ─── CRT HELPERS ─────────────────────────────────────────────

vec2 applyCRTWarp(vec2 uv) {
    vec2 off = uv - 0.5;
    float r2 = dot(off, off);
    uv += off * r2 * CRT_WARP;
    return uv;
}

float calcVignette(vec2 uv) {
    vec2 off = uv - 0.5;
    float dist = dot(off, off);  // 0 at center, ~0.5 at corners
    return 1.0 - CRT_VIGNETTE * smoothstep(0.0, 0.5, dist);
}


// ─── MAIN ────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // ── 1. CRT warp ──────────────────────────────────────────
    vec2 warpedUV = applyCRTWarp(uv);

    // ── 2. Chromatic aberration ──────────────────────────────
    // Subtle animated wobble
    float wobble = 1.0 + CA_WOBBLE * (sin(iTime * 3.7 * CA_WOBBLE_SPEED)
                       * sin(iTime * 6.1 * CA_WOBBLE_SPEED)
                       * sin(iTime * 8.9 * CA_WOBBLE_SPEED));
    float caOff = CA_STRENGTH * wobble / iResolution.x;

    vec3 col;
    col.r = texture(iChannel0, vec2(warpedUV.x - caOff, warpedUV.y)).r;
    col.g = texture(iChannel0, warpedUV).g;
    col.b = texture(iChannel0, vec2(warpedUV.x + caOff, warpedUV.y)).b;
    float alpha = texture(iChannel0, warpedUV).a;

    fragColor = vec4(col, alpha);

    // ── 3. Bloom / Glow ──────────────────────────────────────
    if (BLOOM_INTENSITY > 0.0) {
        vec2 step = BLOOM_RADIUS * vec2(1.414) / iResolution.xy;
        vec3 bloom = vec3(0.0);
        for (int i = 0; i < 24; i++) {
            vec3 s = bloomSamples[i];
            vec4 c = texture(iChannel0, warpedUV + s.xy * step);
            float lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
            if (lum > BLOOM_THRESHOLD) {
                bloom += lum * s.z * c.rgb;
            }
        }
        fragColor.rgb += bloom * BLOOM_INTENSITY;
    }

    // ── 4. CRT scanlines ────────────────────────────────────
    float scanline = 0.5 * (1.0 + sin(2.0 * 3.14159265 * fragCoord.y / CRT_SCANLINE_PERIOD));
    fragColor.rgb *= mix(1.0, scanline, CRT_SCANLINE);

    // ── 5. CRT vignette ──────────────────────────────────────
    if (CRT_VIGNETTE > 0.0) {
        fragColor.rgb *= calcVignette(warpedUV);
    }

    // ── 6. CRT flicker ──────────────────────────────────────
    if (CRT_FLICKER > 0.0) {
        fragColor.rgb *= 1.0 - CRT_FLICKER * 0.5 * (1.0 + sin(2.0 * 3.14159265 * CRT_FLICKER_FREQ * iTime));
    }

    // ── 7. Cursor trail ──────────────────────────────────────
    vec2 vu = trailNorm(fragCoord, 1.0);

    vec4 curCur = vec4(trailNorm(iCurrentCursor.xy, 1.0),  trailNorm(iCurrentCursor.zw, 0.0));
    vec4 preCur = vec4(trailNorm(iPreviousCursor.xy, 1.0), trailNorm(iPreviousCursor.zw, 0.0));

    float vf  = trailVertexFactor(curCur.xy, preCur.xy);
    float ivf = 1.0 - vf;

    vec2 v0 = vec2(curCur.x + curCur.z * vf,  curCur.y - curCur.w);
    vec2 v1 = vec2(curCur.x + curCur.z * ivf, curCur.y);
    vec2 v2 = vec2(preCur.x + curCur.z * ivf, preCur.y);
    vec2 v3 = vec2(preCur.x + curCur.z * vf,  preCur.y - preCur.w);

    float progress = trailBlend(clamp((iTime - iTimeCursorChange) / TRAIL_DURATION, 0.0, 1.0));
    float easedProg = trailEase(progress);

    vec2 cCC = rectCenter(curCur);
    vec2 cCP = rectCenter(preCur);
    float cursorSize = max(curCur.z, curCur.w);
    float lineLen = distance(cCC, cCP);

    bool farEnough = lineLen > TRAIL_THRESHOLD * cursorSize;
    bool separateLine = TRAIL_HIDE_SAME_LINE ? curCur.y != preCur.y : true;

    if (farEnough && separateLine) {
        float distToEnd = distance(vu.xy, cCC);
        float alphaMod = min(distToEnd / (lineLen * easedProg + 0.0001), 1.0);

        float sdfCur   = sdfBox(vu, curCur.xy - curCur.zw * vec2(-0.5, 0.5), curCur.zw * 0.5);
        float sdfTrail = sdfPara(vu, v0, v1, v2, v3);

        vec4 newColor = fragColor;
        newColor = mix(newColor, TRAIL_COLOR_ACCENT, 1.0 - smoothstep(sdfTrail, -0.01, 0.001));
        newColor = mix(newColor, TRAIL_COLOR, trailAA(sdfTrail));
        newColor = mix(fragColor, newColor, (1.0 - alphaMod) * TRAIL_OPACITY);
        fragColor = mix(newColor, fragColor, step(sdfCur, 0.0));
    }

    // ── 8. Clamp output ──────────────────────────────────────
    fragColor = clamp(fragColor, 0.0, 1.0);
}

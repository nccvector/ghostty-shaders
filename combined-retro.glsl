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
const float CRT_WARP           = 0.05;
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

// ─── CURSOR CROSS PARAMETERS ─────────────────────────────────
// Core line opacity [0.0 = invisible, 1.0 = solid]
const float CROSS_OPACITY      = 0.15;
// Chromatic aberration offset for the cross (pixels) — THE HOLY SPLIT
const float CROSS_CA_STRENGTH  = 4.0;
// Inner glow color — the divine light
const vec3  CROSS_COLOR        = vec3(0.5, 0.8, 1.0);
// Outer glow color — heavenly halo
const vec3  CROSS_GLOW_COLOR   = vec3(0.4, 0.6, 1.0);
// Glow spread in pixels — how far the divine light reaches
const float CROSS_GLOW_SIZE    = 5.0;
// Glow intensity [0.0 = none, 1.0 = blinding]
const float CROSS_GLOW_INTENSITY = 0.1;
// Fade out cross with distance from cursor [0.0 = infinite reach, higher = fades sooner]
const float CROSS_FADE         = 0.0008;
// Pulse speed [0.0 = static, higher = faster breathing]
const float CROSS_PULSE_SPEED  = 0.5;
// Pulse amount [0.0 = no pulse, 1.0 = full throb]
const float CROSS_PULSE_AMOUNT = 0.05;
// Gap near cursor [0.0 = no gap]
const float CROSS_GAP          = 0.0;

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

    // ── 8. HOLY CURSOR CROSS ─────────────────────────────────────
    if (CROSS_OPACITY > 0.0) {
        vec2 cursorPos = iCurrentCursor.xy;
        vec2 cursorSize = iCurrentCursor.zw;
        vec2 cursorCenter = cursorPos + cursorSize * vec2(0.5, -0.5);

        // Distance from cursor's row/column center
        float distToRow = abs(fragCoord.y - cursorCenter.y);
        float distToCol = abs(fragCoord.x - cursorCenter.x);

        // Hard core: matches cursor block dimensions
        float coreH = step(distToRow, cursorSize.y * 0.5);
        float coreV = step(distToCol, cursorSize.x * 0.5);

        // Soft glow: exponential falloff from the core edges
        float glowH = exp(-pow(max(distToRow - cursorSize.y * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));
        float glowV = exp(-pow(max(distToCol - cursorSize.x * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));

        // Combine: glow includes core
        float hLine = max(coreH, glowH);
        float vLine = max(coreV, glowV);

        // Divine pulse — breathing light
        float pulse = 1.0 + CROSS_PULSE_AMOUNT * sin(iTime * CROSS_PULSE_SPEED * 3.14159265);

        // Fade with distance from cursor center (light emanates from the source)
        if (CROSS_FADE > 0.0) {
            float fadeH = exp(-CROSS_FADE * distToCol * distToCol);
            float fadeV = exp(-CROSS_FADE * distToRow * distToRow);
            hLine *= fadeH;
            vLine *= fadeV;
        }

        // Gap near cursor
        if (CROSS_GAP > 0.0) {
            hLine *= smoothstep(0.0, CROSS_GAP * cursorSize.x, distToCol);
            vLine *= smoothstep(0.0, CROSS_GAP * cursorSize.y, distToRow);
        }

        float crossMask = max(hLine, vLine);

        // HOLY chromatic aberration — the cross LINES THEMSELVES split into R/G/B
        float caPixels = CROSS_CA_STRENGTH * pulse;
        float caPixelsY = caPixels * 0.5;

        // Compute offset cross masks: shift the fragCoord for R and B channels
        // R channel: cross shifted left and up
        float distToRowR = abs((fragCoord.y + caPixelsY) - cursorCenter.y);
        float distToColR = abs((fragCoord.x + caPixels) - cursorCenter.x);
        float coreHR = step(distToRowR, cursorSize.y * 0.5);
        float coreVR = step(distToColR, cursorSize.x * 0.5);
        float glowHR = exp(-pow(max(distToRowR - cursorSize.y * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));
        float glowVR = exp(-pow(max(distToColR - cursorSize.x * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));
        float maskR = max(max(coreHR, glowHR), max(coreVR, glowVR));

        // G channel: cross at center (use existing values)
        float maskG = crossMask;

        // B channel: cross shifted right and down
        float distToRowB = abs((fragCoord.y - caPixelsY) - cursorCenter.y);
        float distToColB = abs((fragCoord.x - caPixels) - cursorCenter.x);
        float coreHB = step(distToRowB, cursorSize.y * 0.5);
        float coreVB = step(distToColB, cursorSize.x * 0.5);
        float glowHB = exp(-pow(max(distToRowB - cursorSize.y * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));
        float glowVB = exp(-pow(max(distToColB - cursorSize.x * 0.5, 0.0), 2.0) / (CROSS_GLOW_SIZE * CROSS_GLOW_SIZE));
        float maskB = max(max(coreHB, glowHB), max(coreVB, glowVB));

        // Apply fade to each channel's mask
        if (CROSS_FADE > 0.0) {
            maskR *= max(exp(-CROSS_FADE * distToColR * distToColR), exp(-CROSS_FADE * distToRowR * distToRowR));
            maskB *= max(exp(-CROSS_FADE * distToColB * distToColB), exp(-CROSS_FADE * distToRowB * distToRowB));
        }

        // Composite: white center line + red/blue fringes on the sides
        float intensity = CROSS_OPACITY * pulse;
        // Center line — bright white
        fragColor.rgb = mix(fragColor.rgb, vec3(1.0) * pulse, maskG * intensity);
        // Red fringe on one side, blue fringe on the other (desaturated)
        fragColor.r += maskR * intensity * 0.4;
        fragColor.b += maskB * intensity * 0.4;
    }

    // ── 9. Clamp output ──────────────────────────────────────
    fragColor = clamp(fragColor, 0.0, 1.0);
}

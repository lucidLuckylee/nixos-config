#!/usr/bin/env python3
"""Emit graph5.gen.txt — the whole filtergraph for one 288s weather cycle.

Hand-editing this stopped being viable at ~40 timed overlays. It is generated
now, so the timeline is a table at the top of the file rather than something to
be reconstructed from filter labels.

Why 288s: the rain plates wrap over a 1200px vertical tile and a 512px
horizontal one, and the steam loops every 6s. A layer scrolling at v px/s only
returns to its start when v*T is a whole number of tiles, which for the whole
set means T must be a multiple of 48. 288 is six of those — long enough for a
weather cycle, short enough to render.

The seam sits inside steady rain, where every layer is mid-scroll and periodic,
so t=288 matches t=0 exactly.

Rain intensity is not a dial. Each plate is a depth layer with its own streak
width, density and speed, and "heavier" means more layers are up at once:

    sprinkle   sprinkle plate only
    rain       far + mid + near
    heavy      far + mid + near + heavy, plus lightning
    fog        none; fog plate and condensation instead

Every overlay carries BOTH a fade (smooth alpha) and an enable (so ffmpeg skips
the filter entirely outside its window, instead of compositing a transparent
frame 17280 times).
"""
T = 288.0

# --- inputs -----------------------------------------------------------------
I = {name: i for i, name in enumerate([
    'plate', 'mask_cyan', 'mask_amber', 'glow', 'blob1', 'blob2', 'mask_port',
    'rain_far', 'rain_mid', 'rain_near', 'rain_sprinkle', 'rain_heavy',
    'mask_screen', 'bar', 'steam', 'drops_x', 'drops_y', 'drops_spec',
    'drip', 'drip_front', 'fog', 'flash', 'led_cyan', 'led_red', 'led_green',
])}

# --- weather timeline -------------------------------------------------------
# (name, base x, vy px/s, vx px/s, [(in_start, in_dur, out_start, out_dur), ...])
# vy must be a multiple of 1200/288 and vx of 512/288, or the layer will not
# wrap; vx/vy is held at 0.2133 so the drift matches the 12-degree streak tilt.
RAIN = [
    ('rain_far',      262,  50,  10.66667, [(250, 14, 196, 16)]),
    ('rain_mid',      254, 100,  21.33333, [(262, 12, 164, 14)]),
    ('rain_near',     248, 200,  42.66667, [(268, 10, 146, 14)]),
    ('rain_sprinkle', 258,  25,   5.33333, [(160, 12, 206, 16), (238, 14, 276, 10)]),
    ('rain_heavy',    244, 250,  53.33333, [(84, 9, 128, 10)]),
]
# A pulse that wraps the loop is written as (in, in_dur, out, out_dur) with
# out < in: it is on from `in` to T and again from 0 to `out`.

FOG = (198, 18, 268, 16)          # fade in, hold through the quiet, fade out
FOG_VY = 2.0833                   # 600px tile over the loop: one slow drift

LIGHTNING = [92.0, 101.4, 108.2, 119.0, 128.3]

# Condensation on the glass: arrives late in the rain and lingers through fog.
CONDENSATION = (140, 20, 258, 14)

# --- washing machine --------------------------------------------------------
# Short cleaning bursts roughly once a minute; the indicator says what it is
# doing. Green blinking at the end of the cycle = finished.
BURSTS = [(55, 10), (130, 10), (205, 10)]
FINISHED = (250, 288)
DRUM_TURNS = 48                   # whole turns over the loop, so it is seamless

L = []
add = L.append


def fades(pulse):
    """One pulse -> a list of (fade filters, enable window).

    A pulse written with out < in wraps the loop: the layer is up across the
    seam. `fade` cannot express that in one chain — it would need alpha to rise
    again after falling — so it becomes two segments, one running to T with only
    a fade-in and one starting at 0 already at full alpha with only a fade-out.
    Written as one chain it produced an empty enable window and the layer simply
    never drew.
    """
    i0, di, o0, do = pulse
    if o0 > i0:
        return [(f"fade=t=in:st={i0}:d={di}:alpha=1,"
                 f"fade=t=out:st={o0}:d={do}:alpha=1",
                 f"between(t,{i0},{o0 + do})")]
    return [(f"fade=t=in:st={i0}:d={di}:alpha=1", f"gte(t,{i0})"),
            (f"fade=t=out:st={o0}:d={do}:alpha=1", f"lte(t,{o0 + do})")]


# --- plate, lamp breathing --------------------------------------------------
add(f"[{I['plate']}:v]format=gbrp,split=3[bg][c1][a1];")
add("[c1]eq=brightness='0.045*sin(2*PI*t/8)+0.02*sin(2*PI*t/3)':eval=frame[c2];")
add("[a1]eq=brightness='0.028*sin(2*PI*t/12)':eval=frame[a2];")
add(f"[{I['mask_cyan']}:v]format=gbrp[mc];[{I['mask_amber']}:v]format=gbrp[ma];")
add("[bg][c2][mc]maskedmerge[s1];[s1][a2][ma]maskedmerge[s2];")
add(f"[{I['mask_port']}:v]format=gbrp,split=2[mp1][mp2];")
add("[s2]format=rgba[base];")

# --- washing machine: glow, drum, indicator --------------------------------
ang = f"2*PI*{DRUM_TURNS}*t/{T}"
add(f"[{I['glow']}:v]format=rgba[glow];")
add(f"[{I['blob1']}:v]format=rgba[bl1];")
add(f"[{I['blob2']}:v]format=rgba[bl2];")
add("[base][glow]overlay=x=1665:y=890[o1];")
add(f"[o1][bl1]overlay=x='1692+17*cos({ang})':y='917+17*sin({ang})'[o2];")
add(f"[o2][bl2]overlay=x='1695+20*cos(PI+{ang})':y='920+20*sin(PI+{ang})'[o3];")

busy = "+".join(f"between(t,{s},{s + d})" for s, d in BURSTS)
add(f"[{I['led_cyan']}:v]format=rgba[ldc];")
add(f"[{I['led_red']}:v]format=rgba[ldr];")
add(f"[{I['led_green']}:v]format=rgba[ldg];")
add(f"[o3][ldc]overlay=x=1786:y=902:enable='lt({busy}+between(t,{FINISHED[0]},{FINISHED[1]}),0.5)'[o4];")
add(f"[o4][ldr]overlay=x=1786:y=902:enable='gt({busy},0.5)'[o5];")
add(f"[o5][ldg]overlay=x=1786:y=902:"
    f"enable='between(t,{FINISHED[0]},{FINISHED[1]})*lt(mod(t,1.6),0.8)'[o6];")
add("[o6]format=rgba,split=2[keepA][rainbase];")

# --- rain, fog, lightning: all masked to the porthole ----------------------
prev, n = 'rainbase', 0
for name, bx, vy, vx, pulses in RAIN:
    copies = []
    for pulse in pulses:
        for f, en in fades(pulse):
            copies.append((len(copies), f, en))
    add(f"[{I[name]}:v]format=rgba,split={len(copies)}["
        + "][".join(f"{name}_p{p}" for p, _, _ in copies) + "];")
    for p, f, en in copies:
        add(f"[{name}_p{p}]{f},split=4["
            + "][".join(f"{name}_{p}_{k}" for k in range(4)) + "];")
        # The second copy sits one tile lower; its offset is the empty string,
        # not '0' — appending '0' to mod(...) silently produced mod(...)0.
        for k, (ox, oy) in enumerate([(bx, '-1200'), (bx, ''),
                                      (bx + 512, '-1200'), (bx + 512, '')]):
            n += 1
            lbl = f"rn{n}"
            add(f"[{prev}][{name}_{p}_{k}]overlay="
                f"x='{ox}-mod({vx}*t,512)':y='mod({vy}*t,1200){oy}'"
                f":enable='{en}'[{lbl}];")
            prev = lbl

(f, en), = fades(FOG)
add(f"[{I['fog']}:v]format=rgba,{f},split=2[fg0][fg1];")
for k, oy in enumerate(('-600', '')):
    n += 1
    add(f"[{prev}][fg{k}]overlay=x=250:y='mod({FOG_VY}*t,600){oy}'"
        f":enable='{en}'[rn{n}];")
    prev = f"rn{n}"

add(f"[{I['flash']}:v]format=rgba,split={len(LIGHTNING)}["
    + "][".join(f"fl{i}" for i in range(len(LIGHTNING))) + "];")
for i, ft in enumerate(LIGHTNING):
    n += 1
    add(f"[fl{i}]fade=t=in:st={ft}:d=0.06:alpha=1,"
        f"fade=t=out:st={ft + 0.10}:d=0.55:alpha=1[flf{i}];")
    add(f"[{prev}][flf{i}]overlay=x=0:y=0:"
        f"enable='between(t,{ft},{ft + 0.7})'[rn{n}];")
    prev = f"rn{n}"

add(f"[keepA]format=gbrp[kA];[{prev}]format=gbrp[rD];")
add("[kA][rD][mp1]maskedmerge[r1];")

# --- condensation on the glass ---------------------------------------------
(f, en), = fades(CONDENSATION)
add("[r1]split=3[keepC][dpA][dpB];")
add(f"[{I['drops_x']}:v]format=gbrp[dmx];")
add(f"[{I['drops_y']}:v]format=gbrp[dmy];")
add("[dpB][dmx][dmy]displace=edge=smear[dsp0];")
add(f"[dsp0]format=rgba,{f}[dspa];")
add("[dpA]format=rgba[dpAr];")
add(f"[dpAr][dspa]overlay=x=0:y=0:enable='{en}'[dmix];")
add(f"[{I['drops_spec']}:v]format=rgba,{f}[spec];")
add(f"[dmix][spec]overlay=x=0:y=0:enable='{en}'[dropped0];")
add("[dropped0]format=gbrp[droppedD];")
add("[keepC][droppedD][mp2]maskedmerge[r2];")

# --- the screen -------------------------------------------------------------
add("[r2]format=rgba,split=2[keepB][wav];")
add(f"[{I['bar']}:v]format=rgba,split=7[q1][q2][q3][q4][q5][q6][q7];")
prev = 'wav'
for i, (x, k, ph) in enumerate([(1152, 5, 0.0), (1166, 7, 0.9), (1180, 11, 1.8),
                                (1194, 13, 2.7), (1208, 17, 3.6), (1222, 19, 4.5),
                                (1236, 23, 5.4)]):
    lbl = f"w{i + 1}"
    add(f"[{prev}][q{i + 1}]overlay=x={x}:"
        f"y='640-(4+38*(0.5+0.5*sin(2*PI*{k}*t/24+{ph})))'[{lbl}];")
    prev = lbl
add("[keepB]format=gbrp[kB];")
add(f"[{prev}]format=gbrp[wD];[{I['mask_screen']}:v]format=gbrp[ms];")
add("[kB][wD][ms]maskedmerge[fin];")

# --- steam: constant vent, plus washing-machine bursts ---------------------
add(f"[{I['steam']}:v]format=gbrp,split={len(BURSTS) + 1}[sB0]["
    + "][".join(f"sA{i}" for i in range(len(BURSTS))) + "];")
add("[sB0]scale=110:170,pad=1920:1080:920:390:color=black[stB];")
add("[fin][stB]blend=all_mode=screen[sm0];")
prev = 'sm0'
for i, (s, d) in enumerate(BURSTS):
    # Screen-blending treats black as identity, so a burst is faded by scaling
    # the plume's own brightness rather than by an alpha channel.
    add(f"[sA{i}]scale=88:136,"
        f"eq=contrast='min(clip((t-{s})/2.0,0,1),clip(({s + d}-t)/2.5,0,1))':eval=frame,"
        f"pad=1920:1080:1580:760:color=black[stA{i}];")
    add(f"[{prev}][stA{i}]blend=all_mode=screen:"
        f"enable='between(t,{s},{s + d})'[sm{i + 1}];")
    prev = f"sm{i + 1}"

# --- the drip ---------------------------------------------------------------
add(f"[{I['drip']}:v]format=rgba[drip];")
add(f"[{prev}][drip]overlay=x=928:y=340[drp];")
add(f"[{I['drip_front']}:v]format=rgba[dfront];")
add("[drp][dfront]overlay=x=928:y=340[drf];")
add("[drf]format=yuv420p[out]")

open('graph5.gen.txt', 'w').write("\n".join(L) + "\n")
print(f"{len(L)} filter lines, {n} rain/fog/flash overlays, loop {T:.0f}s")

#!/usr/bin/env python3
"""Bake provided clips into the monitor in the scene.

    ./py.sh screen.py src/ants.mp4 src/vinland.mp4

The screen is TINY — 101x46 visible — so this is not "scale a video down".
Almost nothing survives that reduction except gross shape and motion, and the
three things that make a rectangle of moving pixels read as a *screen in the
room* rather than a video pasted on the wall are all added here, once, rather
than by the render filtergraph 17280 times:

  monochrome   a small screen with full colour reads as a photograph. Mapping
               luminance to a single cyan ramp reads as a display, and puts the
               screen in the plate's own palette for free.
  scanlines    the strongest "this is a display" cue there is, and at 56px tall
               the only spatial structure with room to be seen.
  bloom        a screen emits. Without a little glow bleeding off the bright
               areas it reads as a printed sticker.

LOOP LENGTH IS NOT FREE, for the same reason nothing else in this render is.
The wallpaper loop is 288s and the screen is one more periodic layer: unless
the baked program's duration divides 288 exactly, the wallpaper seam lands
mid-clip and the screen jump-cuts every 4:48.

That is also why more clips do NOT mean a longer wallpaper loop. Clips share
the program; the program divides T. Raising T is a separate and expensive
decision — it must stay a multiple of 48 for the rain to wrap, and it costs
render time and file size in proportion.

A clip can be given a range: `clip.mp4@0:43-1:45` takes that excerpt and nothing
else. Ranges accept SS, M:SS or H:M:SS, and either end may be left empty.

Slots are allocated max-min fair, NOT proportionally. Short clips are short
because someone chose an excerpt, so they play in full and the long clip absorbs
whatever is left over; proportional shares would cut a hand-picked 30s clip to
20s in order to give a 4-minute filler montage more room, which is backwards.
SLOTS=96,144,48 overrides the split entirely — how long a clip happens to be
still says nothing about how well it reads at 111x56.

Seams are dissolves, not cuts. There is one between every pair of segments and
one more where the program wraps, and each costs XFADE seconds of source. On a
wallpaper that runs for months, a hard cut at a fixed phase is the one artefact
a viewer is guaranteed to eventually notice.

The screen also spends OFF seconds dark, split evenly into a gap after every
clip. Gaps go BETWEEN the clips rather than in one block at the end because the
point of them is that the monitor is idle between things, and because they give
each clip an unambiguous start — a dissolve from dark reads as "something came
on", whereas clip dissolving into clip reads as one continuous programme.

Dark is not a black rectangle: an off panel is a MIRROR, so the idle segment is
the plate's own pixels from behind the mask, heavily darkened. Painting flat
black instead reads as a hole cut in the wall, the same mistake the drip's
puddle started out making.

  OFF=48             TOTAL seconds idle per loop, shared across the gaps;
                     0 keeps the screen on and runs the clips back to back
  FIT=trim|stretch   force cutting or retiming (default: trim if it fits)
  LOOP=144           force a program length; must divide 288
  SLOTS=96,144,48    per-clip seconds; must sum to the program length minus OFF
  FPS=30             must divide 60, or the 60fps render judders
  SCAN=0 BLOOM=0 VIG=0 NORM=0    turn parts of the treatment off, to compare
  OFF_GAIN=0.48      brightness of the idle panel, against a plate at 207

Output is screen/screen.mkv (FFV1, lossless — this is an intermediate, and h264
at 111x56 would put its artefacts exactly where the scanlines are) plus
screen/meta.sh, which render5.sh sources and graph.py stats. Delete screen/ and
both fall back to the bar visualiser, so a clone without the clips still
renders.
"""
import os
import subprocess
import sys

T = 288.0                    # MUST match graph.py's T
W, H = 111, 56               # the full support of mask_screen.png, i.e. every
                             # pixel where the mask is nonzero at all. The
                             # visible core is 101x46; the extra ring is what
                             # the mask's soft edge fades out over, and content
                             # has to exist there for that edge to do anything.
X, Y = 1145, 590             # and where it sits, for the idle mirror crop.
                             # Must match graph.py's SCREEN_X/SCREEN_Y.

FPS = int(os.environ.get('FPS', 30))
XFADE = float(os.environ.get('XFADE', 1.0))
OFF = float(os.environ.get('OFF', 48))
FIT = os.environ.get('FIT', 'auto')          # auto | trim | stretch

# --- look -------------------------------------------------------------------
# These are set against the plate, not in the abstract. The panel the screen is
# set into has a median luma of 207 — it is a BRIGHT surround — so a screen
# graded to look right on its own comes out as a dark saturated rectangle stuck
# to a pale mint wall. Everything below exists to close that gap.
NORM = float(os.environ.get('NORM', 0.75))      # per-clip auto-levels. Clips
                                                # arrive graded to their own
                                                # taste and a night scene has no
                                                # business being 3 stops under
                                                # the one before it.
CONTRAST = os.environ.get('CONTRAST', '1.05')
LIFT = os.environ.get('LIFT', '0.15')           # black level: a screen showing
MID = os.environ.get('MID', '0.63')             # pure black reads as a hole
SHARP = os.environ.get('SHARP', '0.7')          # recover shape edges the
                                                # box filter smeared
SCAN = float(os.environ.get('SCAN', 0.16))      # fraction taken off every other row
VIG = float(os.environ.get('VIG', 0.15))        # corner falloff: curved glass
WHITE = float(os.environ.get('WHITE', 0.75))    # how far highlights desaturate
WHITE_P = float(os.environ.get('WHITE_P', 3.0)) # toward white, and how abruptly
BLOOM = os.environ.get('BLOOM', '0.34')
BLOOM_SIGMA = os.environ.get('BLOOM_SIGMA', '1.1')
OFF_GAIN = float(os.environ.get('OFF_GAIN', 0.48))  # how much of the room the
                                                    # dark panel still reflects
# Luminance -> cyan. Scale all three together to change overall brightness; the
# RATIOS are what makes it the plate's cyan rather than some other cyan.
TR, TG, TB = (float(os.environ.get(k, v)) for k, v in
              (('TR', '0.17'), ('TG', '0.87'), ('TB', '1.00')))

clips = sys.argv[1:]
if not clips:
    sys.exit("usage: screen.py CLIP [CLIP ...]   (see the docstring)")
if 60 % FPS:
    sys.exit(f"FPS={FPS} does not divide 60; the render would judder")


def probe(path):
    out = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0',
         '-show_entries', 'stream=duration', '-show_entries', 'format=duration',
         '-of', 'default=nw=1:nk=1', path],
        capture_output=True, text=True, check=True).stdout.split()
    return max(float(v) for v in out if v != 'N/A')


def clock(s):
    """SS | M:SS | H:M:SS -> seconds."""
    p = [float(v) for v in s.split(':')]
    return sum(v * 60 ** i for i, v in enumerate(reversed(p)))


def split_range(arg):
    """`clip.mp4@0:43-1:45` -> (path, start, end). A path that exists as
    written is never split, so an @ in a filename is not a problem."""
    if os.path.exists(arg) or '@' not in arg:
        return arg, 0.0, None
    path, _, spec = arg.rpartition('@')
    a, _, b = spec.partition('-')
    return path, (clock(a) if a else 0.0), (clock(b) if b else None)


paths, starts, avail = [], [], []
for arg in clips:
    p, s, e = split_range(arg)
    if not os.path.exists(p):
        sys.exit(f"no such clip: {p}")
    a = (e if e is not None else probe(p)) - s
    if a <= XFADE:
        sys.exit(f"{p}: only {a:.1f}s usable")
    paths.append(p)
    starts.append(s)
    avail.append(a)
clips = paths

# --- program length ---------------------------------------------------------
# N must divide T*FPS as well as index T, so that the program length and its
# frame count are both exact integers. A program 0.4 of a frame short still
# jumps, and it jumps at the same instant every 4:48 forever.
#
# Only the clips draw on the source: the idle segment is generated, so it makes
# the loop longer without needing another second of footage.
#
# Always take the LONGEST legal program that the footage supports. A longer
# program means fewer repeats inside the wallpaper loop, and at L = T the screen
# never repeats at all. Having more footage than the program needs is not a
# problem — it is trimmed. Having less is, because the only way to fill the loop
# is then to slow everything down, which is visible in a way a trim is not.
want = os.environ.get('LOOP', 'auto')
need = lambda L: (L - OFF) + len(clips) * XFADE
legal = [T / n for n in range(1, 2001)
         if (T * FPS) % n == 0 and T % (T / n) == 0 and need(T / n) > 0]
if want != 'auto':
    L = float(want)
    if T % L or (T * FPS) % (T / L):
        sys.exit(f"LOOP={want} does not divide T={T:.0f} into whole frames")
else:
    fits = [L for L in legal if need(L) <= sum(avail)]
    stretchy = [L for L in legal if need(L) / sum(avail) <= 1.35]
    if not (fits or stretchy):
        sys.exit(f"{sum(avail):.1f}s of source fits no divisor of {T:.0f} "
                 f"without extreme retiming; set LOOP, lower OFF, or add clips")
    L = max(fits or stretchy)
if OFF >= L:
    sys.exit(f"OFF={OFF} leaves nothing of a {L:g}s program")

NL = int(round(L * FPS))
NX = int(round(XFADE * FPS))
NOFF = int(round(OFF * FPS))

# --- slots ------------------------------------------------------------------
# Max-min fair: walk the clips shortest first and give each either its whole
# usable length or an equal share of what is left, whichever is smaller. Every
# clip that CAN play in full does, and the surplus lands on the longest one.
#
# Proportional shares were the first version and are wrong here. They cut every
# clip by the same fraction, so a deliberately chosen 62s excerpt gets shortened
# to make room for more of a 4-minute montage — the montage is the part with
# seconds to spare, so it is the part that should give them up.
def allocate(cap, budget):
    out = [0.0] * len(cap)
    left = budget
    for k, i in enumerate(sorted(range(len(cap)), key=lambda i: cap[i])):
        out[i] = min(cap[i], left / (len(cap) - k))
        left -= out[i]
    if left > 1e-6:                       # not enough footage: everything
        for i, c in enumerate(cap):       # stretches by the same factor
            out[i] += left * c / sum(cap)
    return out


if os.environ.get('SLOTS'):
    slot = [int(round(float(s) * FPS)) for s in os.environ['SLOTS'].split(',')]
    if len(slot) != len(clips) or sum(slot) != NL - NOFF:
        sys.exit(f"SLOTS must be {len(clips)} values summing to {L - OFF:g}s")
else:
    share = allocate([a - XFADE for a in avail], (NL - NOFF) / FPS)
    slot = [int(s * FPS) for s in share]
    slot[avail.index(max(avail))] += (NL - NOFF) - sum(slot)
# One gap after each clip; the last one is what the program wraps through.
gap = []
if NOFF:
    base, rem = divmod(NOFF, len(clips))
    gap = [base + (j < rem) for j in range(len(clips))]
if min(slot + gap) <= NX:
    sys.exit(f"a segment is shorter than XFADE={XFADE}s; use SLOTS, fewer "
             f"clips, or a smaller OFF")

# Each segment supplies its slot plus one dissolve tail, which the next
# segment's head consumes. Trim when the source is long enough, retime only when
# it is not — a speed change is visible and a trim is not.
speed = []
for c, a, s in zip(clips, avail, slot):
    f = ((s + NX) / FPS) / a
    if FIT == 'trim' and f > 1.0:
        sys.exit(f"{c}: FIT=trim needs {(s + NX) / FPS:.1f}s, has {a:.1f}s")
    speed.append(1.0 if (FIT != 'stretch' and f <= 1.0) else f)

print(f"program {L:g}s x {T / L:g} = {T:.0f}s   {NL} frames @ {FPS}fps   "
      f"xfade {XFADE}s")
for i, (c, a, s, v) in enumerate(zip(clips, avail, slot, speed)):
    print(f"  {s / FPS:7.2f}s  speed {v:5.3f}x  of {a:6.1f}s  "
          f"{os.path.basename(c)}")
    if gap:
        print(f"  {gap[i] / FPS:7.2f}s  idle (dark panel, reflecting the plate)")

# --- pass 1: grade each segment, dissolve them into one program -------------
# Grading happens BEFORE the joins because every filter after the scale runs on
# 111x56, and because dissolving two graded clips crossfades the finished look
# rather than crossfading two sources and grading the mush that results.
#
# Scanline, curvature, tint and highlight rolloff are ONE geq rather than a
# scanline geq followed by a colorchannelmixer. The mixer can only do a linear
# luma -> colour map, which holds the tint's saturation constant all the way to
# white, and a fully saturated cyan rectangle is exactly what does not belong on
# this plate. Real phosphor desaturates as it approaches its limit, so the white
# term pulls highlights toward the panel's own pale cyan while leaving the
# midtones fully tinted.
#
# An earlier version wrote `geq=lum='...'` and let the chroma planes default.
# geq falls back to the FIRST expression given for any plane left out, so the
# luminance expression ran on cb and cr as well; chroma tracked luma and the
# monochrome ramp came out a hue sweep, green midtones and blue highlights.
# Working in RGB with all three planes given explicitly removes that trap.
def tint(t, n, white=True):
    w = f"+(1-{t:.6f})*{WHITE}*pow({n},{WHITE_P})" if white else ""
    return f"clip(255*{n}*{VIGN}*({t:.6f}{w}),0,255)"


LUMA = f"(r(X,Y)/255*(1-{SCAN}*mod(Y,2)))"
FLAT = "(r(X,Y)/255)"
VIGN = f"(1-{VIG}*(((X-W/2)/(W/2))^2+((Y-H/2)/(H/2))^2)/2)"


def geq(n, gain=1.0, white=True):
    return ("geq=r='" + tint(TR * gain, n, white)
            + "':g='" + tint(TG * gain, n, white)
            + "':b='" + tint(TB * gain, n, white) + "'")


# normalize is temporally stateful, which is normally a hazard in a loop. It is
# safe here because every clip both begins and ends inside a dissolve to or from
# the idle panel, so no frame ever has to match a frame graded in a different
# pass. smoothing is 5s: short enough to follow a scene change, long enough not
# to pump on a passing headlight.
GRADE = (
    "setpts=PTS-STARTPTS,setpts={speed}*PTS,fps={fps}"
    ",scale={w}:{h}:force_original_aspect_ratio=increase:flags=lanczos"
    ",crop={w}:{h}"
    ",normalize=blackpt=black:whitept=white:independence=0"
    ":smoothing={smooth}:strength={norm}"
    ",format=gray"
    ",eq=contrast={contrast}"
    ",curves=all='0/{lift} 0.5/{mid} 1/1'"
    ",unsharp=3:3:{sharp}:3:3:0"
    ",format=gbrp," + geq(LUMA) + ",format=rgb24"
)
# No scanlines on the idle segment: nothing is scanning. The panel is the plate
# seen through dark glass, so it keeps the cyan ratios, keeps the curvature, and
# loses most of the gain. OFF_GAIN was 0.20 to begin with and read as a hole cut
# in a bright white wall — the same mistake the drip's puddle started with.
IDLE = ("crop={w}:{h}:{x}:{y},format=gray,eq=contrast=0.55,format=gbrp,"
        + geq(FLAT, gain=OFF_GAIN, white=False) + ",format=rgb24")
TRIM = ",trim=start_frame=0:end_frame={n},setpts=PTS-STARTPTS"

look = dict(fps=FPS, w=W, h=H, contrast=CONTRAST, lift=LIFT, mid=MID,
            sharp=SHARP, norm=NORM, smooth=FPS * 5)
g, segs = [], []
for i, (s, v) in enumerate(zip(slot, speed)):
    g.append(f"[{i}:v:0]" + GRADE.format(speed=f"{v:.9f}", **look)
             + TRIM.format(n=s + NX) + f"[c{i}];")
    segs.append((f"c{i}", s))
    if gap:
        # A separate v2.png input per gap rather than one split k ways: the gaps
        # are consumed far apart in the chain, and a split would have to buffer
        # every frame in between to keep the later branches fed. Decoding one
        # more PNG is free by comparison.
        g.append(f"[{len(clips) + i}:v]" + IDLE.format(w=W, h=H, x=X, y=Y)
                 + TRIM.format(n=gap[i] + NX) + f"[off{i}];")
        segs.append((f"off{i}", gap[i]))

# xfade consumes NX frames of overlap, so chaining segments of (slot+NX) yields
# NL+NX frames: the program, plus one tail still waiting for the wrap dissolve
# that pass 2 applies.
prev, acc = segs[0][0], segs[0][1] + NX
for lbl, n in segs[1:]:
    out = f"x{lbl}"
    g.append(f"[{prev}][{lbl}]xfade=transition=fade:duration={XFADE}"
             f":offset={(acc - NX) / FPS:.6f}[{out}];")
    acc += n
    prev = out
g.append(f"[{prev}]format=rgb24[out]")

os.makedirs('screen', exist_ok=True)
open('screen/prog.gen.txt', 'w').write("\n".join(g) + "\n")

cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error']
for c, s, a in zip(clips, starts, avail):
    cmd += ['-ss', f"{s:.6f}", '-t', f"{a:.6f}", '-i', c]
cmd += ['-loop', '1', '-framerate', str(FPS), '-i', 'v2.png'] * len(gap)
cmd += ['-filter_complex_script', 'screen/prog.gen.txt', '-map', '[out]',
        '-frames:v', str(NL + NX), '-r', str(FPS), '-an',
        '-c:v', 'ffv1', '-level', '3', '-g', '1', 'screen/prog.mkv']
subprocess.run(cmd, check=True)

# --- pass 2: close the loop, then bloom -------------------------------------
# The wrap is closed by ROTATING the program: [tail x head][body]. Played back
# to back that is body -> tail (continuous in the source) -> dissolve -> head ->
# body (continuous again), so the only discontinuity anywhere is the dissolve.
#
# prog.mkv is opened three times rather than split three ways because the three
# branches consume frames NL apart, and a split would make ffmpeg buffer the
# whole gap — ~160MB of raw frames — to keep them fed.
rot = [
    f"[0:v]trim=start_frame=0:end_frame={NX},setpts=PTS-STARTPTS[head];",
    f"[1:v]trim=start_frame={NX}:end_frame={NL},setpts=PTS-STARTPTS[body];",
    f"[2:v]trim=start_frame={NL}:end_frame={NL + NX},setpts=PTS-STARTPTS[tail];",
    f"[tail][head]xfade=transition=fade:duration={XFADE}:offset=0[seam];",
    "[seam][body]concat=n=2:v=1:a=0,split=2[s0][s1];",
    f"[s1]gblur=sigma={BLOOM_SIGMA}[bl];",
    f"[s0][bl]blend=all_mode=screen:all_opacity={BLOOM},format=rgb24[out]",
]
open('screen/rot.gen.txt', 'w').write("\n".join(rot) + "\n")
subprocess.run(
    ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
     '-i', 'screen/prog.mkv', '-i', 'screen/prog.mkv', '-i', 'screen/prog.mkv',
     '-filter_complex_script', 'screen/rot.gen.txt', '-map', '[out]',
     '-frames:v', str(NL), '-r', str(FPS), '-an',
     '-c:v', 'ffv1', '-level', '3', '-g', '1', 'screen/screen.mkv'], check=True)
os.remove('screen/prog.mkv')

with open('screen/meta.sh', 'w') as f:
    f.write("# Generated by screen.py — sourced by render5.sh, stat'd by graph.py.\n")
    f.write(f"SCREEN_FPS={FPS}\nSCREEN_LOOP={L:g}\nSCREEN_FRAMES={NL}\n"
            f"SCREEN_W={W}\nSCREEN_H={H}\nSCREEN_OFF={OFF:g}\n")
    f.write("SCREEN_CLIPS='" + " ".join(os.path.basename(c) for c in clips) + "'\n")

subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration,size',
                '-show_entries', 'stream=codec_name,width,height,nb_frames',
                '-of', 'default=nw=1', 'screen/screen.mkv'])
print("-> screen/screen.mkv   now: ./py.sh graph.py && OUT=hq.mp4 ./render5.sh")

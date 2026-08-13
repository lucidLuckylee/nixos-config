# Animated wallpaper generator

Everything needed to rebuild `~/.local/share/wallpaper/animated.mp4`. The render
is kept out of git because it is ~103 MB and composites clips that may be used
but not redistributed. Machines without it fall back to the still, via
`ConditionPathExists` on the mpvpaper unit in `home/wallpaper.nix` — so a fresh
clone is never broken, just static.

The rest of this file is *why*, including a number of approaches that were tried
and abandoned. Read the relevant section before changing anything visual; most
of the obvious ideas are in here with the reason they failed.

## Commands

Nix and nothing else — every script fetches its own dependencies.

    ./py.sh script.py          # numpy + pillow + scipy
    ./pytorch.sh script.py     # + torch + transformers

Full rebuild, in order. `pytorch.sh` should never be needed: `sam/` and
`layers.png` are committed, so the depth model and SAM never run again unless
you want to redo the layer map — that alone saves a ~3.7 GB model download.

    ./py.sh steam3.py                     # ~70 s   -> steam/  (360 frames)
    ./py.sh drip.py                       # ~35 s   -> drip/   (1440 frames)
    ./py.sh screen.py src/a.mp4 ...       # ~3 min  -> screen/ (optional)
    ./py.sh graph.py                      # instant -> graph5.gen.txt
    OUT=hq.mp4 ./render5.sh               # ~56 min -> ~103 MB
    ./verify.sh hq.mp4
    ./install.sh hq.mp4

`steam/`, `drip/` and `screen/` are gitignored; everything else the render reads
is committed, so a first render works straight after clone. `render5.sh` refuses
to run when `graph5.gen.txt` is older than `graph.py` or `screen/meta.sh` — a
stale graph is silently WRONG rather than broken, since the input indices still
resolve, just to the wrong images.

The monitor's programme. Clips play in the order given; `@0:43-1:45` takes an
excerpt. `rm -rf screen/` reverts the screen to the bar visualiser.

    ./py.sh screen.py src/ants.mp4 src/penguin.mp4@0:43-1:45 \
                      src/surf.mp4 src/vinland.mp4

A still for a screen of a different shape:

    ./grade.sh ~/Downloads/art.jpg 1680x1050 ../home/wallpaper2.jpg
    UPSCALE=0 ./grade.sh ...              # skip ESRGAN, re-tune the grade only

Preview a slice instead of the whole loop. `FFMPEG_EXTRA` is appended after the
output options, so a second `-t` overrides the built-in `-t 288`:

    OUT=/tmp/peek.mp4 FFMPEG_EXTRA="-t 30" ./render5.sh

Sampling a single late frame is *not* cheap — ffmpeg processes the timeline up
to the moment you ask for, so grabbing t=250 costs nearly a whole render. Render
once and pull frames out of the mp4 with `-ss`. To check the screen, do not
render at all; composite one frame onto the plate (see "The screen").

Put it on another machine — no rebuild and no re-render. The render is 1920x1080
and every Linux machine here has a 1920x1080 output, and the mpvpaper unit
already exists everywhere, merely skipped until the file appears.

    cp ~/.local/share/wallpaper/animated.mp4 /run/media/lucy/STICK/ && sync
    ./install.sh /run/media/lucy/STICK/animated.mp4    # on the other machine

## Pipeline

    v2.png                the plate (upscaled, graded still — same image the
                          repo ships as home/wallpaper.jpg)
      |
      +-- depth2.py       Depth Anything V2 Large, ensembled over 3 scales
      |     -> depth.npy
      +-- sam_masks.py    SAM ViT-H, one prompt per object
      |     -> sam/*.png
      +-- sam_port.py     SAM, exact porthole opening
      |     -> sam/port_glass.png
      |
      +-- layers3.py      depth bands + SAM masks + connectivity
            -> layers.png          index image, pixel value = layer 0..5
            -> ~/Downloads/wallpaper-layers/   previews
      |
      +-- matte4.py       -> mask_port.png   rain matte
      |                      = exact opening (SAM) AND exterior (layer 0)
      +-- uselayers.py    -> mist.png, mask_layer0.png
      +-- assets4.sh      -> rain_near/mid/far.png   (3 depths)
      +-- steam3.py       -> steam/steam_%03d.png    (particle plume)
      +-- drops.py        -> drops_x/y.png, drops_spec.png
      +-- drip.py         -> drip/drip_%03d.png
      +-- screen.py       -> screen/screen.mkv    (the monitor's programme)
      |
      +-- render5.sh      ffmpeg, graph5.gen.txt   -> hqN.mp4
      +-- install.sh      atomic install + service restart

`py.sh` runs a python with numpy/pillow/scipy; `pytorch.sh` adds torch and
transformers (only depth2.py and sam_masks.py need it).

## The still wallpapers

`grade.sh` makes the stills that sway draws as each output's background —
`home/wallpaper.jpg` for the 16:9 screen and `home/wallpaper2.jpg` for the 16:10
one. It is the recipe that used to live only in commit db6d895's message:

    ./grade.sh ~/Downloads/art.jpg 1680x1050 ../home/wallpaper2.jpg

ESRGAN x4 then downsample to the target, sigmoidal contrast, +18 saturation,
30% blend with the same image mapped to `home/colors.nix`. The palette is read
out of colors.nix rather than transcribed, so it cannot drift from the theme.

Two things worth knowing before reaching for something simpler:

**The x4-then-down detour earns its keep.** These sources are ~1MP against a
1.7MP screen, so the naive move is a 1.57x Lanczos resize. Side by side at 1:1
that is visibly mush — brush edges smear and the small painted posters stop
being legible — while the ESRGAN path keeps them crisp without plasticising the
brushwork. The downsample is what removes the smearing the network invents.

**`gowall upscale` is not the upscaler.** It wants to fetch and set up its own
realesrgan binary, which on NixOS is a dynamically linked blob that will not
run; it fails at setup, and before that it exited 127. nixpkgs'
`realesrgan-ncnn-vulkan` is what works, and `gowall` is used only for the grade.

ESRGAN runs on Vulkan, so check what it is actually running on:

    nix shell nixpkgs#vulkan-tools -c vulkaninfo --summary | grep driverName

If that says `llvmpipe` rather than your card, it is on the CPU and a 1MP image
takes ~30 minutes instead of ~15 seconds. On this machine that happens when the
NVIDIA kernel module and userspace libraries are out of step after a rebuild —
the same mismatch that makes `nvidia-smi` report a version mismatch. A reboot
fixes it. `UPSCALE=0` skips the upscale so the tonality, which is the part worth
iterating on, can be re-run in seconds against an already-upscaled image.

## Fixing the layer map by hand

    ./py.sh paint_export.py          # -> ~/Downloads/wallpaper-layers/
    #  edit layers_paint.png in any editor (nix run nixpkgs#gimp)
    ./py.sh paint_import.py          # snap back, rebuild dependent assets
    OUT=hq13.mp4 ./render5.sh
    ./verify.sh hq13.mp4 && ./install.sh hq13.mp4

`layers_paint.png` has one saturated colour per layer; the importer snaps every
pixel to the nearest palette entry, so soft brush edges are harmless. Keep it at
1920x1080. `layers_outline.png` shows the current boundaries over the plate, and
`layers.gpl` is a GIMP palette of the six colours.

| # | layer     | colour    |
|---|-----------|-----------|
| 0 | exterior  | `#0064ff` |
| 1 | far-room  | `#8c5a28` |
| 2 | mid-room  | `#00c878` |
| 3 | near-mid  | `#ffd200` |
| 4 | near      | `#ff3c64` |
| 5 | nearest   | `#a050ff` |

Layer 0 is special: it is not a depth band but the output of a connectivity
test, and it is what the rain keys off. Repainting it moves the rain.

`gridcrop.py X Y W H out.jpg` prints a crop with a labelled coordinate grid,
for reading vertices when a polygon really is needed.

## Prompting SAM for thin things

Ropes, cords and cables need a **box**, not a click. A point on a three-pixel
line tells SAM nothing about how far the thing extends, so it returns the wall
behind it — 7-10% precision against the clothesline. A tight box around the
span states the extent and precision goes to 82%. `sam_rope.py` is the
experiment that establishes this; keep it for when the next thin thing needs
segmenting.

Two follow-ons. SAM's own confidence ranks the wrong candidate first for thin
structures (it prefers the mask that swallows the background), so those prompts
are listed in `SMALLEST` and picked by area instead. And SAM returns a thin
line in fragments, about 58% of the clothesline's span, so `fill_line()` in
layers3.py fits a quadratic through the fragments' centres and redraws it
continuous — still from the image, not from a guess.

## Drops on the glass

`drops.py`, procedural. This started as a crop of a stock rain-on-window clip,
and that approach is a dead end worth recording: at the size the drops need to
be, roughly 1/15 of the source, no crop of a 1080-tall clip is large enough to
fill the opening, so the detail layer had to be tiled. Mirrored tiling makes the
repeat seamless, and superimposing a second tiling at a coprime scale hides the
seams, but neither removes the repeat — the same cell is still there nine times
and it stays visible as a grid.

Generating them removes the constraint: each drop is placed independently, so
there is nothing to repeat. It also removed the last third-party asset, which
was CC BY-SA and carried attribution and share-alike onto everything built from
it. `src/` is no longer read by the render.

A drop is two things. `displace` bends the view behind it using drops_x/y.png
(128 = no shift), modelling the droplet as a lens that inverts and magnifies
what is behind it. drops_spec.png then adds what refraction cannot: the glint,
the shading across the body, and a faint seating ring. Sizes are heavy-tailed —
mostly sub-2px, a few fat ones — because that is what a rained-on window looks
like. Keep the ring weak and the radii small; the first pass had them at 0.30
and up to 13px and the result read as soap bubbles.

## Rain depth

Three plates, and the cue that matters most is streak WIDTH, which the first
version had no variation in at all — every streak was 1px, so the layers read
as one flat sheet. `assets4.sh` generates each plate at a different resolution
and scales them all to 512x1200: 1024 wide halved gives sub-pixel far streaks,
320 wide scaled up gives fat near ones. Density goes the other way from the
first version too — distant rain covers more solid angle, so the far plate gets
*more* seeds, not fewer.

Scroll speed is the other half of the parallax and lives in the filtergraph
(50/100/200 px/s). Those must divide the loop: at 48s over a 1200px tile, only
multiples of 25 px/s return to their starting offset.

## Steam

`steam3.py`. The previous version drew eight circles, grew them and blurred the
result, which at a glance is a plume and on inspection is eight balls — a circle
has no internal structure and blurring only removes what little it had.

Now ~150 particles, each a radial falloff modulated by its own angular harmonics
so the outline is torn rather than round, sheared and tilted as it rises. Nothing
integrates state frame to frame: position is a closed-form function of the
particle's age and loop-periodic sinusoids, so the sequence loops exactly with
no transient to settle and no seam for `-stream_loop` to expose.

Stock smoke footage was the alternative and was rejected for the same reasons
the rain-on-glass clip was: it does not loop, it arrives at a fixed resolution,
and it carries licence conditions. Watch the fan-out — the first pass had 1.25x
horizontal shear and spread to a cone that clipped the top of the frame.

### eq's contrast pivots about mid-grey, not black

The plume is composited with `blend=all_mode=screen`, for which black is the
identity, so a burst is faded by taking the plate's brightness to black. The
first version did that with `eq=contrast=<ramp>` and it painted a bright 88x136
box over the machine at both ends of every burst.

eq's contrast is `v = contrast*(v - 0.5) + 0.5`. It pivots about mid-grey, so
contrast=0 does not mean "gone", it means "every pixel is 128" — and the steam
plate's own mean is 6. Fading OUT made the plume twenty-one times BRIGHTER than
the plume, which is why the artefact was a solid rectangle rather than a
too-visible plume, and why it appeared at both ends rather than one.

`fade` without `alpha=1` fades toward black, which is exactly what screen
blending wants, and it is a multiply rather than a per-frame expression:

    fade=t=in:st=<start>:d=2.0,fade=t=out:st=<end-2.5>:d=2.5

Measured in the burst rectangle, with t just before the burst as ground truth:

    t=0.9  before      old  40.8   new  40.8
    t=1.0  burst start old 149.8   new  40.8
    t=5.0  full plume  old  46.1   new  46.2
    t=10.9 burst end   old 144.9   new  41.1

If you ever need a genuine per-frame *multiply* elsewhere, note that neither
`eq` nor `colorchannelmixer` will do it — `lut*` has no time variable, and `geq`
does but costs an expression evaluation per pixel per channel.

## LEDs: tried and removed

An auto-placer (`leds.py`, deleted) lit up the small bright specks already
painted into the scene, on the theory that a light blinking where a light
already is must be sitting on real hardware. It is not: "small and bright" also
describes a specular highlight on a pipe, an edge of sheet metal, a rivet. All
nine landed in the wrong places and were cut. If lights are wanted later, pick
the positions by hand off `gridcrop.py` and check each one — do not detect them.

## The drip

`drip.py`. Condensation gathers at the mouth of the descending pipe, a drop
swells and necks over six seconds, lets go, and falls 378px at 57 px/s before
the hammock swallows it.

It is a baked 720-frame sequence, not sprites on overlay expressions, because
the interesting parts — the drop filling, sagging, and necking until surface
tension loses, then the puddle rippling — are shape changes, and `overlay` can
only translate a fixed image. 24s at 30fps, exactly half the loop, so
`-stream_loop` plays it twice and the seam lands in the quiet tail.

Slow to form, quick to fall: 7s swelling at the mouth, then 632px in 2.4s. That
is the shape of a real drip — nearly all the time is surface tension losing an
argument with gravity, and the fall is over almost before you see it.

The puddle is a **mirror**, not a grey disc. The first attempt painted a dark
ellipse with a bright rim and it read as a hole in the floor or a dinner plate.
Water sells itself by showing the room: the puddle samples the plate above it,
mirrored about its own centre line and compressed 0.28x (the surface is seen at
a very shallow angle), darkened to 0.58 because a mirror absorbs. Ripples are
applied as a vertical DISPLACEMENT of that sample rather than as painted arcs —
a ripple tilts the surface, which moves what you see in it.

### Making water look like water

Three mistakes, each of which I could only see by zooming to 6x on the rendered
frame rather than judging a downscaled crop:

**The body must be dark.** A water drop refracts whatever is behind it, and
behind this one is unlit machinery. Rendering the body as additive brightness
made a glowing blue pill. Dark body + a bright rim (total internal reflection,
brightest along the BOTTOM where the light gathers) + one small catchlight is
what reads as water. Watch the rim width: a full even ring reads as an eye.

**Condensation is mostly invisible.** On dark metal you see the catchlights,
not the water. Darkening the beads as much as the falling drop turned them into
black berries. ~430 beads, mostly sub-pixel, power-law glint distribution so a
few catch the light hard and most barely do; darkening at a third of the drop's.

**The surface geometry has to be measured.** The beads sat on a line sloping
+0.345 when the pipe's lower edge actually slopes -0.171 (measured as the
per-column max luminance gradient, robust-fitted). They were tracking a line
that does not exist and drifting off the pipe. `edge_y()` holds the fit. The
hanging drop is anchored ON that edge — 11px of clearance read as floating.

Occlusion comes from `drip_front.png`, which redraws **layer >= 4** — the
hammock — on top of the sequence, so the drop vanishes behind it and re-emerges
below. It must not be layer > 2: there is a thin band of layer 3 at the floor
edge (y 956-965) that is *behind* the falling drop, and including it made the
drop flicker out just above the puddle.

The original version fell 72px and stopped at y=458, which the layer map shows
is mid-air — nothing is there at all.

## The screen

`screen.py` bakes a list of clips into `screen/screen.mkv`, which `render5.sh`
lays down at 1145,590 and `mask_screen.png` cuts to shape. Both that script and
`graph.py` key off `screen/meta.sh`, so deleting `screen/` falls the render back
to the bar visualiser and a fresh clone still works — which it has to, because
the clips are not ours to commit.

    ./py.sh screen.py src/ants.mp4 src/penguin.mp4@0:43-1:45 src/surf.mp4 \
                      src/vinland.mp4

Three separate things had to be got right, and only the first is obvious.

**The programme has to divide the loop.** The screen is one more periodic layer,
so its length obeys the same rule as the rain: unless it divides 288 exactly the
wallpaper seam lands mid-clip and the screen jump-cuts every 4:48. More clips do
NOT mean a longer wallpaper loop — clips share the programme, the programme
divides T. Raising T is a separate and much more expensive decision.

Slots are max-min fair, not proportional. Proportional was the first version and
it cut a deliberately chosen 62s excerpt down to 39s in order to give a
four-minute filler montage more room; the montage is the thing with seconds to
spare, so it is the thing that should give them up. Short clips now play in full
and the longest one absorbs the remainder, which for these four means nothing is
time-stretched at all.

Gaps go BETWEEN the clips, not in one block. The monitor being idle between
things is the point, and a dissolve up from dark gives each clip an unambiguous
start — clip dissolving straight into clip reads as one continuous programme.
The dark state is the plate's own pixels darkened, not black: an off panel is a
mirror. At OFF_GAIN 0.20 it read as a hole cut in the wall, the same mistake the
puddle started with. 0.48 against a plate at luma 211 reads as dark glass.

**The grade is set against the plate, not judged on its own.** The panel around
the screen has a median luma of 207 — a bright surround — and a screen graded to
look good in isolation lands on it as a dark, saturated rectangle. What fixed it:

- *Highlights desaturate toward white.* A linear luminance-to-cyan map holds
  saturation constant all the way up, and full-saturation cyan is exactly what
  does not belong here. Real phosphor washes out as it approaches its limit, so
  highlights are pulled toward the panel's own pale cyan and only the midtones
  stay fully tinted. This one change did most of the work.
- *Per-clip auto-levels.* Clips arrive graded to their own taste, and a night
  driving scene has no business being three stops under the one before it.
  `normalize` at strength 0.75 over a 5s window. It is temporally stateful,
  which is normally a hazard in a loop, but every clip begins and ends inside a
  dissolve, so no frame has to match one graded in a different pass.
- *Scanlines and a slight corner falloff.* At 56px tall the scanline is the only
  spatial structure with room to be seen, and it is the strongest "this is a
  display" cue available.

Check it without rendering. Compositing one screen frame onto `v2.png` through
the mask costs a second and shows exactly what the grade will look like in
place, which matters because sampling t=250 from a real render costs most of an
hour:

    ffmpeg -ss 130 -i screen/screen.mkv -frames:v 1 -update 1 -y /tmp/s.png
    ffmpeg -i v2.png -i /tmp/s.png -i mask_screen.png -filter_complex \
      "[1:v]pad=1920:1080:1145:590[s0];[0:v]format=gbrp[bg];[s0]format=gbrp[s];
       [2:v]format=gbrp[m];[bg][s][m]maskedmerge,crop=201:116:1100:565,
       scale=iw*4:ih*4:flags=neighbor" -frames:v 1 -update 1 -y /tmp/ctx.png

### geq defaults its missing planes to the first one you gave it

`geq=lum='...'` does not leave chroma alone. Any plane expression you omit falls
back to the first one supplied, so the luminance expression ran on cb and cr as
well; chroma tracked luma and a monochrome ramp came out a hue sweep — green
midtones, blue highlights. On 111x56 anime footage that is easy to blame on the
source. On a synthetic 0-255 ramp it is unmissable, which is why the grade is
worth testing on one:

    ffmpeg -i ramp.png -vf "<the chain>" -update 1 -y /tmp/r.png

The scanline, curvature, tint and highlight rolloff are one RGB geq now, with
all three planes written out, so the trap is gone rather than worked around.

## Two things that bite

Never `cp` over the live `animated.mp4`. mpv re-reads the file every loop and
will decode half-written bytes; use `install.sh`, which writes a temp file and
`mv`s it.

`-filter_complex_script` does not accept `#` comments, which is why the graph
lives in a `.gen.txt`.

## Rough edges

- The fog phase is 48 s of near-static haze and may want shortening.
- The surf clip is a night scene and stays dark even after auto-levels. It reads
  as a screen showing something dark, which is correct, but it is the least
  legible of the four at 111x56.

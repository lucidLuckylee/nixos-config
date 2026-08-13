# Animated wallpaper generator

Everything needed to rebuild `~/.local/share/wallpaper/animated.mp4`. Kept out
of the NixOS repo because it is large, not because of licensing — every asset is
now generated here, so nothing in the render carries conditions. (`src/` holds
the CC BY-SA clip the drops used to come from; it is no longer read and can be
deleted.) Machines without the mp4 fall back to the still, via
`ConditionPathExists` on the mpvpaper unit in `home/linux.nix`.

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
      |
      +-- render5.sh      ffmpeg, graph5.gen.txt   -> hqN.mp4
      +-- install.sh      atomic install + service restart

`py.sh` runs a python with numpy/pillow/scipy; `pytorch.sh` adds torch and
transformers (only depth2.py and sam_masks.py need it).

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

## Two things that bite

Never `cp` over the live `animated.mp4`. mpv re-reads the file every loop and
will decode half-written bytes; use `install.sh`, which writes a temp file and
`mv`s it.

`-filter_complex_script` does not accept `#` comments, which is why the graph
lives in a `.gen.txt`.

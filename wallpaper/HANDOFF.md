# Handoff: animated wallpaper generator

Everything needed to rebuild the wallpaper on another machine. The render
itself (~103 MB) is deliberately not in git — you regenerate it.

`README.md` next to this file explains *why* things are the way they are,
including several approaches that were tried and abandoned. Read it before
changing anything visual; most of the obvious ideas are in there with the
reason they failed.

## What you need

Nix, and nothing else. Every script fetches its own dependencies:

    ./py.sh script.py        # numpy + pillow + scipy
    ./pytorch.sh script.py   # + torch + transformers (only depth2/sam_masks)

`nix shell nixpkgs#ffmpeg` and `nixpkgs#imagemagick` are used inline.

You should not need `pytorch.sh` at all: `sam/` and `layers.png` are committed,
so the depth model and SAM never have to run again unless you want to redo the
layer map. That saves a ~3.7 GB model download.

## Rebuild, in order

    ./py.sh steam3.py          # ~75 s   -> steam/   (360 frames)
    ./py.sh drip.py            # ~45 s   -> drip/    (1440 frames)
    ./py.sh graph.py           #  instant -> graph5.gen.txt
    OUT=hq.mp4 ./render5.sh    # the long one, see below
    ./verify.sh hq.mp4
    ./install.sh hq.mp4

`steam/` and `drip/` are gitignored because they are ~24 MB of PNGs that
regenerate in two minutes.

Everything else — the plate, masks, rain plates, drop maps, fog, flash, LEDs —
is committed, so a first render works straight after clone.

## Render cost, and what actually helps

Measured on a Ryzen 5 5500U (6c/12t): **20 s of output took 358 s wall and
1550 s CPU**, i.e. the pipeline sustains about **4.3 cores**. Full 288 s loop
≈ **86 minutes**, ~103 MB.

It is already multi-threaded, so the wins available are:

- **More/faster CPU cores.** The most reliable one. The filtergraph is a large
  share of the cost and runs entirely on CPU.
- **`CODEC_ARGS="$H264_FAST"`** — x264 `-preset medium` instead of `slow`.
  Free, and visually indistinguishable at CRF 15 on this material.
- **`CODEC_ARGS="$NVENC"`** — hands the encode to the GPU. Real, but bounded:
  it only removes the encoder's share.

A GPU cannot take the filtergraph. `maskedmerge`, `displace`, `blend`, and 60
timed `overlay`s have no CUDA equivalents in ffmpeg, so those stay on the CPU
whatever card is present. Do not expect the 90 minutes to become 10.

If you want a fast preview rather than a final, render a slice:

    OUT=/tmp/peek.mp4 FFMPEG_EXTRA="-t 30" ./render5.sh

Note that single-frame sampling is *not* cheap: ffmpeg processes the timeline
up to the moment you ask for, so grabbing t=250 costs nearly a whole render.
Render once and pull frames out of the mp4 with `-ss` instead.

## Installing

`install.sh` decodes the file to check it, writes a temp file and `mv`s it into
`~/.local/share/wallpaper/animated.mp4`, then restarts the user service.

**Never `cp` over the live file.** mpv runs with `--loop-file=inf` and re-reads
it every loop; overwriting in place makes it decode half-written bytes and die
with "Invalid NAL unit size". `mv` is an atomic rename, so a running player
keeps the old inode until it restarts.

The machine needs the mpvpaper user service from `home/linux.nix`. Machines
without the mp4 fall back to the still automatically — that is the
`ConditionPathExists` on the unit, so a fresh clone is never broken, just
static.

## The timeline

`graph.py` is the source of truth. The weather cycle, the washing-machine
bursts and the LED states are tables at the top of it; change those and
regenerate rather than editing `graph5.gen.txt`, which is overwritten.

The loop is 288 s and that number is not free. The rain plates wrap over a
1200 px vertical tile and a 512 px horizontal one, and the steam loops every
6 s, so the loop must be a multiple of **48 s** or layers visibly jump at the
seam. Scroll speeds are constrained too: `vy` a multiple of `1200/T`, `vx` of
`512/T`, and `vx/vy` held at 0.2133 to match the 12° streak tilt.

## Known-unfinished

- **The screen still shows the bar visualiser.** The intent is a video looped
  into the panel with a cyan tint. The screen is **101 x 46 px**, 2.2:1 — put a
  clip you have the rights to in `src/` and wire it in near the `mask_screen`
  section of `graph.py`. Content matters far more than resolution at that size.
- The fog phase is 48 s of near-static haze and may want shortening.
- `src/` and `hf/` are gitignored; nothing in the render reads `src/` any more.

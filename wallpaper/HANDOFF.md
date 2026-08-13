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

    ./py.sh steam3.py          # ~70 s   -> steam/   (360 frames)
    ./py.sh drip.py            # ~35 s   -> drip/    (1440 frames)
    ./py.sh screen.py CLIP...  # ~3 min  -> screen/  (optional, see below)
    ./py.sh graph.py           #  instant -> graph5.gen.txt
    OUT=hq.mp4 ./render5.sh    # the long one, see below
    ./verify.sh hq.mp4
    ./install.sh hq.mp4

`steam/`, `drip/` and `screen/` are gitignored — the first two are ~24 MB of
PNGs that regenerate in two minutes, and the third is built from clips that are
not ours to commit.

Everything else — the plate, masks, rain plates, drop maps, fog, flash, LEDs —
is committed, so a first render works straight after clone. Without `screen/`
the monitor falls back to the bar visualiser rather than failing.

`render5.sh` refuses to run if `graph5.gen.txt` is older than `graph.py` or
`screen/meta.sh`. A stale graph is silently WRONG rather than broken — the input
indices still resolve, they just resolve to the wrong images — and you would
find out an hour later.

## Render cost, and what actually helps

Measured on a Ryzen 5 3600 (6c/12t), 6 s of output:

    filtergraph only (-f null)   66.3 s wall, 389 s CPU
    + x264 -preset medium        67.4 s
    + x264 -preset slow          69.8 s

Full 288 s loop ≈ **56 minutes**, ~100 MB. The pipeline sustains **5.9 cores**.

**The encoder is 5% of that.** This kills the two obvious speedups:

- **`CODEC_ARGS="$NVENC"`** — the GPU can only take the encode, because
  `maskedmerge`, `displace`, `blend` and 60 timed `overlay`s have no CUDA
  equivalents in ffmpeg. That caps it at 3.5 s in 70, so a GPU render is ~53
  minutes instead of ~56. Not worth chasing, and definitely not worth rebooting
  into a driver fix for. (If you try anyway: `nvidia-smi` reporting
  "Driver/library version mismatch" means the loaded kernel module is older than
  the userspace libs after a rebuild, and NVENC will fail with
  `CUDA_ERROR_COMPAT_NOT_SUPPORTED_ON_DEVICE`.)
- **`CODEC_ARGS="$H264_FAST"`** — saves 2.4 s in 70. `-preset slow` is the only
  one of these knobs that changes the output, so keep it.

What is actually left on the table is the other 6 cores. Harvesting them means
rendering segments of the timeline in parallel processes, and every scrolling
layer's phase would have to be re-derived per segment — steam, drip and the
screen programme all loop at their own rates. A wrong offset there does not
fail, it just makes the loop jump. Not attempted.

If you want a fast preview rather than a final, render a slice — see below.

If you want a fast preview rather than a final, render a slice:

    OUT=/tmp/peek.mp4 FFMPEG_EXTRA="-t 30" ./render5.sh

(`FFMPEG_EXTRA` is appended after the output options, so a second `-t` there
overrides the built-in `-t 288`.)

Note that single-frame sampling is *not* cheap: ffmpeg processes the timeline
up to the moment you ask for, so grabbing t=250 costs nearly a whole render.
Render once and pull frames out of the mp4 with `-ss` instead.

If what you are checking is the screen, do not render at all — composite one
frame of `screen/screen.mkv` onto `v2.png` through `mask_screen.png` and look at
that. It costs a second, shows the grade exactly as it will land, and is the
only reason the screen took four passes to tune instead of four hours. The
command is in README under "The screen".

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

## The screen

Done, via `screen.py` — see README for why it is shaped the way it is. The short
version:

    ./py.sh screen.py src/ants.mp4 src/penguin.mp4@0:43-1:45 src/surf.mp4 \
                      src/vinland.mp4

builds a 288 s programme: each clip in turn with 12 s of dark panel between
them, dissolves at every seam, baked to `screen/screen.mkv` at 111x56 with the
monochrome-cyan, scanline and bloom treatment already applied. Clips are laid
down in the order given. `clip.mp4@0:43-1:45` takes an excerpt.

The programme length must divide 288, which `screen.py` enforces. Adding clips
does not require a longer wallpaper loop — they share the programme.

To change what is on the screen, re-run `screen.py`, then `graph.py`, then
render. To take the screen out entirely, `rm -rf screen/`; the render falls back
to the bar visualiser on its own.

## Known-unfinished

- The fog phase is 48 s of near-static haze and may want shortening.
- Anything faded for a `blend=all_mode=screen` layer must go to BLACK, and `eq`
  cannot do that — its contrast pivots about mid-grey, so a ramp to zero paints
  a solid mid-grey rectangle. This bit the washing-machine steam bursts for
  three renders. Use `fade` (no `alpha=1`). README has the measurements.
- The surf clip is a night scene and stays dark even after auto-levels. It
  reads as a screen showing something dark, which is correct, but it is the
  least legible of the four at 111x56.
- `src/` and `hf/` are gitignored. `src/` is read again now — `screen.py` takes
  its clips from there — but nothing in the *render* reads it directly.

# Samsung Gear 360 SM-R210 to Equirectangular Converter

Batch-convert Samsung Gear 360 2017 / SM-R210 dual-fisheye videos into equirectangular 360 video using `ffmpeg`'s `v360` filter.

This is a small workflow script, not a full camera-agnostic stitcher. The default settings are tuned from real SM-R210 2560x1280 footage for use in Final Cut Pro as 360 source media that can be reframed in a normal 16:9 project.

## Current Preset

```text
v360=input=dfisheye:output=equirect:ih_fov=190.5:iv_fov=191:interp=lanczos
```

This was chosen because it gave the best practical result in comparison tests:

- `ih_fov=190.5` looked better than `190`
- `iv_fov=191` improved the stitch compared with matching horizontal/vertical FOV
- `interp=lanczos` looked sharper than default interpolation

## Requirements

- macOS, Linux, or another shell environment with Bash
- `ffmpeg`
- `ffprobe`
- `exiftool` for 360 metadata tagging

On macOS with Homebrew:

```bash
brew install ffmpeg exiftool
```

The script looks for `exiftool` in `PATH` first. If it is missing, the videos still convert, but Final Cut may not automatically recognize them as 360/equirectangular clips.

## Usage

```bash
./convert_gear360.sh "/path/to/raw-folder" "/path/to/output-folder"
```

Example:

```bash
./convert_gear360.sh \
  "/Users/michael/Movies/gear360_raw" \
  "/Users/michael/Movies/gear360_stitched"
```

The script converts `.MP4` and `.mp4` files in the input folder only. It does not recurse into subfolders.

Outputs are named:

```text
original_name_equirect.mp4
```

## Options

```text
--prores        Output ProRes 422 MOV files for Final Cut
--force         Overwrite existing outputs
--crf VALUE     H.264 quality, default 18
--preset VALUE  H.264 preset, default medium
--help          Show script help
```

Example ProRes conversion:

```bash
./convert_gear360.sh --prores "/path/to/raw-folder" "/path/to/output-folder"
```

ProRes outputs are named:

```text
original_name_equirect.mov
```

## Final Cut Pro Notes

Recommended workflow:

1. Keep the Final Cut library on local storage.
2. Import converted equirectangular files.
3. Confirm Final Cut sees the clips as:
   - Projection: `Equirectangular`
   - Stereoscopic: `Monoscopic`
4. Use a normal 16:9 project, usually `1080p`, and reframe the 360 clip.

Why 1080p:

- The stitched SM-R210 frame is only `2560x1280`.
- A normal reframed view uses only part of the sphere.
- A 4K timeline will not create additional real detail from this camera.

## Why Not Samsung ActionDirector?

The original Samsung/CyberLink Gear 360 software is effectively abandoned and unreliable on modern Apple Silicon Macs.

## Why Not Hugin / gear360pano?

The Hugin/`gear360pano` path had theoretical advantages, especially seam blending and calibration templates, but in testing it was too slow and produced worse geometry for the sample footage. The horizon could not be leveled consistently when rotating around the sphere, which points to a bad or mismatched calibration/profile.

The tuned `ffmpeg v360` workflow was faster, stable frame-to-frame, and good enough for Final Cut reframing.

## Scope

This project is intentionally narrow:

- Samsung Gear 360 SM-R210
- 2560x1280 dual-fisheye video
- equirectangular monoscopic output
- Final Cut-friendly metadata tagging

It is not a universal 360 stitcher.

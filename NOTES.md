# Notes

These notes capture the reasoning behind the current SM-R210 conversion workflow.

## Best Setting Found

```text
v360=input=dfisheye:output=equirect:ih_fov=190.5:iv_fov=191:interp=lanczos
```

The source test clip was Samsung Gear 360 2017 / SM-R210 footage:

- Source projection: dual fisheye, side by side
- Source resolution: `2560x1280`
- Frame rate: `30000/1001` / 29.97 fps

## Benchmark

Same 10-second sample, same H.264 encode settings:

- Default interpolation: `9.90s`
- Lanczos interpolation: `12.52s`

Lanczos was about 26% slower, but visually sharper enough to keep.

## Final Cut Pro

Final Cut correctly recognized tagged outputs as:

- Projection: `Equirectangular`
- Stereoscopic mode: `Monoscopic`

Recommended edit setup:

- normal 16:9 project
- `1080p`
- `29.97p`
- reframe the 360 clip in Final Cut

## Hugin / gear360pano Findings

The old `gear360pano` workflow was tested and rejected for this use case.

Problems:

- too slow
- frame-by-frame stitching pipeline
- seam/blend instability risk
- calibration/profile did not match the footage well
- horizon could not be corrected consistently with a simple roll adjustment

Local script changes that were tried:

- replaced Linux-oriented script path detection with `BASH_SOURCE`-based path detection
- added `/Applications/Hugin/tools_mac` to `PATH`
- added Hugin's bundled ExifTool directory to `PATH`
- disabled Hugin GPU flags on macOS
- guarded `notify-send` calls so macOS would not fail
- used macOS-compatible `mktemp` templates
- improved filename and output path quoting
- allowed explicit output paths
- used absolute PTO template paths
- fell back to Hugin `enblend` if `multiblend` was missing
- added experimental `--save-masks` / `--load-masks`
- attempted fixed seam mask reuse for `enblend`

None of that made the Hugin route preferable to tuned `ffmpeg v360`.

## Related Projects

Useful references:

```text
https://ffmpeg.org/ffmpeg-filters.html#v360
https://huginpanorama.com/
https://hugin.sourceforge.io/
https://github.com/stitchEm/stitchEm
https://github.com/stitchEm/stitchEm/releases
https://github.com/cynricfu/dual-fisheye-video-stitching
https://github.com/drNoob13/fisheyeStitcher
https://github.com/raboof/dualfisheye2equirectangular
https://github.com/BloodyAnt/dualfisheye_to_equirectangular
https://gyroflow.xyz/
https://github.com/gyroflow/gyroflow
https://docs.gyroflow.xyz/app/getting-started/lens-calibration
https://github.com/gyroflow/lens_profiles
```

## Future Tool Idea

A more serious open-source stitcher would likely be:

```text
camera profile + ffmpeg IO + OpenCV/GPU remap/blend + preview/tuning UI
```

It would need per-camera profiles for:

- lens centers
- lens FOVs
- distortion coefficients
- per-lens rotations
- seam position
- feather width
- color/exposure correction

That could be useful for old or unsupported 360 cameras, but it is a separate project.

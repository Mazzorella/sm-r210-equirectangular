# Changelog

All notable changes to this project will be documented in this file.

This project uses Semantic Versioning.

## v0.1.0 - 2026-06-04

Initial usable release.

### Added

- Batch conversion for Samsung Gear 360 SM-R210 dual-fisheye MP4 files.
- Tuned ffmpeg `v360` preset: `ih_fov=190.5:iv_fov=191:interp=lanczos`.
- H.264 MP4 output by default.
- Optional ProRes 422 MOV output for Final Cut workflows.
- Google spherical/equirectangular metadata tagging with ExifTool.
- Progress display with file count, progress bar, percentage, and elapsed/total time.
- Safe resume behavior using temporary outputs and cleanup for interrupted runs.
- Documentation for Final Cut import/reframe workflow and the tested SM-R210 settings.

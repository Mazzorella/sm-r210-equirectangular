#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

INPUT_FOV_H="190.5"
INPUT_FOV_V="191"
INTERP="lanczos"
CRF="18"
PRESET="medium"
FORCE="no"
OUTPUT_MODE="h264"

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME [options] INPUT_FOLDER OUTPUT_FOLDER

Convert Samsung Gear 360 SM-R210 dual-fisheye MP4 files to equirectangular 360 video.

Options:
  --prores        Output ProRes 422 MOV files instead of H.264 MP4
  --force         Overwrite existing outputs
  --crf VALUE     H.264 CRF quality value (default: 18)
  --preset VALUE  H.264 preset (default: medium)
  -h, --help      Show this help

Current v360 preset:
  input=dfisheye:output=equirect:ih_fov=$INPUT_FOV_H:iv_fov=$INPUT_FOV_V:interp=$INTERP
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

find_exiftool() {
  if command -v exiftool >/dev/null 2>&1; then
    command -v exiftool
    return 0
  fi

  local hugin_exiftool="/Applications/Hugin/HuginStitchProject.app/Contents/Resources/ExifTool/exiftool"
  if [ -x "$hugin_exiftool" ]; then
    printf '%s\n' "$hugin_exiftool"
    return 0
  fi

  return 1
}

tag_360_metadata() {
  local file="$1"
  local width="$2"
  local height="$3"

  if [ -z "${EXIFTOOL:-}" ]; then
    echo "Warning: exiftool not found; skipping 360 metadata for $file" >&2
    return 0
  fi

  "$EXIFTOOL" \
    -overwrite_original \
    -XMP-GSpherical:Spherical=true \
    -XMP-GSpherical:Stitched=true \
    -XMP-GSpherical:StitchingSoftware="ffmpeg v360" \
    -XMP-GSpherical:ProjectionType=equirectangular \
    -XMP-GSpherical:StereoMode=mono \
    -XMP-GSpherical:FullPanoWidthPixels="$width" \
    -XMP-GSpherical:FullPanoHeightPixels="$height" \
    -XMP-GSpherical:CroppedAreaImageWidthPixels="$width" \
    -XMP-GSpherical:CroppedAreaImageHeightPixels="$height" \
    -XMP-GSpherical:CroppedAreaLeftPixels=0 \
    -XMP-GSpherical:CroppedAreaTopPixels=0 \
    "$file" >/dev/null
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prores)
      OUTPUT_MODE="prores"
      shift
      ;;
    --force)
      FORCE="yes"
      shift
      ;;
    --crf)
      [ "$#" -ge 2 ] || die "--crf requires a value"
      CRF="$2"
      shift 2
      ;;
    --preset)
      [ "$#" -ge 2 ] || die "--preset requires a value"
      PRESET="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 2 ] || { usage; exit 1; }

INPUT_DIR="${1%/}"
OUTPUT_DIR="${2%/}"

[ -d "$INPUT_DIR" ] || die "input folder does not exist: $INPUT_DIR"
mkdir -p "$OUTPUT_DIR"

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg is required"
command -v ffprobe >/dev/null 2>&1 || die "ffprobe is required"
EXIFTOOL="$(find_exiftool || true)"

FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname '*.mp4' \) -print0)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No .MP4/.mp4 files found in: $INPUT_DIR"
  exit 0
fi

echo "Input folder:  $INPUT_DIR"
echo "Output folder: $OUTPUT_DIR"
echo "Files found:   ${#FILES[@]}"
echo "Mode:          $OUTPUT_MODE"
echo

for input in "${FILES[@]}"; do
  filename="$(basename "$input")"
  stem="${filename%.*}"

  if [ "$OUTPUT_MODE" = "prores" ]; then
    output="$OUTPUT_DIR/${stem}_equirect.mov"
    video_args=(-c:v prores_ks -profile:v 2 -pix_fmt yuv422p10le -vendor apl0)
    audio_args=(-c:a pcm_s16le)
  else
    output="$OUTPUT_DIR/${stem}_equirect.mp4"
    video_args=(-c:v libx264 -crf "$CRF" -preset "$PRESET")
    audio_args=(-c:a aac -b:a 192k)
  fi

  if [ -e "$output" ] && [ "$FORCE" != "yes" ]; then
    echo "Skipping existing output: $output"
    continue
  fi

  echo "Converting: $filename"
  ffmpeg -y \
    -i "$input" \
    -vf "v360=input=dfisheye:output=equirect:ih_fov=${INPUT_FOV_H}:iv_fov=${INPUT_FOV_V}:interp=${INTERP}" \
    "${video_args[@]}" \
    "${audio_args[@]}" \
    "$output"

  dimensions="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$output")"
  width="${dimensions%x*}"
  height="${dimensions#*x}"

  tag_360_metadata "$output" "$width" "$height"
  echo "Wrote: $output"
  echo
done

echo "Done."

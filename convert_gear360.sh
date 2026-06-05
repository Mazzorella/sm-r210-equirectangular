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
PROGRESS_BAR_WIDTH=24
ACTIVE_TEMP_OUTPUT=""

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

cleanup_active_temp() {
  if [ -n "$ACTIVE_TEMP_OUTPUT" ] && [ -e "$ACTIVE_TEMP_OUTPUT" ]; then
    rm -f "$ACTIVE_TEMP_OUTPUT"
  fi
}

handle_interrupt() {
  echo
  echo "Interrupted. Removing active temporary output." >&2
  cleanup_active_temp
  exit 130
}

trap handle_interrupt INT TERM

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

format_seconds() {
  local seconds="$1"
  local whole=$((seconds))
  local hours=$((whole / 3600))
  local minutes=$(((whole % 3600) / 60))
  local secs=$((whole % 60))

  if [ "$hours" -gt 0 ]; then
    printf '%d:%02d:%02d' "$hours" "$minutes" "$secs"
  else
    printf '%d:%02d' "$minutes" "$secs"
  fi
}

progress_bar() {
  local percent="$1"
  local filled=$((percent * PROGRESS_BAR_WIDTH / 100))
  local empty=$((PROGRESS_BAR_WIDTH - filled))
  local bar=""
  local i

  for ((i = 0; i < filled; i++)); do
    bar="${bar}#"
  done
  for ((i = 0; i < empty; i++)); do
    bar="${bar}-"
  done

  printf '[%s]' "$bar"
}

get_duration_us() {
  local file="$1"
  local duration

  duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file")"
  awk -v duration="$duration" 'BEGIN { printf "%.0f", duration * 1000000 }'
}

run_ffmpeg_with_progress() {
  local index="$1"
  local total="$2"
  local input="$3"
  local label="$4"
  local duration_us="$5"
  shift 5

  local line key value out_time_us percent elapsed total_seconds
  total_seconds=$((duration_us / 1000000))

  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"

    case "$key" in
      out_time_us)
        out_time_us="$value"
        if [ "$duration_us" -gt 0 ] && [ "$out_time_us" -ge 0 ] 2>/dev/null; then
          percent=$((out_time_us * 100 / duration_us))
          [ "$percent" -gt 100 ] && percent=100
          elapsed="$(format_seconds $((out_time_us / 1000000)))"
          printf '\r[%d/%d] %-35s %s %3d%% (%s / %s)' \
            "$index" "$total" "$label" "$(progress_bar "$percent")" "$percent" "$elapsed" "$(format_seconds "$total_seconds")"
        fi
        ;;
      progress)
        if [ "$value" = "end" ]; then
          printf '\r[%d/%d] %-35s %s 100%% (%s / %s)\n' \
            "$index" "$total" "$label" "$(progress_bar 100)" "$(format_seconds "$total_seconds")" "$(format_seconds "$total_seconds")"
        fi
        ;;
    esac
  done < <(ffmpeg -hide_banner -loglevel error -nostats -y "$@" -progress pipe:1)
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
rm -f "$OUTPUT_DIR"/*_equirect.tmp.mp4 "$OUTPUT_DIR"/*_equirect.tmp.mov

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

total_files="${#FILES[@]}"
converted=0
skipped=0
failed=0

for index in "${!FILES[@]}"; do
  input="${FILES[$index]}"
  filename="$(basename "$input")"
  stem="${filename%.*}"
  file_number=$((index + 1))

  if [ "$OUTPUT_MODE" = "prores" ]; then
    output="$OUTPUT_DIR/${stem}_equirect.mov"
    temp_output="$OUTPUT_DIR/${stem}_equirect.tmp.mov"
    video_args=(-c:v prores_ks -profile:v 2 -pix_fmt yuv422p10le -vendor apl0)
    audio_args=(-c:a pcm_s16le)
  else
    output="$OUTPUT_DIR/${stem}_equirect.mp4"
    temp_output="$OUTPUT_DIR/${stem}_equirect.tmp.mp4"
    video_args=(-c:v libx264 -crf "$CRF" -preset "$PRESET")
    audio_args=(-c:a aac -b:a 192k)
  fi

  if [ -e "$output" ] && [ "$FORCE" != "yes" ]; then
    printf '[%d/%d] Skipping existing output: %s\n' "$file_number" "$total_files" "$output"
    skipped=$((skipped + 1))
    continue
  fi

  duration_us="$(get_duration_us "$input")"
  rm -f "$temp_output"
  ACTIVE_TEMP_OUTPUT="$temp_output"

  if run_ffmpeg_with_progress "$file_number" "$total_files" "$input" "$filename" "$duration_us" \
    -i "$input" \
    -vf "v360=input=dfisheye:output=equirect:ih_fov=${INPUT_FOV_H}:iv_fov=${INPUT_FOV_V}:interp=${INTERP}" \
    "${video_args[@]}" \
    "${audio_args[@]}" \
    "$temp_output"; then
    :
  else
    echo
    echo "Error: ffmpeg failed for $input" >&2
    cleanup_active_temp
    ACTIVE_TEMP_OUTPUT=""
    failed=$((failed + 1))
    continue
  fi

  if ! dimensions="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$temp_output")"; then
    echo "Error: could not read output dimensions for $temp_output" >&2
    cleanup_active_temp
    ACTIVE_TEMP_OUTPUT=""
    failed=$((failed + 1))
    continue
  fi
  width="${dimensions%x*}"
  height="${dimensions#*x}"

  if ! tag_360_metadata "$temp_output" "$width" "$height"; then
    echo "Error: metadata tagging failed for $temp_output" >&2
    cleanup_active_temp
    ACTIVE_TEMP_OUTPUT=""
    failed=$((failed + 1))
    continue
  fi

  if ! mv -f "$temp_output" "$output"; then
    echo "Error: could not move temporary output into place: $output" >&2
    cleanup_active_temp
    ACTIVE_TEMP_OUTPUT=""
    failed=$((failed + 1))
    continue
  fi

  ACTIVE_TEMP_OUTPUT=""
  converted=$((converted + 1))
  echo "Wrote: $output"
  echo
done

echo "Done. Converted: $converted, skipped: $skipped, failed: $failed."
[ "$failed" -eq 0 ] || exit 1

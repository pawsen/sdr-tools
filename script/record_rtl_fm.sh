#!/usr/bin/env bash
#
# Real-time FM/AM demodulation using rtl_fm with direct parameter passthrough
# - Supports both file output and direct audio playback


show_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -f FREQ        Center frequency (e.g., 433.92M or 90.8M)
  -s RATE        Sample rate (default: 24k for AM/FM, 170k for WBFM)
  -M MODULATION  am/fm/wbfm (default: am)
  -g GAIN        Gain setting (omit for auto gain)
  -r RESAMPLE    Resample rate (default: equal to sample rate, 32k for WBFM)
                 There seems a bug is resample>sample
  -o DIR         Output directory (default: recordings/)
  -p             Play audio instead of saving to file
  -t             Add timestamp to output filename
  -h             Show this help

RTL_FM_OPTIONS:
  Additional parameters passed directly to rtl_fm after --
  Example: $0 -f 433.92M -- -p 0.5 -E dc

Examples:
  $0 -f 433.92M -g 20            # Basic AM demodulation
  $0 -f 90.8M -m wbfm -p         # Play broadcast FM (dr p1, gladsaxe)
  $0 -f 144.39M -g 20 -- -E dc   # With DC offset correction
EOF
}

# Defaults
FREQ="433.92M"
SAMPLE_RATE=""
MODULATION="am"
GAIN=""  # "0" disables gain. In rtl_sdr -g 0 is automatic. Not for rtl_fm
OUTPUT_DIR="recordings"
RESAMPLE=""
TIMESTAMP=false
PLAY=false
EXTRA_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f) FREQ="$2"; shift 2 ;;
    -s) SAMPLE_RATE="$2"; shift 2 ;;
    -M) MODULATION="$2"; shift 2 ;;
    -g) GAIN="$2"; shift 2 ;;
    -r) RESAMPLE="$2"; shift 2 ;;
    -o) OUTPUT_DIR="$2"; shift 2 ;;
    -p) PLAY=true; shift ;;
    -t) TIMESTAMP=true; shift ;;
    -h) show_help; exit 0 ;;
    --) shift; EXTRA_ARGS=("$@"); break ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Set WBFM defaults if selected
if [[ "$MODULATION" == "wbfm" ]]; then
  # -M wbfm says to use wideband FM mode, but this is really a shortcut for a tweaked narrowband FM mode. It expands fully into
  # -M fm -s 170k -A fast -r 32k -l 0 -E deemp
  # https://web.archive.org/web/20230603213739/http://kmkeen.com/rtl-demod-guide/
  SAMPLE_RATE=${SAMPLE_RATE:-"170k"}
  RESAMPLE="32k"
  WBFM_OPTS=(-A fast -l 0 -E deemp)
else
  WBFM_OPTS=()
  SAMPLE_RATE=${SAMPLE_RATE:-"24k"}
  RESAMPLE=${RESAMPLE:-"$SAMPLE_RATE"}
fi

# Prepare output filename if not playing
if ! $PLAY; then
  mkdir -p "$OUTPUT_DIR" || { echo "Error: Cannot create output directory"; exit 1; }

  if $TIMESTAMP; then
    OUTPUT_FILE="${OUTPUT_DIR}/demod_${MODULATION}_$(date +%Y%m%d_%H%M%S).wav"
  else
    OUTPUT_FILE="${OUTPUT_DIR}/demod_${MODULATION}.wav"
  fi
fi

# File size monitor
show_size() {
  while true; do
    size=$(du -h "$OUTPUT_FILE" 2>/dev/null | cut -f1 || echo "0")
    echo -ne "Recording... File size: $size\r"
    sleep 1
  done
}

# Build base command
CMD=(rtl_fm -f "$FREQ" -M "$MODULATION" -s "$SAMPLE_RATE")
# Add gain only if specified
[[ -n "$GAIN" ]] && CMD+=(-g "$GAIN")
# complete
CMD+=(-r "$RESAMPLE" "${WBFM_OPTS[@]}" "${EXTRA_ARGS[@]}" -)

echo "Demodulating $FREQ (Ctrl+C to stop)"
echo "Modulation: $MODULATION"
echo "Sample rate: $SAMPLE_RATE"
echo "Audio rate: $RESAMPLE"
echo "Gain: $GAIN"
[[ ${#EXTRA_ARGS[@]} -gt 0 ]] && echo "Extra args: ${EXTRA_ARGS[*]}"
echo -n "CMD: "
printf "  %q " "${CMD[@]}"
echo -e "\n"

# Handle interrupts properly. Because of the pipe between rtl_fm and sox/play
handle_interrupt() {
    echo -e "\nReceived interrupt - stopping gracefully..."
    # Kill only if processes exist
    if jobs -p; then
        echo "Stopping background processes..."
        kill $(jobs -p)
    fi
    exit 0
}
handle_file_write() {
    echo -e "\nFinishing file write..."
    wait  # Let the current pipeline finish
    echo "Capture saved to $OUTPUT_FILE"
    exit 0
}

if $PLAY; then
  echo "Mode: Playing live audio"
  trap handle_interrupt INT TERM
  "${CMD[@]}" | play -r "$RESAMPLE" -t raw -e s -b 16 -c 1 -V1 -
else
  echo "Output: $OUTPUT_FILE"
  show_size &
  trap handle_file_write INT
  "${CMD[@]}" | sox -t raw -r "$RESAMPLE" -e signed -b 16 -c 1 - "$OUTPUT_FILE"
fi

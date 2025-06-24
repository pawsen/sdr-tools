#!/usr/bin/env bash
#
# Continuous RF capture using RTL-SDR
# Usage: ./capture_433mhz.sh [-f FREQ] [-s RATE] [-g GAIN] [-d SEC] [-m] [-l LABEL] [-o DIR]
# Output: Raw I/Q data as 8bit unsigned int (.cu8 format)
# - filename formatted for importing to rtl_433
#
# Note on numeric formats:
# - Frequency (-f) and sample rate (-s) should be given as plain numbers
# - Scientific notation is accepted (e.g., 433.92e6 or 1.026e6)
# - Do not include unit suffixes (MHz/kHz, etc.) - these will be auto-formatted

# Default values
# - Sample rate: 1.026e6 (1.026MS/s), sufficient for most OOK/ASK devices
# - Nyquist: Captures signals up to 500kHz (1/2 sample rate)
# - rtl-sdr can do 2.4MS/s
FREQ="433.92e6"  # MHz
SAMPLE_RATE="1.026e6"  # Msps
GAIN="0"    # 0 for auto
DURATION="" # Optional
NO_TIMESTAMP=true
LABEL="" # optional
OUTPUT_DIR="."

usage() {
  echo "Usage: $0 [-f FREQ] [-s RATE] [-g GAIN] [-d SEC] [-m] [-l LABEL] [--timestamp] [-o DIR]"
}
die() {
  echo "Error: $1" >&2
  usage
  exit 1
}

show_help() {
    cat <<EOF
$(usage)
Options:
  -f FREQ    Center frequency in Hz (e.g., 433.92e6 or 433920000)
             Do not include MHz/kHz units
  -s RATE    Sample rate in Hz (e.g., 1.026e6 or 1026000)
             Do not include MSps/KSps units
  -g GAIN    Gain setting (0 for auto)
  -d SEC     Duration in seconds (optional)
  -m         Save metadata JSON file
  -l LABEL   Optional recording label
  -o DIR     Output directory (default: current dir)
  -h         Show this help

Examples:
  $0 -f 433.92e6 -s 1.026e6 -g 20       # 433.92MHz, 1.026MSps, 20dB gain
  $0 -f 868e6 -s 250e3 -d 10 -l "test"  # 868MHz, 250KSps, 10sec, labeled "test"
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
      -f) FREQ="$2"; shift 2 ;;
      -s) SAMPLE_RATE="$2"; shift 2 ;;
      -g) GAIN="$2"; shift 2 ;;
      -d) DURATION="$2"; shift 2 ;;
      -m) SAVE_METADATA=true; shift ;;
      -l) LABEL="$2"; shift 2 ;;
      -o) OUTPUT_DIR="$2"; shift 2 ;;
      -h) show_help ;exit 0 ;;
      --timestamp) NO_TIMESTAMP=false; shift ;;
      *) die "Unknown option: $1" ;;
  esac
done

# Prepare output directory
OUTPUT_DIR="${OUTPUT_DIR%/}"
if [ -e "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
  die "'$OUTPUT_DIR' exists but is not a directory"
fi

mkdir -p "$OUTPUT_DIR" || die "Failed to create output directory"
[ -w "$OUTPUT_DIR" ] || die "Output directory is not writable"

# Format filename components
# Append unit suffix to frequency (MHz) and sample rate (Msps)
FREQ_FMT=$(awk -v f="$FREQ" 'BEGIN {printf "%.3fMHz", f/1e6}')
SAMPLE_FMT=$(awk -v s="$SAMPLE_RATE" 'BEGIN {printf "%.3fMsps", s/1e6}')
GAIN_FMT="${GAIN}dB"
LABEL_SAFE=$(echo "$LABEL" | sed 's/[^a-zA-Z0-9_-]/_/g')

# Build filename
FILENAME="${LABEL_SAFE:+${LABEL_SAFE}_}capture_${FREQ_FMT}_${SAMPLE_FMT}_${GAIN_FMT}"
[ "$NO_TIMESTAMP" != true ] && FILENAME+="_$(date +%Y%m%d_%H%M%S)"
OUTPUT_FILE="${OUTPUT_DIR}/${FILENAME}.cu8"

echo "Starting SDR capture"
echo "Frequency: $FREQ"
echo "Sample Rate: $SAMPLE_RATE"
echo "Gain: $GAIN"
[ -n "$DURATION" ] && echo "Duration: $DURATION sec"
echo "Output: $OUTPUT_FILE"
echo "Press Ctrl+C to stop early."

# File size monitor
show_size() {
  while true; do
    size=$(du -h "$OUTPUT_FILE" 2>/dev/null | cut -f1 || echo "0")
    echo -ne "Recording... File size: $size\r"
    sleep 1
  done
}

# Start recording
show_size &
MONITOR_PID=$!

if [ -n "$DURATION" ]; then
  # Capture for N seconds: calculate samples = (int) sample_rate * duration
  # 1 sample = 2 bytes (1 I + 1 Q)
  # Convert scientific notation to plain numbers for bc
  RATE_PLAIN=$(echo "$SAMPLE_RATE" | sed 's/[eE]/*10^/;s/+//')
  SAMPLE_COUNT=$(echo "$RATE_PLAIN * $DURATION" | bc -l | awk '{printf "%.0f", $1}')
  rtl_sdr -f "$FREQ" -s "$SAMPLE_RATE" -g "$GAIN" -n "$SAMPLE_COUNT" "$OUTPUT_FILE"
else
  rtl_sdr -f "$FREQ" -s "$SAMPLE_RATE" -g "$GAIN" "$OUTPUT_FILE"
fi

STATUS=$?
kill $MONITOR_PID
echo -e "\nCapture complete. File saved to $OUTPUT_FILE"

# Calculate actual duration
FILESIZE=$(stat -c %s "$OUTPUT_FILE" 2>/dev/null || echo 0)
RATE_PLAIN=$(echo "$SAMPLE_RATE" | sed 's/[eE]/*10^/;s/+//')
DURATION_ACTUAL=$(echo "$FILESIZE / ($RATE_PLAIN * 2)" | bc -l)
echo "Estimated recording duration: ${DURATION_ACTUAL}s"

# Save metadata if requested
if [ $STATUS -eq 0 ] && [ "$SAVE_METADATA" = true ]; then
  cat >"${OUTPUT_FILE%.cu8}.json" <<EOF
{
  "frequency": "$FREQ",
  "sample_rate": "$SAMPLE_RATE",
  "gain": "$GAIN",
  "duration_sec": "${DURATION:-null}",
  "timestamp": "$(date +%Y%m%d_%H%M%S)",
  "filename": "$(basename "$OUTPUT_FILE")"
}
EOF
  echo "Metadata saved to ${OUTPUT_FILE%.cu8}.json"
elif [ $STATUS -ne 0 ]; then
  echo "Error: rtl_sdr failed (exit code $STATUS)"
  rm -f "$OUTPUT_FILE"
fi

exit $STATUS

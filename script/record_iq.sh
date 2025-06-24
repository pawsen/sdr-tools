#!/usr/bin/env bash
#
# Continuous 433MHz RF capture using RTL-SDR
# - Sample rate: 1.026e6M (1MS/s), sufficient for most OOK/ASK devices
# - Nyquist: Captures signals up to 500kHz (1/2 sample rate)
# - rtl-sdr can do 2.4MS/s
# Usage: ./capture_433mhz.sh (Ctrl+C to stop)
# Output: Raw I/Q data as 8bit unsigned int, saved as .cu8 for rtl_433 compatibility

# Default values
FREQ="433.92e6"
SAMPLE_RATE="1.026e6"
GAIN="0"  # 0 for auto
DURATION=""  # Optional
NO_TIMESTAMP=true
LABEL=""  # prepend the output file
OUTPUT_DIR="."  # default: current directory

die() {
    echo "Error: $1" >&2
    echo "Usage: $0 [-f|--freq FREQ] [-s|--sample-rate RATE] [-g|--gain GAIN] [-d|--duration SEC] [-m|--save-metadata]"
    exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--freq)
      [[ -z "$2" ]] && die "Missing frequency"
      FREQ="$2"
      shift 2
      ;;
    -s|--sample-rate)
      [[ -z "$2" ]] && die "Missing sample rate"
      SAMPLE_RATE="$2"
      shift 2
      ;;
    -g|--gain)
      [[ -z "$2" ]] && die "Missing gain"
      GAIN="$2"
      shift 2
      ;;
    -d|--duration)
      [[ -z "$2" ]] && die "Missing duration"
      DURATION="$2"
      shift 2
      ;;
    -m|--save-metadata)
      SAVE_METADATA=true
      shift
      ;;
    --timestamp)
      NO_TIMESTAMP=false
      shift
      ;;
    -l|--label)
      LABEL="$2"
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [-f|--freq FREQ] [-s|--sample-rate RATE] [-g|--gain GAIN] [-d|--duration SEC] [-m|--save-metadata]"
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

# Remove trailing slashes from OUTPUT_DIR
OUTPUT_DIR="${OUTPUT_DIR%/}"
# Validate or create output directory
if [ -e "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: '$OUTPUT_DIR' exists but is not a directory." >&2
  exit 1
fi

if [ ! -e "$OUTPUT_DIR" ]; then
  if ! mkdir -p "$OUTPUT_DIR"; then
    echo "Error: Failed to create output directory '$OUTPUT_DIR'." >&2
    exit 1
  fi
fi

if [ ! -w "$OUTPUT_DIR" ]; then
  echo "Error: Output directory '$OUTPUT_DIR' is not writable." >&2
  exit 1
fi

# Append unit suffix to frequency (MHz) and sample rate (Msps)
FREQ_FMT=$(echo "$FREQ" | awk '{printf "%.3fMHz", $1/1e6}')
SAMPLE_FMT=$(echo "$SAMPLE_RATE" | awk '{printf "%.3fMsps", $1/1e6}')
GAIN_FMT="${GAIN}dB"

# Sanitize optional label
LABEL_SAFE=$(echo "$LABEL" | sed 's/[^a-zA-Z0-9_-]/_/g')
# Build extra part: gain + optional label
EXTRA_PARTS="${GAIN_FMT}"
[ -n "$LABEL_SAFE" ] && EXTRA_PARTS="${EXTRA_PARTS}_${LABEL_SAFE}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
# Assemble filename parts
FILENAME_PARTS=""
[ -n "$LABEL_SAFE" ] && FILENAME_PARTS="${LABEL_SAFE}_"
FILENAME_PARTS+="capture_${FREQ_FMT}_${SAMPLE_FMT}_${GAIN_FMT}"
[ "$NO_TIMESTAMP" != true ] && FILENAME_PARTS+="_${TIMESTAMP}"
OUTPUT_FILE="${OUTPUT_DIR}/${FILENAME_PARTS}.cu8"

METADATA_FILE="${OUTPUT_FILE%.iq}.json"

echo "Starting SDR capture"
echo "Frequency: $FREQ"
echo "Sample Rate: $SAMPLE_RATE"
echo "Gain: $GAIN"
if [ -n "$DURATION" ]; then
  echo "Duration: $DURATION sec"
fi
echo "Output: $OUTPUT_FILE"
echo "Press Ctrl+C to stop early."

# Calculate file size in background
function show_size() {
  while true; do
    sleep 1
    size=$(du -h "$OUTPUT_FILE" 2>/dev/null | cut -f1)
    [ -z "$size" ] && size="0"
    echo -ne "Recording... File size: $size\r"
  done
}

show_size &
MONITOR_PID=$!

# Start recording (with or without duration)
if [ -n "$DURATION" ]; then
  # Capture for N seconds: calculate samples = (int) sample_rate * duration
  # 1 sample = 2 bytes (1 I + 1 Q)
  # Convert scientific notation to plain numbers for bc
  RATE_PLAIN=$(echo "$SAMPLE_RATE" | sed 's/[eE]/*10^/' | sed 's/+//')
  SAMPLE_COUNT=$(echo "$RATE_PLAIN * $DURATION" | bc -l | awk '{printf "%.0f", $1}')
  rtl_sdr -f "$FREQ" -s "$SAMPLE_RATE" -g "$GAIN" -n "$SAMPLE_COUNT" "$OUTPUT_FILE"
else
  rtl_sdr -f "$FREQ" -s "$SAMPLE_RATE" -g "$GAIN" "$OUTPUT_FILE"
fi

# Capture exit status
STATUS=$?

kill $MONITOR_PID
echo -e "\nCapture complete. File saved to $OUTPUT_FILE"

FILESIZE=$(stat -c %s "$OUTPUT_FILE")  # file size in bytes
RATE_PLAIN=$(echo "$SAMPLE_RATE" | sed 's/[eE]/*10^/' | sed 's/+//')
DURATION_ACTUAL=$(echo "$FILESIZE / ($RATE_PLAIN * 2)" | bc -l)
echo "Estimated recording duration: ${DURATION_ACTUAL}s"

# If rtl_sdr succeeded, write metadata
if [ $STATUS -eq 0 ] && [ "$SAVE_METADATA" = true ]; then
  cat > "$METADATA_FILE" <<EOF
{
  "frequency": "$FREQ",
  "sample_rate": "$SAMPLE_RATE",
  "gain": "$GAIN",
  "duration_sec": "${DURATION:-null}",
  "timestamp": "$TIMESTAMP",
  "filename": "$OUTPUT_FILE"
}
EOF
  echo "Metadata saved to $METADATA_FILE"
fi
if [ $STATUS -ne 0 ]; then
  echo "Error: rtl_sdr failed (exit code $STATUS)."
  rm -f "$OUTPUT_FILE"  # Optional: remove partial IQ file
fi

#!/bin/bash

# Default values
LABEL="capture"
FREQ="433.92MHz"
SAMPLE_RATE="250ksps"
OUTPUT_DIR="recordings"
declare -a OUTPUT_TYPES=()
declare -a EXTRA_ARGS=()

# Supported output formats
VALID_FORMATS=("cu8" "cs16" "cf32" "am.s16" "am.f32" "fm.s16" "fm.f32")

show_help() {
    cat <<EOF

Usage: $0 [-l LABEL] [-f FREQ] [-s SAMPLE_RATE] [-d DIR] [-W FORMAT]... [EXTRA_ARGS]
Wrapper for rtl_433 with configurable output formats

Options:
  -l LABEL        Output file label (default: capture)
  -f FREQ         Frequency (default: 433.92MHz)
                  (fractional) number suffixed with 'M', 'Hz', 'kHz', 'MHz', or 'GHz'.
  -s SAMPLE_RATE  Sample rate (default: 250ksps)
                  (fractional) number suffixed with 'k', 'sps', 'ksps', 'Msps', or 'Gsps'.
  -d DIR          Output directory (default: recordings)
  -W FORMAT       Output format (may be repeated for multiple formats)

Supported formats:
  cu8       Unsigned 8-bit I/Q samples
  cs16      Signed 16-bit I/Q samples
  cf32      Float 32-bit I/Q samples
Modulated raw files. Use sox to convert to wav
  am.s16    Signed 16-bit AM samples
  am.f32    Float 32-bit AM samples
  fm.s16    Signed 16-bit FM samples
  fm.f32    Float 32-bit FM samples

Example:
  $0 -l mycapture -f 868MHz -s 500ksps -d /data/recordings -W cu8 -W fm.f32 -g 20 -A

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l) LABEL="$2"; shift 2 ;;
        -f) FREQ="$2"; shift 2 ;;
        -s) SAMPLE_RATE="$2"; shift 2 ;;
        -d) OUTPUT_DIR="$2"; shift 2 ;;
        -W)
            if [[ " ${VALID_FORMATS[@]} " =~ " $2 " ]]; then
                OUTPUT_TYPES+=("$2")
                shift 2
            else
                echo "Error: Unsupported format '$2'" >&2
                show_help >&2
                exit 1
            fi
            ;;
        -h) show_help; exit 0 ;;
        *) EXTRA_ARGS+=("$1"); shift ;;
    esac
done

# Default to cu8 if no formats specified
[ ${#OUTPUT_TYPES[@]} -eq 0 ] && OUTPUT_TYPES=("cu8")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Build command array
CMD=(
    rtl_433
    -f "$FREQ"
    -s "$SAMPLE_RATE"
    "${EXTRA_ARGS[@]}"
)

# Add output file arguments
for format in "${OUTPUT_TYPES[@]}"; do
    CMD+=(-W "${OUTPUT_DIR}/${LABEL}_${FREQ}_${SAMPLE_RATE}.${format}")
done

# Execute
exec "${CMD[@]}"

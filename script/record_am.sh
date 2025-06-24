#!/usr/bin/env bash

# Real-time 433MHz FM/AM demodulation using rtl_fm
# - Sample rate: 170k (captures 85kHz bandwith: Nyquist 1/2 sample rate)
# - Most 433MHz devices use ≤50kHz BW (OOK/FSK modulation)
# - 170k provides buffer for drift/adjacent signals
# - Demodulates to audible frequencies (24kHz WAV)
# Usage: ./record_am.sh (Ctrl+C to stop)
# Process to audio offline. Remember to set a sample_rate that match the capture!
#  cat capture.iq | record_am.sh
#
# Output: timestamped .wav file with baseband audio
# Requires: rtl-sdr, sox
#
#

FREQ=$(1:-433.92M)
SAMPLE_RATE=$(2:-170k)
GAIN="36"
OUTPUT="demod_$(date +%Y%m%d_%H%M%S).wav"

echo "Demodulating $FREQ (Ctrl+C to stop)"
echo "Output: $OUTPUT"

rtl_fm -f "$FREQ" -M am -s "$SAMPLE_RATE" -g $GAIN -r 24k - | \
sox -t raw -r 24k -e signed -b 16 -c 1 - "$OUTPUT"

echo -e "\nCapture saved to $OUTPUT"

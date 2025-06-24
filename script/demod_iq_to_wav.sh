#!/usr/bin/env bash

# ------------ Config ------------
INPUT_IQ="$1"             # e.g., input.iq
IQ_RATE=2400000           # Must match how you recorded it
IQ_RATE=1000000           # Must match how you recorded it
AUDIO_RATE=48000          # Output WAV sample rate
OUTPUT_WAV="${INPUT_IQ%.*}_demod.wav"

# ------------ Checks ------------
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: $0 recording.iq"
  echo
  echo "Demodulates AM/OOK-modulated signals from an IQ file."
  echo "The output is a WAV audio file you can view in Audacity or URH."
  exit 0
fi
if [[ -z "$INPUT_IQ" || ! -f "$INPUT_IQ" ]]; then
  echo "Usage: $0 recording.iq"
  exit 1
fi

echo "📡 Demodulating $INPUT_IQ to $OUTPUT_WAV ..."

# ------------ Pipeline ------------
sox -t raw -r $IQ_RATE -es -b 8 -c 2 "$INPUT_IQ" -t raw - | \
csdr convert_u8_f | \
# csdr shift_addition_cc <frequency_offset_ratio> | \
csdr fir_decimate_cc 50 0.005 HAMMING | \
csdr amdemod_cf | \
csdr fastdcblock_ff | \
csdr agc_ff | \
csdr limit_ff | \
csdr convert_f_s16 | \
sox -t raw -r $AUDIO_RATE -e signed -b 16 -c 1 - "$OUTPUT_WAV"

# ---------------------- Processing Steps -----------------------
# convert_s8_f           : Converts signed 8-bit IQ samples to float
# shift_addition_cc      : Frequency shifts the signal to center desired carrier
# fastagc                : Basic gain control to stabilize input signal
# fir_decimate_cc        : Downsample and filter for AM bandwidth (~50 kHz)
# amdemod_cf             : AM demodulation (suitable for OOK/ASK)
# fastdcblock_ff         : Removes DC offset from demodulated audio
# agc_ff                 : Automatic gain control for demodulated signal
# limit_ff               : Avoids clipping spikes
# convert_f_s16          : Converts float to signed 16-bit audio
# sox                    : Writes to .wav for analysis in Audacity
# ---------------------------------------------------------------

echo "Done. Output: $OUTPUT_WAV"

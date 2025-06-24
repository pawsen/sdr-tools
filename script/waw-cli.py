"""Turn a recorded signal into a square wave

Take any value that is below 0 and set it to absolute minimum, and anything above 0 is set to
maximum.

This is usefull in recorded RF signals, making visual checking of bit lengths much easier and more
accurate. And effectively what the original source was doing before the signal got converted and
sent over RF - a 0 was a pin going LOW and a 1 was a pin going HIGH.

"""

import argparse
import os
import numpy as np
import scipy.io.wavfile as wav

def print_stats(label, samplerate, data):
    duration = len(data) / samplerate
    channels = data.shape[1] if data.ndim > 1 else 1
    print(f"\nStats for {label}:")
    print(f"  Sample rate : {samplerate} Hz")
    print(f"  Channels     : {channels}")
    print(f"  Duration     : {duration:.2f} seconds")
    print(f"  Data type    : {data.dtype}")
    print(f"  Max amplitude: {np.max(data)}")
    print(f"  Min amplitude: {np.min(data)}")

def square_to_peaks(sample):
    max_val = np.max(sample)
    min_val = np.min(sample)
    result = np.where(sample >= 0, max_val, min_val)
    return result.astype(sample.dtype)

def main():
    parser = argparse.ArgumentParser(description="Flatten audio signal to original max/min values.")
    parser.add_argument("input", help="Input WAV file")
    parser.add_argument("output", nargs="?", help="Output WAV file (optional)")
    parser.add_argument("--inplace", action="store_true", help="Overwrite the input file")

    args = parser.parse_args()
    input_file = args.input
    output_file = args.output

    # Decide output file
    if args.inplace:
        output_file = input_file
    elif not output_file:
        base, _ = os.path.splitext(input_file)
        output_file = f"{base}_square.wav"

    # Read input file
    rate, sample = wav.read(input_file)
    print_stats("Input", rate, sample)

    # Apply transformation
    squared_sample = square_to_peaks(sample)

    # Save result
    wav.write(output_file, rate, squared_sample)
    print(f"\nOutput written to: {output_file}")
    print_stats("Output", rate, squared_sample)

if __name__ == "__main__":
    main()

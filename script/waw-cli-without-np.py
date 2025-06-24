"""Turn a recorded signal into a square wave

Take any value that is below 0 and set it to absolute minimum, and anything above 0 is set to
maximum.

This is usefull in recorded RF signals, making visual checking of bit lengths much easier and more
accurate. And effectively what the original source was doing before the signal got converted and
sent over RF - a 0 was a pin going LOW and a 1 was a pin going HIGH.

This is without numpy, for easier usage on NixOS

"""


import argparse
import os
import wave
import array
import contextlib

def read_wav(filename):
    with contextlib.closing(wave.open(filename, 'rb')) as wf:
        params = wf.getparams()
        nchannels, sampwidth, framerate, nframes = params[:4]
        if sampwidth != 2:
            raise ValueError("Only 16-bit PCM WAV files are supported.")
        frames = wf.readframes(nframes)
        samples = array.array('h', frames)
        if os.name == 'nt':  # handle byte order on Windows
            samples.byteswap()
        return params, samples

def write_wav(filename, params, samples):
    with contextlib.closing(wave.open(filename, 'wb')) as wf:
        wf.setparams(params)
        if os.name == 'nt':
            samples.byteswap()
        wf.writeframes(samples.tobytes())

def print_stats(label, params, samples):
    nchannels, sampwidth, framerate, nframes = params[:4]
    duration = nframes / framerate
    print(f"\nStats for {label}:")
    print(f"  Sample rate : {framerate} Hz")
    print(f"  Channels     : {nchannels}")
    print(f"  Duration     : {duration:.2f} seconds")
    print(f"  Sample width : {sampwidth} bytes")
    print(f"  Max amplitude: {max(samples)}")
    print(f"  Min amplitude: {min(samples)}")

def square_to_peaks(samples):
    max_val = max(samples)
    min_val = min(samples)
    return array.array('h', [max_val if s >= 0 else min_val for s in samples])

def main():
    parser = argparse.ArgumentParser(description="Flatten audio signal to original max/min values (pure Python).")
    parser.add_argument("input", help="Input WAV file")
    parser.add_argument("output", nargs="?", help="Output WAV file (optional if not using --inplace)")
    parser.add_argument("--inplace", action="store_true", help="Overwrite the input file")

    args = parser.parse_args()

    input_file = args.input
    output_file = args.output

    if args.inplace:
        output_file = input_file
    elif not output_file:
        base, _ = os.path.splitext(input_file)
        output_file = f"{base}_square.wav"

    # Read input
    params, samples = read_wav(input_file)
    print_stats("Input", params, samples)

    # Process
    processed = square_to_peaks(samples)

    # Write output
    write_wav(output_file, params, processed)
    print(f"\nOutput written to: {output_file}")
    print_stats("Output", params, processed)

if __name__ == "__main__":
    main()

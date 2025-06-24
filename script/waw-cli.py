"""Turn a recorded signal into a square wave

Take any value that is below a threshold(0.1, default) and set it to absolute minimum, and anything
above 0 is set to maximum.

This is usefull in recorded RF signals, making visual checking of bit lengths much easier and more
accurate. And effectively what the original source was doing before the signal got converted and
sent over RF - a 0 was a pin going LOW and a 1 was a pin going HIGH.

"""

import argparse
import os
import numpy as np
import scipy.io.wavfile as wav
import matplotlib.pyplot as plt


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
    print(f"  Mean         : {np.mean(data):.4f}")
    print(f"  Median       : {np.median(data):.4f}")


def square_to_peaks(sample, threshold=0.1, debug=False, sample_rate=1):
    """Normalize signal to 0.0 – 0.5

    depending on gain, there can be spikes wich cause most of the high part of the signal to be
    quite lower than 1.
    See the raw data by enabling debug
    """
    sample = sample.astype(np.float32)
    max_val = np.max(sample)
    min_val = np.min(sample)
    amplitude_range = max_val - min_val

    # Avoid division by zero
    if amplitude_range == 0:
        return np.full_like(sample, max_val)

    normalized = (sample - min_val) / amplitude_range
    # setting max to 0.5 instead of 1 give more visual pleasing square waves in audacity
    result = np.where(normalized >= threshold, 0.5, 0.0)

    if debug:
        print(f"Using threshold: {threshold}")
        print(f"Input range: {np.min(sample)} to {np.max(sample)}")

        # Create time axis in seconds
        duration = len(sample) / sample_rate
        time = np.linspace(0, duration, len(sample))

        fig, axs = plt.subplots(3)
        axs[0].set_title("original")
        axs[0].plot(time, sample)

        axs[1].set_title("normalized")
        axs[1].axhline(
            y=threshold, color="r", linestyle="--", label=f"Threshold: {threshold}"
        )
        axs[1].plot(time, normalized)

        axs[2].set_title("result")
        axs[2].plot(time, result)
        plt.show()

    result_scaled = result
    # Restore original scale (optional)
    # result_scaled = result * (max_val - min_val) + min_val
    return result_scaled.astype(sample.dtype)


def main():
    parser = argparse.ArgumentParser(
        description="Flatten audio signal to original max/min values."
    )
    parser.add_argument("input", help="Input WAV file")
    parser.add_argument("output", nargs="?", help="Output WAV file (optional)")
    parser.add_argument(
        "--inplace", action="store_true", help="Overwrite the input file"
    )
    parser.add_argument("--debug", action="store_true", help="Plot signals")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.1,
        help="Threshold value for square wave conversion (default: 0.1)",
    )

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

    sample = sample.astype(np.float32)
    squared_sample = square_to_peaks(
        sample, threshold=args.threshold, debug=args.debug, sample_rate=rate
    )

    # Save result
    wav.write(output_file, rate, squared_sample)
    print(f"\nOutput written to: {output_file}")
    print_stats("Output", rate, squared_sample)


if __name__ == "__main__":
    main()

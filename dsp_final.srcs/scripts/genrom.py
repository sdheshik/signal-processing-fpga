import argparse
import math
from pathlib import Path
from binascii import hexlify
from matplotlib import pyplot as plt  # imported but not currently used

def genrom() -> None:
    """
    ROM generator.
    Generate data representing a periodic signal (sin or square)
    for use as initialization file in VHDL.
    """
    # -------------------------------------------------------------------------
    # Argument parsing
    # -------------------------------------------------------------------------
    parser = argparse.ArgumentParser(description="ROM generator")
    parser.add_argument(
        "-o", "--output-rom-file",
        type=str, required=True,
        help="Output ROM file"
    )
    parser.add_argument(
        "-s", "--sampling-frequency",
        type=int, required=True,
        help="Target sampling frequency (in MHz)"
    )
    parser.add_argument(
        "--square",
        action="store_true",
        help="Generate data representing a SQUARE signal"
    )
    parser.add_argument(
        "--sin",
        action="store_true",
        help="Generate data representing a SIN signal"
    )
    args = parser.parse_args()

    # -------------------------------------------------------------------------
    # Parameter setup
    # -------------------------------------------------------------------------
    output_rom_file    = Path(args.output_rom_file).resolve()
    sampling_frequency = 1e6 * args.sampling_frequency      # in Hz
    sampling_period    = 1.0 / sampling_frequency           # in seconds
    gain               = 80                                 # amplitude gain
    quantification     = 14                                 # number of quantization bits
    memory_width       = 16                                 # ROM data width (bits)
    memory_depth       = 9                                  # ROM address width (bits)
    v_min              = int(-(2**quantification / 2))      # min quantized value
    v_max              = int((2**quantification / 2) - 1)   # max quantized value
    number_points      = 2**memory_depth                    # total number of samples

    # -------------------------------------------------------------------------
    # Signal frequency and harmonics
    # -------------------------------------------------------------------------
    if args.square:
        # Square wave: fundamental spans full ROM sequence
        cos_frequency    = 1.0 / (number_points * sampling_period)
        number_harmonics = 10
    if args.sin:
        # Sine wave: fixed 25 MHz tone
        cos_frequency    = 25e6
        number_harmonics = 1

    # -------------------------------------------------------------------------
    # Time vector and signal initialization
    # -------------------------------------------------------------------------
    t  = [0.0] * number_points
    Ve = [0.0] * number_points
    for i in range(1, number_points):
        t[i] = t[i-1] + sampling_period

    # -------------------------------------------------------------------------
    # Prepare odd harmonics indices for square wave
    # -------------------------------------------------------------------------
    m = []
    n = 1
    for _ in range(number_harmonics):
        m.append(n)
        n += 2

    # -------------------------------------------------------------------------
    # Compute waveform samples (sum of sinusoids)
    # -------------------------------------------------------------------------
    for i in range(number_points):
        for j in range(number_harmonics):
            Ve[i] += (gain / m[j]) * math.sin(
                2.0 * math.pi * m[j] * cos_frequency * t[i]
            )

    # -------------------------------------------------------------------------
    # Write hex values to ROM file
    # -------------------------------------------------------------------------
    with output_rom_file.open(mode='w') as f:
        for v in Ve:
            # Convert to signed int then to big-endian bytes
            byte_seq = int(v).to_bytes(memory_width // 8, byteorder='big', signed=True)
            # Convert bytes to hex string and write one per line
            hex_str = hexlify(byte_seq).decode('utf-8')
            f.write(hex_str + "\n")


if __name__ == "__main__":
    genrom()

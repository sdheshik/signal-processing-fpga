import argparse
import time
import math
import serial
from matplotlib import pyplot as plt

def uart_acquisition() -> None:
    """
    Main entry point for UART acquisition.
    Parses command-line arguments, reads raw data from the DUT via UART,
    and plots it if the expected number of bytes is received.
    """
    parser = argparse.ArgumentParser(description="UART Acquisition")

    # Serial port and baudrate arguments
    parser.add_argument(
        "-p", "--serial-port",
        type=str, required=True,
        help="Name of the serial port (e.g. COM3 or /dev/ttyUSB0)"
    )
    parser.add_argument(
        "-b", "--baudrate",
        type=int, default=230400,
        help="UART baudrate (default: 230400)"
    )
    args = parser.parse_args()

    # Open the serial link with specified parameters
    serial_link = serial.Serial(
        port=args.serial_port,
        baudrate=args.baudrate,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        bytesize=serial.EIGHTBITS,
        timeout=8
    )

    # Read raw data from the device
    data = read_uart(serial_link)
    serial_link.close()

    # Validate and plot
    if len(data) == 2048:
        plot_data(data)
    else:
        print(f"Error when reading UART: received {len(data)} bytes instead of 2048")

def read_uart(uart_link: serial.Serial) -> bytes:
    """
    Send the start and read commands to the device over UART, then
    read back exactly 2048 bytes of data.
    Returns:
        A bytes object containing the raw data read.
    """
    print(f"Reading UART {uart_link.bytesize}-bit link "
          f"on port {uart_link.port} at {uart_link.baudrate} baud")

    # Command sequence: 0x5A to start fill, then 0xA5 to start readback
    uart_link.write(b'\x5A')
    time.sleep(0.01)
    uart_link.write(b'\xA5')

    # Read exactly 2048 bytes (512 complex samples × 4 bytes each)
    return uart_link.read(2048)

def plot_data(data: bytes) -> plt.Figure:
    """
    Interpret the raw byte stream as 512 complex samples (little-endian, 16-bit),
    compute the magnitude spectrum, and plot real part, imaginary part, and magnitude.
    Args:
        data: A bytes object of length 2048 (512 samples × 4 bytes).
    Returns:
        The matplotlib Figure object for further manipulation if desired.
    """
    # Pre-allocate lists for real, imag, and spectrum
    data_re   = [0] * 512
    data_im   = [0] * 512
    spectrum  = [0] * 512
    data_chr  = list(data)  # Convert bytes to list of integers

    # Frequency axis (assuming sampling rate of 390.625 kHz)
    f = [195.3125e3 * i for i in range(512)]

    # Extract 16-bit signed real and imaginary parts
    for k in range(512):
        # Real part: little-endian bytes 0 and 1
        raw_re = (data_chr[k*4 + 1] << 8) | data_chr[k*4 + 0]
        if raw_re > 32767:
            raw_re -= 65536
        data_re[k] = raw_re

        # Imaginary part: little-endian bytes 2 and 3
        raw_im = (data_chr[k*4 + 3] << 8) | data_chr[k*4 + 2]
        if raw_im > 32767:
            raw_im -= 65536
        data_im[k] = raw_im

        # Compute magnitude
        spectrum[k] = math.sqrt(raw_re**2 + raw_im**2)

    # Plot the results in three subplots
    fig, axs = plt.subplots(3, sharex=True)
    axs[0].plot(f, data_re)
    axs[0].set_ylabel('Real')
    axs[1].plot(f, data_im)
    axs[1].set_ylabel('Imag')
    axs[2].plot(f, spectrum)
    axs[2].set_ylabel('Magnitude')
    axs[2].set_xlabel('Frequency (Hz)')

    plt.show()
    return fig

if __name__ == "__main__":
    uart_acquisition()

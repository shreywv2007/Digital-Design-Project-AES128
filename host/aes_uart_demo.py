#!/usr/bin/env python3
r"""Send one AES-128 request to the FPGA and print its response.

Install on macOS: python3 -m pip install pyserial
Find serial ports: ls /dev/cu.*
Usage (replace SERIAL_PORT with your device):
    python3 host/aes_uart_demo.py SERIAL_PORT encrypt \
        --key 000102030405060708090A0B0C0D0E0F \
        --data 00112233445566778899AABBCCDDEEFF
Use 'decrypt' with ciphertext in --data and the same 128-bit key.
Optional --baud must match the FPGA BAUD_RATE; default 115200, always 8-N-1.
--timeout bounds the complete response read, not each individual byte.

Exactly 35 raw request bytes: A5 5A COMMAND KEY[16] DATA[16].
Exactly 19 raw response bytes: 5A A5 STATUS RESULT[16].
Hex strings are decoded left to right; byte 0 maps to RTL [127:120].
UART hardware handles LSB-first bits: never reverse bytes or bits here.
One request per run; do not run concurrent clients against the same FPGA.
After a timeout/partial request, stop transmission, wait for serial traffic
to stop, then reset the FPGA before retrying. Closing/reopening the Mac port
or clearing its buffers does not reset the FPGA parser. A write's returned
byte count means driver acceptance, not confirmed FPGA delivery. No automatic
retransmission is safe without request IDs or a specified recovery rule.
The exact invalid-command status code remains pending team agreement; every
nonzero status is handled as an error. This app does not implement AES itself.
"""

import argparse
import math
import re
import sys
import time


CMD_ENCRYPT = 0x01
CMD_DECRYPT = 0x02
REQUEST_SYNC = bytes((0xA5, 0x5A))
RESPONSE_SYNC = bytes((0x5A, 0xA5))
REQUEST_LENGTH = 35
RESPONSE_LENGTH = 19


class ProtocolError(Exception):
    """The received packet cannot be accepted as a successful AES result."""


def hex_block(value):
    """Accept exactly 16 bytes expressed as 32 hexadecimal characters."""
    if re.fullmatch(r"[0-9a-fA-F]{32}", value) is None:
        raise argparse.ArgumentTypeError(
            "use exactly 32 hexadecimal characters (16 bytes), without 0x or spaces"
        )
    return bytes.fromhex(value)


def positive_integer(value):
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive integer") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def positive_seconds(value):
    try:
        number = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a positive finite number") from exc
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("must be a positive finite number")
    return number


def build_request(command, key, data):
    if command not in (CMD_ENCRYPT, CMD_DECRYPT):
        raise ValueError("command must be encrypt (0x01) or decrypt (0x02)")
    if len(key) != 16 or len(data) != 16:
        raise ValueError("key and data must each contain exactly 16 bytes")
    request = REQUEST_SYNC + bytes((command,)) + key + data
    if len(request) != REQUEST_LENGTH:
        raise ValueError("request must contain exactly 35 bytes")
    return request


def write_request(serial_port, request, timeout):
    """Bound writes and explain uncertain delivery after any write failure."""
    import serial

    deadline = time.monotonic() + timeout
    offset = 0
    original_timeout = serial_port.write_timeout
    write_completed = False

    def write_error(reason):
        return ProtocolError(
            f"{reason}. The serial driver reported accepting {offset}/{len(request)} "
            "request bytes; this does not confirm FPGA delivery. A failed write "
            "may have accepted additional bytes, and the FPGA may have received "
            "a partial request. Stop transmission, wait for serial traffic to "
            "stop, then reset the FPGA before retrying. Clearing host serial "
            "buffers or reopening the port alone does not reset the FPGA parser."
        )

    try:
        while offset < len(request):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise write_error("Request write deadline expired")
            serial_port.write_timeout = remaining
            written = serial_port.write(request[offset:])
            if written is None or written <= 0:
                raise write_error("Serial write made no progress")
            offset += written
        write_completed = True
    except (serial.SerialException, OSError, ValueError) as exc:
        # SerialTimeoutException is a SerialException. Its failing write may
        # have transmitted bytes without returning a count: never auto-retry.
        raise write_error(f"Serial request write failed: {exc}") from exc
    finally:
        try:
            serial_port.write_timeout = original_timeout
        except (serial.SerialException, OSError, ValueError) as exc:
            # Preserve an earlier failure/interrupt if unplugging the adapter
            # also makes timeout restoration fail. Report restoration errors
            # after an otherwise completed write, since delivery is uncertain.
            if write_completed:
                raise write_error(f"Could not restore serial write timeout: {exc}") from exc


def read_response(serial_port, timeout):
    """Accumulate a full response, including serial reads returning short chunks."""
    response = bytearray()
    deadline = time.monotonic() + timeout
    original_timeout = serial_port.timeout
    try:
        while len(response) < RESPONSE_LENGTH:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            serial_port.timeout = remaining
            chunk = serial_port.read(RESPONSE_LENGTH - len(response))
            if not chunk:
                break
            response.extend(chunk)
    finally:
        serial_port.timeout = original_timeout
    if len(response) != RESPONSE_LENGTH:
        received = bytes(response).hex().upper() or "(none)"
        raise ProtocolError(
            f"incomplete response: received {len(response)}/{RESPONSE_LENGTH} "
            f"bytes before timeout; bytes: {received}. "
            "Check FPGA clock/baud and controller wiring; reset before retrying."
        )
    return bytes(response)


def decode_response(response):
    if len(response) != RESPONSE_LENGTH:
        raise ProtocolError("response must contain exactly 19 bytes")
    if response[:2] != RESPONSE_SYNC:
        raise ProtocolError(
            f"bad response sync: {response[:2].hex().upper()}, expected 5AA5"
        )
    return response[2], response[3:19]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("port", help="serial device, e.g. a device listed by ls /dev/cu.*")
    parser.add_argument("command", choices=("encrypt", "decrypt"))
    parser.add_argument("--key", required=True, type=hex_block,
                        help="128-bit AES key: 32 hex characters")
    parser.add_argument("--data", required=True, type=hex_block,
                        help="128-bit plaintext (encrypt) or ciphertext (decrypt)")
    parser.add_argument("--baud", type=positive_integer, default=115200,
                        help="baud rate matching FPGA BAUD_RATE (default: 115200)")
    parser.add_argument("--timeout", type=positive_seconds, default=3.0,
                        help="write/response timeout in seconds (default: 3)")
    args = parser.parse_args(argv)

    try:
        import serial
    except ImportError:
        print("Missing pyserial. Install: python3 -m pip install pyserial", file=sys.stderr)
        return 1

    command = CMD_ENCRYPT if args.command == "encrypt" else CMD_DECRYPT
    request = build_request(command, args.key, args.data)
    print(f"Port:    {args.port} ({args.baud} baud, 8-N-1)", flush=True)
    print(f"Command: {args.command.upper()} (0x{command:02X})", flush=True)
    print(f"Key:     {args.key.hex().upper()}", flush=True)
    print(f"Input:   {args.data.hex().upper()}", flush=True)

    try:
        # Configure handshake lines before opening. No software/hardware flow
        # control: arbitrary binary payloads may contain XON/XOFF byte values.
        # A board wrapper must still define its reset source; opening a port
        # is not assumed to reset the FPGA or initialize the system controller.
        with serial.Serial(
            port=None, baudrate=args.baud, bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
            timeout=args.timeout, write_timeout=args.timeout,
            xonxoff=False, rtscts=False, dsrdtr=False
        ) as serial_port:
            serial_port.dtr = False
            serial_port.rts = False
            serial_port.port = args.port
            serial_port.open()
            serial_port.reset_input_buffer()
            write_request(serial_port, request, args.timeout)
            response = read_response(serial_port, args.timeout)
        status, result = decode_response(response)
        print(f"Status:  0x{status:02X} ({'success' if status == 0 else 'error'})")
        print(f"Result:  {result.hex().upper()}")
        if status != 0:
            detail = ""
            if result != bytes(16):
                detail = " Error result is nonzero; invalid-command replies must be zero."
            raise ProtocolError(f"FPGA returned error status 0x{status:02X}.{detail}")
    except (ProtocolError, serial.SerialException, OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrupted; reset the FPGA before retrying a partial transaction.",
              file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())

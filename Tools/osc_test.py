#!/usr/bin/env python3
"""
MotionHub OSC Test Script
Sends OSC messages to control MotionHub parameters.

Usage: python3 osc_test.py
"""

import socket
import struct
import time
import sys

def create_osc_message(address, value):
    """Create a simple OSC message with a float value."""
    # OSC address (null-terminated, padded to 4 bytes)
    address_bytes = address.encode('utf-8') + b'\x00'
    while len(address_bytes) % 4 != 0:
        address_bytes += b'\x00'

    # Type tag (,f for float, null-terminated, padded to 4 bytes)
    type_tag = b',f\x00\x00'

    # Float value (big-endian)
    value_bytes = struct.pack('>f', float(value))

    return address_bytes + type_tag + value_bytes

def send_osc(address, value, host='127.0.0.1', port=9000):
    """Send an OSC message via UDP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    message = create_osc_message(address, value)
    sock.sendto(message, (host, port))
    sock.close()
    print(f"Sent: {address} = {value}")

def main():
    print("=" * 50)
    print("MotionHub OSC Test")
    print("=" * 50)
    print(f"Sending to: 127.0.0.1:9000")
    print()
    print("Make sure MotionHub is running with OSC enabled!")
    print()

    # Check for quick test mode
    if len(sys.argv) > 1 and sys.argv[1] == 'test100':
        print("Testing 0-100 range values...")
        print("-" * 30)
        # Test with values in the 0-100 range (like Max for Live dials)
        send_osc("/motionhub/intensity", 50.0)
        time.sleep(0.3)
        send_osc("/motionhub/glitch", 50.0)
        time.sleep(0.3)
        send_osc("/motionhub/colorshift", 50.0)
        time.sleep(0.3)
        print("-" * 30)
        print("All parameters should now show 50 in MotionHub")
        return

    # Test each parameter
    tests = [
        ("/motionhub/intensity", 0.8),
        ("/motionhub/glitch", 0.5),
        ("/motionhub/speed", 2.0),
        ("/motionhub/colorshift", 0.3),
    ]

    print("Sending test values...")
    print("-" * 30)

    for address, value in tests:
        send_osc(address, value)
        time.sleep(0.5)

    print("-" * 30)
    print()

    # Interactive mode
    print("Interactive mode - enter commands:")
    print("  intensity 0.5  - set intensity to 0.5")
    print("  glitch 0.8     - set glitch to 0.8")
    print("  speed 3.0      - set speed to 3.0")
    print("  color 0.2      - set color shift to 0.2")
    print("  mono 1         - enable monochrome")
    print("  mono 0         - disable monochrome")
    print("  reset          - trigger reset")
    print("  quit           - exit")
    print()

    param_map = {
        'intensity': '/motionhub/intensity',
        'glitch': '/motionhub/glitch',
        'speed': '/motionhub/speed',
        'color': '/motionhub/colorshift',
        'mono': '/motionhub/monochrome',
        'reset': '/motionhub/reset',
    }

    while True:
        try:
            cmd = input("> ").strip().lower()
            if cmd == 'quit' or cmd == 'exit' or cmd == 'q':
                break

            parts = cmd.split()
            if len(parts) == 1 and parts[0] == 'reset':
                send_osc('/motionhub/reset', 1.0)
            elif len(parts) == 2:
                param, value = parts
                if param in param_map:
                    send_osc(param_map[param], float(value))
                else:
                    print(f"Unknown parameter: {param}")
            else:
                print("Invalid command. Try: intensity 0.5")
        except ValueError:
            print("Invalid value. Use a number.")
        except KeyboardInterrupt:
            print("\nExiting...")
            break

    print("Done!")

if __name__ == '__main__':
    main()

#!/bin/bash
# HP PS200 Scanner Button Daemon
# Listens for physical button presses and triggers scans
# Button 5 = Simplex (single side)
# Button 3 = Duplex (both sides)

SCAN_DIR="$HOME/Scans"
mkdir -p "$SCAN_DIR"

echo "=== HP PS200 Button Daemon ==="
echo "Scans saved to: $SCAN_DIR"
echo "Press scanner buttons to scan:"
echo "  [Simplex] -> 300dpi color, front only"
echo "  [Duplex]  -> 300dpi color, both sides"
echo ""
echo "Ctrl+C to stop"

python3 -u << 'PYEOF'
import usb.core, subprocess, os, sys
from datetime import datetime

SCAN_DIR = os.path.expanduser("~/Scans")
os.makedirs(SCAN_DIR, exist_ok=True)

# Button mapping
SIMPLEX = 5
DUPLEX = 3

def find_device():
    result = subprocess.run(["scanimage", "-L"], capture_output=True, text=True, timeout=15)
    for line in result.stdout.splitlines():
        if "HP PS200" in line:
            return line.split("'")[1]  # extract device name between quotes
    return None

def scan(source, label):
    dev = find_device()
    if not dev:
        print("  Scanner not found!")
        return

    ts = datetime.now().strftime("%Y%m%d-%H%M%S")

    if source == "ADF Duplex":
        pattern = f"{SCAN_DIR}/scan-duplex-{ts}-%d.pnm"
        cmd = ["scanimage", "-d", dev, "--format=pnm", "--resolution", "300",
               "--mode", "Color", "--source", source, "-x", "215", "-y", "297",
               f"--batch={pattern}"]
    else:
        fname = f"{SCAN_DIR}/scan-{ts}.pnm"
        cmd = ["scanimage", "-d", dev, "--format=pnm", "--resolution", "300",
               "--mode", "Color", "--source", source, "-x", "215", "-y", "297",
               "-o", fname]

    print(f"  Scanning ({label})...")
    try:
        subprocess.run(cmd, timeout=120)
        print(f"  Done! Saved to {SCAN_DIR}")
    except Exception as e:
        print(f"  Error: {e}")

def main():
    while True:
        try:
            dev = usb.core.find(idVendor=0x03f0, idProduct=0x53f3)
            if not dev:
                print("Waiting for scanner...")
                import time; time.sleep(3)
                continue

            print("Listening for button press...")
            while True:
                try:
                    data = dev.read(0x83, 8, timeout=1000)
                    if data[0] & 0x80:
                        btn = data[1]
                        if btn == SIMPLEX:
                            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] SIMPLEX button pressed")
                            scan("ADF Front", "simplex 300dpi color")
                            print("Listening for button press...")
                        elif btn == DUPLEX:
                            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] DUPLEX button pressed")
                            scan("ADF Duplex", "duplex 300dpi color")
                            print("Listening for button press...")
                        else:
                            print(f"  Unknown button: {btn}")
                except usb.core.USBTimeoutError:
                    pass
                except usb.core.USBError:
                    break  # device disconnected, retry

        except KeyboardInterrupt:
            print("\nStopped.")
            sys.exit(0)
        except Exception as e:
            print(f"Error: {e}")
            import time; time.sleep(3)

main()
PYEOF

#!/bin/bash
# HP PS200 Scanner Button Daemon
# Button 1 (ID=5): Simplex (single side)
# Button 2 (ID=3): Duplex (both sides)

SCAN_DIR="$HOME/Scans"
mkdir -p "$SCAN_DIR"

echo "=== HP PS200 Button Daemon ==="
echo "Scans saved to: $SCAN_DIR"
echo "  [1] Simplex  |  [2] Duplex"
echo "Ctrl+C to stop"

python3 -u << 'PYEOF'
import subprocess, os, sys, time
from datetime import datetime

SCAN_DIR = os.path.expanduser("~/Scans")
os.makedirs(SCAN_DIR, exist_ok=True)

BTN_SIMPLEX = 5
BTN_DUPLEX = 3

def poll_button():
    """Quick open USB, read one interrupt, close immediately."""
    try:
        import usb.core, usb.util
        dev = usb.core.find(idVendor=0x03f0, idProduct=0x53f3)
        if not dev:
            return None
        try:
            data = dev.read(0x83, 8, timeout=800)
            if data[0] & 0x80:
                return data[1]
        except:
            pass
        finally:
            usb.util.dispose_resources(dev)
            del dev
    except:
        pass
    return None

def scan(source, label):
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")

    if source == "ADF Duplex":
        pattern = f"{SCAN_DIR}/scan-duplex-{ts}-%d.pnm"
        cmd = ["scanimage", "--format=pnm", "--resolution", "300",
               "--mode", "Color", "--source", source, "-x", "215", "-y", "297",
               f"--batch={pattern}"]
    else:
        fname = f"{SCAN_DIR}/scan-{ts}.pnm"
        cmd = ["scanimage", "--format=pnm", "--resolution", "300",
               "--mode", "Color", "--source", source, "-x", "215", "-y", "297",
               "-o", fname]

    print(f"  Scanning ({label})...", flush=True)
    try:
        result = subprocess.run(cmd, timeout=120, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  Done! Saved to {SCAN_DIR}", flush=True)
        else:
            err = result.stderr.strip().split('\n')[-1] if result.stderr else "unknown"
            print(f"  Error: {err}", flush=True)
    except Exception as e:
        print(f"  Error: {e}", flush=True)

    # Small dummy scan to trigger the driver's eject mechanism
    time.sleep(1)
    subprocess.run(["scanimage", "--format=pnm", "--resolution", "50",
                    "--mode", "Lineart", "-x", "10", "-y", "1",
                    "-o", "/dev/null"], timeout=15, capture_output=True)
    time.sleep(1)

def main():
    print("Listening...", flush=True)
    scanning = False

    while True:
        try:
            btn = poll_button()

            if btn == BTN_SIMPLEX and not scanning:
                scanning = True
                now = datetime.now().strftime('%H:%M:%S')
                print(f"\n[{now}] Button 1: SIMPLEX", flush=True)
                time.sleep(1)
                scan("ADF Front", "simplex 300dpi color")
                # Flush stale button events
                for _ in range(10):
                    poll_button()
                scanning = False
                print("Listening...", flush=True)

            elif btn == BTN_DUPLEX and not scanning:
                scanning = True
                now = datetime.now().strftime('%H:%M:%S')
                print(f"\n[{now}] Button 2: DUPLEX", flush=True)
                time.sleep(1)
                scan("ADF Duplex", "duplex 300dpi color")
                # Flush stale button events
                for _ in range(10):
                    poll_button()
                scanning = False
                print("Listening...", flush=True)

            time.sleep(0.2)

        except KeyboardInterrupt:
            print("\nStopped.")
            sys.exit(0)
        except Exception as e:
            print(f"Error: {e}", flush=True)
            time.sleep(3)

main()
PYEOF

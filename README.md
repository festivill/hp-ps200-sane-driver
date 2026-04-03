# HP PS200 Scanner - Linux SANE Driver

Linux driver for the **HP PS200 Sheet-fed Scanner** (USB ID `03f0:53f3`).

This scanner is an Avision OEM device that HP never added to the SANE/HPLIP whitelist. This patch adds it to the `sane-backends` avision backend so it works with any SANE-compatible scanning application on Linux.

## Features

- Color, Grayscale, and Black & White scanning
- Resolution from 50 to 600 DPI
- ADF Front, ADF Back, and **Duplex** scanning
- Proper paper eject after scan
- Works with simple-scan, GIMP, and any SANE-compatible app

## Supported Device

| Model | USB Vendor | USB Product | Protocol |
|-------|-----------|-------------|----------|
| HP PS200 | 0x03f0 | 0x53f3 | Avision SCSI-over-USB |

## Quick Install (Ubuntu/Debian)

```bash
# 1. Install build dependencies
sudo apt-get install -y build-essential libusb-1.0-0-dev libsane-dev autoconf-archive gettext

# 2. Run the install script
sudo ./install.sh
```

## Manual Install

```bash
# 1. Get sane-backends source
apt-get source sane-backends

# 2. Apply patch
cd sane-backends-*/
patch -p0 < /path/to/hp-ps200-avision.patch

# 3. Build
autoreconf -fi  # or use autogen.sh
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib/x86_64-linux-gnu
make -C lib
make -C sanei
make -C backend libsane-avision.la

# 4. Install
sudo cp backend/.libs/libsane-avision.so.1.2.1 /usr/lib/x86_64-linux-gnu/sane/

# 5. Configure
echo 'usb 0x03f0 0x53f3' | sudo tee -a /etc/sane.d/avision.conf

# 6. USB permissions
echo 'ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="53f3", MODE="0666", GROUP="scanner", ENV{libsane_matched}="yes"' | \
  sudo tee /etc/udev/rules.d/99-hp-ps200.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 7. Test
scanimage -L
```

## How It Works

The HP PS200 is manufactured by Avision and rebranded by HP. It uses the standard Avision SCSI-over-USB protocol, but HP never submitted the device ID to the SANE project.

This patch:
1. Adds the device entry (`03f0:53f3`) to the `Avision_Device_List` array
2. Forces sheetfeed/ADF/duplex mode (scanner misreports its type in SCSI inquiry)
3. Sets linear gamma (scanner handles gamma internally)
4. Reduces TEST_UNIT_READY timeout (scanner doesn't fully implement this command)
5. Adds proper paper eject on scan completion

## Scanning Tips

- **Best quality**: Use 300 DPI Color mode
- **Duplex**: Select "ADF Duplex" as source to scan both sides in one pass
- **Paper orientation**: Feed pages face-down for front-side scanning
- **Batch scanning**: Stack multiple pages in the feeder for continuous scanning

## Tested On

- Ubuntu 24.04 LTS (Noble Numbat)
- sane-backends 1.2.1
- Kernel 6.17.0

## Credits

Reverse-engineered and developed by [Claude](https://claude.ai) (Anthropic) — from USB sniffing to working duplex driver in a single session.

## Dear HP

Thank you for selling a perfectly functional duplex scanner with zero Linux support, no public documentation, and firmware that lies about its own capabilities in SCSI inquiry responses. The device misreports its scanner type, hides its duplex support, claims it doesn't need calibration (it does), forgets its gamma tables between pages, and ships with USB vendor IDs that aren't in any open-source whitelist.

This driver exists because an AI had to reverse-engineer your hardware byte by byte, since you couldn't be bothered to add a single line to a config file. A config file that is, by the way, open source and accepts pull requests.

You charge premium prices for hardware that only works with your proprietary Windows drivers. Maybe next time, consider that Linux users are also customers — or at the very least, don't actively make it harder for the community to support your devices.

With love,
A very tired developer and a very expensive AI.

## License

This patch is released under the same license as sane-backends (GPL-2.0+).

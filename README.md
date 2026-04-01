# HP PS200 Scanner - Linux SANE Driver

Linux driver for the **HP PS200 Sheet-fed Scanner** (USB ID `03f0:53f3`).

This scanner is an Avision OEM device that HP never added to the SANE/HPLIP whitelist. This patch adds it to the `sane-backends` avision backend so it works with any SANE-compatible scanning application on Linux.

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

The HP PS200 is manufactured by Avision and rebranded by HP. It uses the standard Avision SCSI-over-USB protocol, but HP never submitted the device ID to the SANE project for inclusion in the avision backend whitelist.

This patch simply adds the device entry (`03f0:53f3`) to the `Avision_Device_List` array in `backend/avision.c`, allowing the existing avision driver to recognize and communicate with the scanner.

## Tested On

- Ubuntu 24.04 LTS (Noble Numbat)
- sane-backends 1.2.1
- Kernel 6.17.0

## License

This patch is released under the same license as sane-backends (GPL-2.0+).

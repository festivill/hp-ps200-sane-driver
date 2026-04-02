#!/bin/bash
# HP PS200 Scanner - SANE Driver Installer
# Patches the sane-backends avision backend to support the HP PS200

set -e

echo "=== HP PS200 SANE Driver Installer ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh"
    exit 1
fi

# Check if scanner is connected
if ! lsusb | grep -q "03f0:53f3"; then
    echo "Warning: HP PS200 scanner not detected on USB."
    echo "Continuing with installation anyway..."
fi

# Install build dependencies
echo "[1/7] Installing build dependencies..."
apt-get install -y build-essential libusb-1.0-0-dev dpkg-dev autoconf-archive gettext > /dev/null 2>&1

# Enable source repos if needed
if ! apt-get source --download-only sane-backends > /dev/null 2>&1; then
    echo "[1/7] Enabling source repositories..."
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true
    apt-get update -qq
fi

# Get sane-backends source
echo "[2/7] Downloading sane-backends source..."
WORKDIR=$(mktemp -d)
cd "$WORKDIR"
apt-get source sane-backends > /dev/null 2>&1
cd sane-backends-*/

# Apply patch
echo "[3/7] Applying HP PS200 patch..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patch -p0 < "$SCRIPT_DIR/hp-ps200-avision.patch"

# Build
echo "[4/7] Building (this may take a minute)..."
apt-get build-dep -y sane-backends > /dev/null 2>&1
if [ -f autogen.sh ]; then
    bash autogen.sh > /dev/null 2>&1
fi
./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib/x86_64-linux-gnu > /dev/null 2>&1
make -C lib -j$(nproc) > /dev/null 2>&1
make -C sanei -j$(nproc) > /dev/null 2>&1
make -C backend libsane-avision.la -j$(nproc) > /dev/null 2>&1

# Backup and install
echo "[5/7] Installing patched library..."
SANE_LIB="/usr/lib/x86_64-linux-gnu/sane/libsane-avision.so.1.2.1"
if [ -f "$SANE_LIB" ] && [ ! -f "${SANE_LIB}.orig" ]; then
    cp "$SANE_LIB" "${SANE_LIB}.orig"
fi
cp backend/.libs/libsane-avision.so.1.2.1 "$SANE_LIB"
ldconfig

# Configure SANE
echo "[6/7] Configuring SANE..."
if ! grep -q "0x03f0 0x53f3" /etc/sane.d/avision.conf 2>/dev/null; then
    echo "option force-a4" >> /etc/sane.d/avision.conf
    echo "usb 0x03f0 0x53f3" >> /etc/sane.d/avision.conf
fi

# USB permissions
echo "[7/7] Setting USB permissions..."
cat > /etc/udev/rules.d/99-hp-ps200.rules << 'EOF'
ATTRS{idVendor}=="03f0", ATTRS{idProduct}=="53f3", MODE="0666", GROUP="scanner", ENV{libsane_matched}="yes"
EOF
udevadm control --reload-rules
udevadm trigger

# Cleanup
rm -rf "$WORKDIR"

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Test with: scanimage -L"
echo "Scan with: simple-scan"
echo ""

# Test
if scanimage -L 2>&1 | grep -q "HP PS200"; then
    echo "SUCCESS: HP PS200 scanner detected!"
else
    echo "Scanner not detected. Make sure it's plugged in and try: scanimage -L"
fi

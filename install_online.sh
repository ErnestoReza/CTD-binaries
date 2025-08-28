#!/usr/bin/env bash
# install_ctd.sh  –  installer for CTD
set -euo pipefail

OWNER=ErnestoReza
BINREPO=CTD-binaries
BASENAME=Magno
INSTALL_DIR=/opt/ctd
SERVICE=ctd.service

if [[ $EUID -ne 0 ]]; then
  echo "‼️  Please run as root: sudo bash $0"
  exit 1
fi

echo "🛈 Detecting OS release …"
RELEASE=$(lsb_release -cs)      # buster | bullseye | bookworm | etc.
ASSET="${BASENAME}-${RELEASE}.tar.gz"
URL="https://github.com/${OWNER}/${BINREPO}/releases/latest/download/${ASSET}"

echo "🛈 Installing into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd      "$INSTALL_DIR"

echo "⬇  Downloading $ASSET …"
curl -fsSL -o "$ASSET" "$URL"

echo "📦 Unpacking …"
tar -xzf "$ASSET"

BIN_PATH="$INSTALL_DIR/LCD.dist/LCD.bin"
ln -sf "$BIN_PATH" /usr/local/bin/ctd
chmod +x   /usr/local/bin/ctd

echo "📝 Writing systemd unit …"
/bin/cat > "/etc/systemd/system/$SERVICE" <<EOF
[Unit]
Description=CTD Controller
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ctd
User=pi
WorkingDirectory=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1
Restart=on-failure
StandardOutput=append:/var/log/ctd.log
StandardError=append:/var/log/ctd.log

[Install]
WantedBy=multi-user.target
EOF

/bin/cat > "/etc/logrotate.d/ctd" <<EOF
/var/log/ctd.log {
    daily
    rotate 14
    missingok
    notifempty
    copytruncate
}
EOF

echo "📁 Removing old CTD installation and backing up…"

mkdir -p "/home/pi/Desktop/temp/lib"
cp -a "/home/pi/Desktop/CTD/lib/test_files/." "/home/pi/Desktop/temp/lib/test_files"
cp "/home/pi/Desktop/CTD/lib/config.ini" "/home/pi/Desktop/temp/lib/config.ini"
rm -r "/home/pi/Desktop/CTD"

echo "📁 Creating directories …"
mkdir -p "/home/pi/Desktop/CTD"
cp -a "$INSTALL_DIR/LCD.dist/lib/." "/home/pi/Desktop/CTD/lib"
cp -a "$INSTALL_DIR/LCD.dist/Resources/." "/home/pi/Desktop/CTD/Resources"
cp -a "$INSTALL_DIR/LCD.dist/Verry Important Files/." "/home/pi/Desktop/CTD/Verry Important Files"
cp -a "/home/pi/Desktop/temp/lib/test_files/." "/home/pi/Desktop/CTD/lib/test_files"
cp "/home/pi/Desktop/temp/lib/config.ini" "/home/pi/Desktop/CTD/lib/config.ini"

rm -rf "/home/pi/Desktop/temp"

chown -R pi:pi "/home/pi/Desktop/CTD"

echo "⚙️  Configuring /etc/rc.local..."
RC_LOCAL="/etc/rc.local"
/bin/cat > "$RC_LOCAL" <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
EOF

echo "📁 Deleting Backups …"
rm -rf /home/pi/Documents/*

echo "🔄 Reloading systemd & starting service …"
systemctl daemon-reload
systemctl enable --now  "$SERVICE"

echo "✅ Installation complete. Logs:"
systemctl --no-pager status "$SERVICE"
echo "Use   journalctl -u $SERVICE -f   to follow output."

reboot
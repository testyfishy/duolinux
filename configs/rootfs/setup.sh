#!/bin/bash
# Runs inside the arm64 rootfs via chroot (or qemu+chroot). Idempotent.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export SYSTEMD_OFFLINE=1

USER_NAME="${DUO_USER:-duo}"
USER_PASS="${DUO_PASSWORD:-duo}"
HOSTNAME="${DUO_HOSTNAME:-duo}"
TIMEZONE="${DUO_TIMEZONE:-Europe/London}"

echo "== duo rootfs setup: user=$USER_NAME host=$HOSTNAME"

# --- user ----------------------------------------------------------
if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -c "DuoLinux user" "$USER_NAME"
fi
echo "$USER_NAME:$USER_PASS" | chpasswd
for g in sudo input video render audio netdev bluetooth plugdev; do
  getent group "$g" >/dev/null 2>&1 && usermod -aG "$g" "$USER_NAME"
done
passwd -l root >/dev/null 2>&1 || true
install -d -o "$USER_NAME" -g "$USER_NAME" -m 700 "/home/$USER_NAME/.ssh"
install -d -o "$USER_NAME" -g "$USER_NAME" -m 755 "/home/$USER_NAME/.local/state/duo"
install -d -m 755 /etc/duo /var/lib/duo /run/duo /var/log

# --- identity ------------------------------------------------------
echo "$HOSTNAME" > /etc/hostname
if ! grep -qE "^127\.0\.1\.1[[:space:]]+$HOSTNAME" /etc/hosts; then
  echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
fi
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
echo "$TIMEZONE" > /etc/timezone
printf 'C.UTF-8 UTF-8\nen_GB.UTF-8 UTF-8\n' > /etc/locale.gen
locale-gen >/dev/null 2>&1 || true
echo 'LANG=C.UTF-8' > /etc/default/locale

# --- mounts --------------------------------------------------------
cat > /etc/fstab <<EOF
LABEL=${DUO_ROOT_LABEL:-STORAGE} / ext4 defaults,noatime 0 1
tmpfs /tmp tmpfs defaults,nosuid,nodev,size=512M 0 0
EOF

# --- services ------------------------------------------------------
systemctl enable NetworkManager.service >/dev/null 2>&1 || true
systemctl enable systemd-resolved.service >/dev/null 2>&1 || true
systemctl enable ssh.service >/dev/null 2>&1 || true
systemctl enable tailscaled.service >/dev/null 2>&1 || true
systemctl enable bluetooth.service >/dev/null 2>&1 || true
systemctl enable duo-firstboot.service >/dev/null 2>&1 || true
systemctl enable duo-inputd.service >/dev/null 2>&1 || true
systemctl enable getty@tty1.service >/dev/null 2>&1 || true
systemctl set-default graphical.target >/dev/null 2>&1 || true

# ssh host keys for the image; regenerate on first boot if you prefer
ssh-keygen -A >/dev/null 2>&1 || true

# --- permissions ---------------------------------------------------
echo "$USER_NAME ALL=(ALL:ALL) ALL" > /etc/sudoers.d/duo
chmod 440 /etc/sudoers.d/duo
chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME"
if [ -f /etc/duo/tailscale.authkey ]; then
  chmod 600 /etc/duo/tailscale.authkey
fi
chmod 600 /etc/duo/duo.conf 2>/dev/null || true

# --- journal -------------------------------------------------------
mkdir -p /var/log/journal
systemd-machine-id-setup >/dev/null 2>&1 || true

# --- cleanup -------------------------------------------------------
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/setup.sh
sync
echo "== duo rootfs setup complete"

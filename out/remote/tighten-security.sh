#!/bin/bash
# Tighten authorisation: no blanket NOPASSWD, no polkit bypass. The session
# keeps exactly three narrowly-scoped root helpers, and everything else that
# needs root asks for the account password (which now exists).
set -u

echo "=== 1. scroll-direction helper so the GUI needs no shell via sudo"
cat > /usr/local/bin/duo-scroll-set <<'EOF'
#!/bin/sh
# Set the right-stick scroll direction. Called by the Controller settings page.
case "${1:-}" in
    natural)   printf 'natural\n'  > /etc/duo/scroll-direction ;;
    standard)  printf 'standard\n' > /etc/duo/scroll-direction ;;
    *) echo "usage: duo-scroll-set natural|standard" >&2; exit 2 ;;
esac
chmod 644 /etc/duo/scroll-direction
EOF
chmod 755 /usr/local/bin/duo-scroll-set
chmod 644 /etc/duo/scroll-direction 2>/dev/null || true

echo "=== 2. single sudoers file, three commands only"
rm -f /etc/sudoers.d/90-duo /etc/sudoers.d/zz-duo /etc/sudoers.d/duo /etc/sudoers.d/duo-bottom
cat > /etc/sudoers.d/duo <<'EOF'
# The desktop session may run these three root helpers without a prompt.
# Everything else requires the account password.
duo ALL=(root) NOPASSWD: /usr/local/bin/duo-bottom-detect
duo ALL=(root) NOPASSWD: /usr/local/bin/duo-controller-apply
duo ALL=(root) NOPASSWD: /usr/local/bin/duo-scroll-set
EOF
chmod 440 /etc/sudoers.d/duo
visudo -c 2>&1 | tail -2

echo "=== 3. remove the polkit bypass so admin actions prompt for the password"
rm -f /etc/polkit-1/rules.d/49-duo-nopasswd.rules
systemctl restart polkit.service
sleep 1
systemctl is-active polkit.service

echo "=== 4. verify what duo may do without a password"
su - duo -c 'sudo -n -l' 2>&1 | head -12

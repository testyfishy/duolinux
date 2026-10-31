#!/bin/bash
# The device is single-user and duo already has NOPASSWD sudo. polkit asking
# for a password that was never set just blocks the GUI, so grant the desktop
# user polkit admin without a prompt (same trust level sudo already grants).
set -u
install -d -m 755 /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-duo-nopasswd.rules <<'EOF'
/* Single-user handheld: the desktop user is the administrator. */
polkit.addRule(function(action, subject) {
    if (subject.user == "duo" && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF
chmod 644 /etc/polkit-1/rules.d/49-duo-nopasswd.rules

systemctl restart polkit.service
sleep 2
systemctl is-active polkit.service
echo "=== rule installed:"
cat /etc/polkit-1/rules.d/49-duo-nopasswd.rules

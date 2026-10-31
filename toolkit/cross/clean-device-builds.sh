#!/bin/bash
# Stop the handheld from carrying the toolchains' leftovers: the whisper.cpp
# source tree and wvkbd tree that were built on the device are no longer used,
# because both binaries are now cross-built on the PC.
#
# Keeps the binaries, moves whisper-cli to a stable path, removes the trees.
set -euo pipefail
KEY=$HOME/.ssh/duo_key
H=root@192.168.86.33
SSH="ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SCP="scp -q -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "=== before"
$SSH "$H" 'du -sh /opt/duo-stt/whisper.cpp /root/whisper.cpp /root/wvkbd-0.15 2>/dev/null; df -h / | tail -1'

echo
echo "=== moving whisper-cli to a stable path"
$SSH "$H" '
set -e
mkdir -p /opt/duo-stt/bin
if [ -f /opt/duo-stt/whisper.cpp/build/bin/whisper-cli ]; then
    mv -f /opt/duo-stt/whisper.cpp/build/bin/whisper-cli /opt/duo-stt/bin/whisper-cli
fi
chmod 755 /opt/duo-stt/bin/whisper-cli
/opt/duo-stt/bin/whisper-cli --help 2>&1 | head -1
'

echo
echo "=== installing duo-dictate (new local-cli path)"
$SCP "/mnt/c/Users/HTPC-Aran/Documents/Default Project/duolinux/out/remote/duo-dictate" "$H:/tmp/duo-dictate"
$SSH "$H" '
set -e
sed -i "s/\r$//" /tmp/duo-dictate
install -m 755 /tmp/duo-dictate /usr/local/bin/duo-dictate
grep -n "LOCAL_CLI" /usr/local/bin/duo-dictate | head -1
python3 -c "import ast,sys; ast.parse(open(\"/usr/local/bin/duo-dictate\").read()); print(\"  syntax ok\")"
'

echo
echo "=== removing build trees"
$SSH "$H" '
rm -rf /opt/duo-stt/whisper.cpp /opt/duo-stt/venv1
rm -rf /root/whisper.cpp /root/wvkbd-0.15 /root/wvkbd.tar.gz /root/wvkbd_0.15.orig.tar.xz /root/wvkbd
echo "  done"
'

echo
echo "=== after"
$SSH "$H" '
du -sh /opt/duo-stt 2>/dev/null
df -h / | tail -1
ls -l /opt/duo-stt/bin/whisper-cli
duo-dictate status 2>&1 | sed "s/^/  /"
'

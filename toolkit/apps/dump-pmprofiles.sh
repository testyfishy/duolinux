#!/bin/sh
set -u
echo "=== powermanagementprofilesrc (the file PowerDevil reads for actions)"
su - duo -c 'cat ~/.config/powermanagementprofilesrc' 2>/dev/null | sed 's/^/  /' | head -50

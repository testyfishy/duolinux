#!/bin/bash
# Print the existing backend DAI link verbatim so the new VA link can copy its
# exact shape (platform phandle included).
set -uo pipefail
sed -n '3976,4020p' /tmp/va-vendor.dts

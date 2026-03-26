#!/usr/bin/env bash

set -euo pipefail

if pgrep -x wvkbd-mobintl >/dev/null 2>&1 || pgrep -x wvkbd >/dev/null 2>&1; then
	pkill -x wvkbd-mobintl >/dev/null 2>&1 || true
	pkill -x wvkbd >/dev/null 2>&1 || true
	exit 0
fi

exec /etc/hypr/scripts/toggle-osk.sh
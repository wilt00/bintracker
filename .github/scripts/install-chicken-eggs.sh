#!/usr/bin/env bash
set -euo pipefail

eggs=(
  srfi-18 check-errors args base64 bitstring comparse coops
  list-utils matchable pstk s11n simple-md5 sqlite3
  stb-image stb-image-write srfi-1 srfi-4 srfi-13 srfi-14
  srfi-69 shell stack test typed-records web-colors
)

for attempt in 1 2 3; do
  if chicken-install -verbose "${eggs[@]}"; then
    exit 0
  fi

  if (( attempt == 3 )); then
    echo 'Chicken egg installation failed after three attempts.' >&2
    exit 1
  fi

  echo "Chicken egg installation attempt $attempt failed; retrying..." >&2
  sleep $((attempt * 15))
done

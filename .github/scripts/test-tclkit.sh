#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
smoke_script="$RUNNER_TEMP/tclkit-smoke.tcl"
smoke_result="$RUNNER_TEMP/tclkit-smoke.txt"

cat > "$smoke_script" <<'EOF'
package require Tk
wm withdraw .
set channel [open [lindex $argv 0] w]
puts $channel [info patchlevel]
close $channel
destroy .
exit
EOF

rm -f "$smoke_result"
"$repo_root/build/3rdparty/tclkit.exe" "$smoke_script" "$smoke_result"
for _ in {1..50}; do
  test -f "$smoke_result" && break
  sleep 0.1
done
grep -E '^8\.6\.' "$smoke_result"

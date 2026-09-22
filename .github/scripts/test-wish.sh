#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
wish="$repo_root/build/bin/wish.exe"
smoke_script="$RUNNER_TEMP/wish-smoke.tcl"
smoke_result="$RUNNER_TEMP/wish-smoke.txt"

grep -a -F '<dpiAware>true</dpiAware>' "$wish"

cat > "$smoke_script" <<'EOF'
package require Tk
wm withdraw .
set channel [open [lindex $argv 0] w]
puts $channel "[info patchlevel] [package provide Tk]"
close $channel
destroy .
exit
EOF

rm -f "$smoke_result"
"$wish" "$smoke_script" "$smoke_result"
for _ in {1..50}; do
  test -f "$smoke_result" && break
  sleep 0.1
done
grep -E '^8\.6\.[0-9]+ 8\.6\.[0-9]+$' "$smoke_result"

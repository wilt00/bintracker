#!/usr/bin/env bash
set -euo pipefail

: "${MINGW_PREFIX:?MINGW_PREFIX must be set}"
: "${OBJECT_ARCH:?OBJECT_ARCH must be set}"

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root/build"

make -f Makefile.msys RELEASE=1 bintracker.exe

dependencies=$(ldd ./bintracker.exe)
printf '%s\n' "$dependencies"
if grep -q 'not found' <<<"$dependencies"; then
  echo 'A runtime DLL could not be resolved.' >&2
  exit 1
fi

while IFS= read -r dependency; do
  case "$dependency" in
    "$MINGW_PREFIX"/bin/*.dll) cp -f "$dependency" . ;;
  esac
done < <(awk '/=> \// { print $3 }' <<<"$dependencies")

objdump -f bintracker.exe | tee object-format.txt
grep -F "architecture: $OBJECT_ARCH" object-format.txt

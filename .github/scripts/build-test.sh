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

wish="$MINGW_PREFIX/bin/wish.exe"
wish_dependencies=$(ldd "$wish")
printf '%s\n' "$wish_dependencies"
if grep -q 'not found' <<<"$wish_dependencies"; then
  echo 'A Wish runtime DLL could not be resolved.' >&2
  exit 1
fi

rm -rf bin lib
mkdir -p bin lib
cp "$wish" bin/
while IFS= read -r dependency; do
  case "$dependency" in
    "$MINGW_PREFIX"/bin/*.dll) cp -f "$dependency" bin/ ;;
  esac
done < <(awk '/=> \// { print $3 }' <<<"$wish_dependencies")
cp -r "$MINGW_PREFIX/lib/tcl8.6" "$MINGW_PREFIX/lib/tk8.6" lib/

test -f bin/wish.exe
test -f bin/tcl86.dll
test -f bin/tk86.dll
test -f bin/zlib1.dll
test -f lib/tcl8.6/init.tcl
test -f lib/tk8.6/tk.tcl

objdump -f bintracker.exe | tee object-format.txt
grep -F "architecture: $OBJECT_ARCH" object-format.txt

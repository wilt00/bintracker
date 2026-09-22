#!/usr/bin/env bash
set -euo pipefail

: "${ARCH:?ARCH must be set}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}"
: "${RUNNER_TEMP:?RUNNER_TEMP must be set}"

stage="$RUNNER_TEMP/bintracker"
archive="$GITHUB_WORKSPACE/bintracker-windows-$ARCH.zip"
rm -rf "$stage"
mkdir -p "$stage/3rdparty"

cp build/bintracker.exe "$stage/"
cp build/*.import.scm "$stage/"
find build -maxdepth 1 -type f -iname '*.dll' -exec cp -f '{}' "$stage/" ';'
cp build/3rdparty/tclkit.exe "$stage/3rdparty/"
cp -r build/config build/mame-bridge build/mdal-targets build/mdef \
  build/plugins build/resources build/roms build/tunes "$stage/"
cp LICENSE "$stage/"

test -f "$stage/bintracker.exe"
test -f "$stage/bintracker-core.import.scm"
test -f "$stage/3rdparty/tclkit.exe"
test ! -e "$stage/3rdparty/mame"
if find "$stage" -type f -iname 'mame.exe' -print -quit | grep -q .; then
  echo 'The package unexpectedly contains mame.exe.' >&2
  exit 1
fi
grep -F 'program-name: "mame.exe"' "$stage/config/emulators.windows.scm"

(
  cd "$stage"
  zip -q -9 -r "$archive" .
)

verify="$RUNNER_TEMP/archive-check"
rm -rf "$verify"
mkdir -p "$verify"
unzip -q "$archive" -d "$verify"
test -f "$verify/bintracker.exe"
for import_file in build/*.import.scm; do
  test -f "$verify/$(basename "$import_file")"
done
test -f "$verify/3rdparty/tclkit.exe"
test -f "$verify/resources/icons/save.png"
test -f "$verify/mdef/4VoiceMusicPlayer/4VoiceMusicPlayer.mdef"

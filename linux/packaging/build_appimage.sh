#!/bin/bash
# Builds an AppImage from the release bundle (no root needed to run it).
# Usage: bash linux/packaging/build_appimage.sh <version>
set -euo pipefail
VERSION="${1:-0.1.0}"
BUNDLE="build/linux/x64/release/bundle"
APPDIR="build/appimage/Streakin.AppDir" # TODO(rename)

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
cp linux/packaging/in.incantum.streakin.individual.desktop "$APPDIR/"
cp assets/icon.png "$APPDIR/in.incantum.streakin.individual.png"
cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/usr/bin/streakin" "$@"
RUN
chmod +x "$APPDIR/AppRun"

if [ ! -x appimagetool ]; then
  curl -fsSL -o appimagetool \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x appimagetool
fi
ARCH=x86_64 ./appimagetool --appimage-extract-and-run "$APPDIR" "build/appimage/Streakin-$VERSION-x86_64.AppImage"

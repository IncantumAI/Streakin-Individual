#!/bin/bash
# Builds a .deb from the release bundle. Usage: bash linux/packaging/build_deb.sh <version>
# Requires: flutter build linux --release already run.
set -euo pipefail
VERSION="${1:-0.1.0}"
BUNDLE="build/linux/x64/release/bundle"
# TODO(rename): package + binary name (spec §19 item 6).
PKG="streakin"
ROOT="build/deb/${PKG}_${VERSION}"

rm -rf "$ROOT"
mkdir -p "$ROOT/DEBIAN" "$ROOT/opt/$PKG" "$ROOT/usr/share/applications" \
         "$ROOT/usr/share/icons/hicolor/512x512/apps" "$ROOT/usr/bin"
cp -r "$BUNDLE/." "$ROOT/opt/$PKG/"
cp linux/packaging/in.incantum.streakin.individual.desktop "$ROOT/usr/share/applications/"
cp assets/icon.png "$ROOT/usr/share/icons/hicolor/512x512/apps/in.incantum.streakin.individual.png"
ln -s "/opt/$PKG/$PKG" "$ROOT/usr/bin/$PKG"

cat > "$ROOT/DEBIAN/control" <<CTL
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1 | libappindicator3-1
Maintainer: Incantum <hello@incantum.in>
Description: Private, offline-first habit tracker and notetaker.
CTL

cat > "$ROOT/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
command -v update-desktop-database >/dev/null && update-desktop-database -q || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
POST
chmod 755 "$ROOT/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "$ROOT" "build/deb/${PKG}_${VERSION}_amd64.deb"
echo "Built build/deb/${PKG}_${VERSION}_amd64.deb"

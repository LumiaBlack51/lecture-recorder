#!/usr/bin/env bash
set -euo pipefail
umask 022

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PACKAGE_NAME="lecture-recorder"
BINARY_NAME="lecture_recorder"
APP_NAME="Lecture Recorder"
VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
ARCH="${DEB_ARCH:-$(dpkg --print-architecture)}"

if [[ -z "$VERSION" ]]; then
  echo "Unable to read version from pubspec.yaml." >&2
  exit 1
fi

if [[ "$ARCH" != "amd64" ]]; then
  echo "This packaging script currently supports amd64 Linux builds only." >&2
  exit 1
fi

OUT_DIR="$ROOT_DIR/dist"
WORK_DIR="$OUT_DIR/deb"
PACKAGE_DIR="$WORK_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"
DEB_PATH="$OUT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"

rm -rf "$WORK_DIR"
rm -rf "$ROOT_DIR/build/linux"
mkdir -p "$PACKAGE_DIR"

export PATH="/usr/bin:$PATH"
export CC="${CC:-/usr/bin/clang}"
export CXX="${CXX:-/usr/bin/clang++}"

flutter build linux --release

install -d "$PACKAGE_DIR/DEBIAN"
install -d "$PACKAGE_DIR/opt/$PACKAGE_NAME"
install -d "$PACKAGE_DIR/usr/bin"
install -d "$PACKAGE_DIR/usr/share/applications"
install -d "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUNDLE_DIR/." "$PACKAGE_DIR/opt/$PACKAGE_NAME/"
ln -s "/opt/$PACKAGE_NAME/$BINARY_NAME" "$PACKAGE_DIR/usr/bin/$PACKAGE_NAME"
install -m 0644 assets/icons/app_icon.png \
  "$PACKAGE_DIR/usr/share/icons/hicolor/256x256/apps/$PACKAGE_NAME.png"

cat >"$PACKAGE_DIR/usr/share/applications/$PACKAGE_NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Course-based lecture recorder
Exec=$PACKAGE_NAME
Icon=$PACKAGE_NAME
Terminal=false
Categories=AudioVideo;Audio;Recorder;
StartupWMClass=com.must.lecture_recorder
DESKTOP

installed_size="$(du -ks "$PACKAGE_DIR" | cut -f1)"
cat >"$PACKAGE_DIR/DEBIAN/control" <<CONTROL
Package: $PACKAGE_NAME
Version: $VERSION
Section: sound
Priority: optional
Architecture: $ARCH
Maintainer: LumiaBlack51 <LumiaBlack51@users.noreply.github.com>
Installed-Size: $installed_size
Depends: libc6, libstdc++6, libgtk-3-0 | libgtk-3-0t64, libgstreamer1.0-0, gstreamer1.0-plugins-base, libpulse0, libasound2 | libasound2t64, xdg-utils
Description: Cross-platform lecture recorder
 Lecture Recorder provides course-based recording, automatic segmentation,
 bilingual Chinese and English UI, and a recordings manager.
CONTROL

fakeroot dpkg-deb --build --root-owner-group "$PACKAGE_DIR" "$DEB_PATH"
echo "$DEB_PATH"

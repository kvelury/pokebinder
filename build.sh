#!/bin/bash
# Builds PokéBinder.app into build/PokéBinder.app.
#   --install   also replace /Applications/PokéBinder.app with the fresh build
# Installing is opt-in on purpose: during development this script runs constantly,
# and silently replacing the copy in /Applications on every build makes it
# ambiguous which PokéBinder you're running.
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        -h|--help)
            echo "Usage: ./build.sh [--install]"
            echo "  --install   copy the built app over /Applications/PokéBinder.app"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

echo "==> Building PokéBinder (release)…"
swift build -c release

APP=build/PokéBinder.app
echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# SPM emits the ASCII target name; CFBundleExecutable must match the filename
# we place in Contents/MacOS, which is the accented display name.
cp .build/release/PokeBinder "$APP/Contents/MacOS/PokéBinder"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad-hoc)…"
codesign --force --sign - "$APP"

if [ "$INSTALL" = true ]; then
    DEST="/Applications/PokéBinder.app"
    if [ ! -w /Applications ]; then
        echo "==> Cannot write to /Applications — re-run with sudo, or copy manually:" >&2
        echo "    sudo cp -R \"$PWD/$APP\" /Applications/" >&2
        exit 1
    fi
    # Replacing the bundle out from under a running copy leaves it half-broken.
    # Bundle id, not display name — immune to the rename and LaunchServices' name cache.
    osascript -e 'quit app id "com.pokebinder.app"' >/dev/null 2>&1 || true
    echo "==> Installing to ${DEST}…"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "==> Done. Installed to ${DEST}."
else
    echo "==> Done. Launch with: open ${APP}"
    echo "    (./build.sh --install also replaces /Applications/PokéBinder.app)"
fi

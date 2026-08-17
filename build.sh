#!/bin/bash
# Builds PokeBinder.app into build/PokeBinder.app.
#   --install   also replace /Applications/PokeBinder.app with the fresh build
# Installing is opt-in on purpose: during development this script runs constantly,
# and silently replacing the copy in /Applications on every build makes it
# ambiguous which PokeBinder you're running.
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        -h|--help)
            echo "Usage: ./build.sh [--install]"
            echo "  --install   copy the built app over /Applications/PokeBinder.app"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 1
            ;;
    esac
done

echo "==> Building PokeBinder (release)…"
swift build -c release

APP=build/PokeBinder.app
echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PokeBinder "$APP/Contents/MacOS/PokeBinder"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (ad-hoc)…"
codesign --force --sign - "$APP"

if [ "$INSTALL" = true ]; then
    DEST="/Applications/PokeBinder.app"
    if [ ! -w /Applications ]; then
        echo "==> Cannot write to /Applications — re-run with sudo, or copy manually:" >&2
        echo "    sudo cp -R \"$PWD/$APP\" /Applications/" >&2
        exit 1
    fi
    # Replacing the bundle out from under a running copy leaves it half-broken.
    osascript -e 'quit app "PokeBinder"' >/dev/null 2>&1 || true
    echo "==> Installing to ${DEST}…"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "==> Done. Installed to ${DEST}."
else
    echo "==> Done. Launch with: open ${APP}"
    echo "    (./build.sh --install also replaces /Applications/PokeBinder.app)"
fi

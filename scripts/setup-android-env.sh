#!/usr/bin/env bash
# Install the Android SDK/NDK, CMake and vcpkg needed to build the APK.
#
#   ./scripts/setup-android-env.sh            # installs into ./.toolchain
#   TOOLCHAIN_DIR=/opt/krkr ./scripts/setup-android-env.sh
#
# Afterwards run:  source ./.toolchain/env.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$ROOT/.toolchain}"
SDK_DIR="$TOOLCHAIN_DIR/android-sdk"
VCPKG_DIR="$TOOLCHAIN_DIR/vcpkg"
NDK_VERSION="28.0.13004108"
CMAKE_VERSION="3.31.1"
CMDLINE_TOOLS_ZIP="commandlinetools-linux-11076708_latest.zip"

mkdir -p "$TOOLCHAIN_DIR"

for tool in git curl unzip java bison python3 nasm; do
    command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done
command -v yasm >/dev/null || echo "warning: yasm not found (needed by ffmpeg on some hosts)" >&2

if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/$CMDLINE_TOOLS_ZIP" "https://dl.google.com/android/repository/$CMDLINE_TOOLS_ZIP"
    unzip -q "$tmp/$CMDLINE_TOOLS_ZIP" -d "$tmp"
    mkdir -p "$SDK_DIR/cmdline-tools"
    mv "$tmp/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
    rm -rf "$tmp"
fi

SDKMANAGER="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKMANAGER" --sdk_root="$SDK_DIR" --licenses >/dev/null || true
"$SDKMANAGER" --sdk_root="$SDK_DIR" \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "cmake;$CMAKE_VERSION" \
    "ndk;$NDK_VERSION"

if [ ! -x "$VCPKG_DIR/vcpkg" ]; then
    [ -d "$VCPKG_DIR/.git" ] || git clone https://github.com/microsoft/vcpkg.git "$VCPKG_DIR"
    "$VCPKG_DIR/bootstrap-vcpkg.sh" -disableMetrics
fi

cat > "$TOOLCHAIN_DIR/env.sh" <<ENV
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export ANDROID_SDK="$SDK_DIR"
export ANDROID_NDK="$SDK_DIR/ndk/$NDK_VERSION"
export ANDROID_NDK_HOME="$SDK_DIR/ndk/$NDK_VERSION"
export VCPKG_ROOT="$VCPKG_DIR"
export PATH="$SDK_DIR/cmake/$CMAKE_VERSION/bin:\$PATH"
ENV

echo
echo "Toolchain ready. Run:  source $TOOLCHAIN_DIR/env.sh"

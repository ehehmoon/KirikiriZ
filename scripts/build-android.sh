#!/usr/bin/env bash
# Build the Android APK.
#
#   ./scripts/build-android.sh                 # release, arm64-v8a
#   ./scripts/build-android.sh debug
#   ABIS=arm64-v8a,x86_64 ./scripts/build-android.sh release
#
# Signing (release): uses $KEYSTORE_FILE / $KEYSTORE_PASSWORD / $KEY_ALIAS /
# $KEY_PASSWORD when set, otherwise creates a local keystore in
# ./.toolchain/release.keystore and keeps reusing it so updates install over
# the previous version.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_TYPE="${1:-release}"
ABIS="${ABIS:-arm64-v8a}"
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$ROOT/.toolchain}"
ANDROID_DIR="$ROOT/upstream/krkr2/platforms/android"

if [ -f "$TOOLCHAIN_DIR/env.sh" ]; then
    # shellcheck disable=SC1091
    source "$TOOLCHAIN_DIR/env.sh"
fi
for var in ANDROID_HOME ANDROID_NDK VCPKG_ROOT; do
    if [ -z "${!var:-}" ]; then
        echo "$var is not set; run ./scripts/setup-android-env.sh first" >&2
        exit 1
    fi
done
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_NDK}"

"$ROOT/scripts/apply-patches.sh"

case "$BUILD_TYPE" in
    release) TASK=assembleRelease ;;
    debug)   TASK=assembleDebug ;;
    *) echo "usage: $0 [release|debug]" >&2; exit 1 ;;
esac

if [ "$BUILD_TYPE" = release ]; then
    if [ -z "${KEYSTORE_FILE:-}" ]; then
        KEYSTORE_FILE="$TOOLCHAIN_DIR/release.keystore"
        KEY_ALIAS="${KEY_ALIAS:-krkrz}"
        if [ ! -f "$KEYSTORE_FILE" ]; then
            mkdir -p "$TOOLCHAIN_DIR"
            pass="$(od -An -tx1 -N12 /dev/urandom | tr -d " \n")"
            keytool -genkeypair -keystore "$KEYSTORE_FILE" -alias "$KEY_ALIAS" \
                -keyalg RSA -keysize 2048 -validity 10000 \
                -storepass "$pass" -keypass "$pass" \
                -dname "CN=KirikiriZ Android, O=Local Build" >/dev/null
            printf '%s' "$pass" > "$KEYSTORE_FILE.pass"
            chmod 600 "$KEYSTORE_FILE" "$KEYSTORE_FILE.pass"
        fi
        KEYSTORE_PASSWORD="$(cat "$KEYSTORE_FILE.pass")"
        KEY_PASSWORD="$KEYSTORE_PASSWORD"
    fi
    # upstream build.gradle reads app/sign.properties + app/sign.keystore
    cp "$KEYSTORE_FILE" "$ANDROID_DIR/app/sign.keystore"
    cat > "$ANDROID_DIR/app/sign.properties" <<PROPS
SIGN_STORE_PASS=$KEYSTORE_PASSWORD
SIGN_KEY_ALIAS=$KEY_ALIAS
SIGN_KEY_PASS=${KEY_PASSWORD:-$KEYSTORE_PASSWORD}
PROPS
fi

"$ANDROID_DIR/gradlew" -p "$ANDROID_DIR" --console=plain --no-daemon \
    "-PkrkrAbis=$ABIS" "$TASK"

mkdir -p "$ROOT/dist"
find "$ANDROID_DIR/out/android/app/outputs/apk/$BUILD_TYPE" -name '*.apk' \
    -exec cp -v {} "$ROOT/dist/" \;
echo "APK(s) copied to $ROOT/dist"

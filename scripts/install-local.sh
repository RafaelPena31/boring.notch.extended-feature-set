#!/bin/bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_CONFIG="$ROOT_DIR/.local-signing.env"
readonly DERIVED_DATA="$ROOT_DIR/.build/local-install"
readonly BUILT_APP="$DERIVED_DATA/Build/Products/Release/boringNotch.app"
readonly INSTALLED_APP="/Applications/boringNotch.app"

fail() {
    echo "error: $*" >&2
    exit 1
}

[[ -f "$SIGNING_CONFIG" ]] || fail "create .local-signing.env as described in BUILDING.md"
# shellcheck source=/dev/null
source "$SIGNING_CONFIG"
[[ -n "${DEVELOPMENT_TEAM:-}" ]] || fail "DEVELOPMENT_TEAM must be set in .local-signing.env"
readonly TEAM_ID="$DEVELOPMENT_TEAM"

team_id() {
    /usr/bin/codesign -dv --verbose=4 "$1" 2>&1 \
        | /usr/bin/awk -F= '/^TeamIdentifier=/{ print $2; exit }'
}

sandbox_value() {
    /usr/bin/codesign -d --entitlements - "$1" 2>&1 \
        | /usr/bin/awk '/\[Key\] com.apple.security.app-sandbox/{ getline; getline; print $2; exit }'
}

validate_app() {
    local app="$1"
    local helper="$app/Contents/XPCServices/BoringNotchXPCHelper.xpc"

    [[ -d "$helper" ]] || fail "XPC helper not found in $app"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
    [[ "$(team_id "$app")" == "$TEAM_ID" ]] || fail "main app is not signed by the configured development team"
    [[ "$(team_id "$helper")" == "$TEAM_ID" ]] || fail "XPC helper is not signed by the configured development team"
    [[ "$(sandbox_value "$app")" == "true" ]] || fail "main app sandbox is not enabled"
    [[ "$(sandbox_value "$helper")" == "false" ]] || fail "XPC helper sandbox must be disabled"
}

revision="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
checkout_state="clean"
[[ -z "$(git -C "$ROOT_DIR" status --porcelain --untracked-files=normal)" ]] || checkout_state="with local changes"

echo "Building boringNotch $revision ($checkout_state)..."
/bin/rm -rf "$DERIVED_DATA"

xcodebuild \
    -quiet \
    -project "$ROOT_DIR/boringNotch.xcodeproj" \
    -scheme boringNotch \
    -configuration Release \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="Apple Development" \
    build

[[ -d "$BUILT_APP" ]] || fail "build completed without producing $BUILT_APP"
validate_app "$BUILT_APP"

/usr/bin/osascript -e 'tell application id "theboringteam.boringnotch" to quit' 2>/dev/null || true
/bin/sleep 1
/bin/rm -rf "$INSTALLED_APP"
/usr/bin/ditto "$BUILT_APP" "$INSTALLED_APP"

validate_app "$INSTALLED_APP"
/usr/bin/open "$INSTALLED_APP"

echo "Installed boringNotch $revision ($checkout_state) with the configured development team."

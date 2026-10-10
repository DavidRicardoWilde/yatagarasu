#!/usr/bin/env bash
#
# Builds a standalone Yatagarasu.app (Release, universal) that launches by
# double-clicking, then packages it as a .zip and a drag-to-install .dmg.
#
# Usage:
#   scripts/package-app.sh [options]
#
# Options:
#   --install             Also copy the app into /Applications (or --install-dir).
#   --install-dir DIR     Where --install puts the app. Default: /Applications.
#   --version X.Y.Z       CFBundleShortVersionString. Default: "version" in package.json.
#   --build-number N      CFBundleVersion. Default: 1.
#   --sign IDENTITY       Code-signing identity, e.g. "Developer ID Application: …".
#                         Default: "-" (ad-hoc), which needs no Apple account.
#   --team TEAM_ID        Team for --sign. Default: the project's team.
#   --no-dmg              Skip the .dmg (the .zip is always produced).
#   -h, --help            Show this help.
#
# The same settings can come from the environment: YATAGARASU_VERSION,
# YATAGARASU_BUILD_NUMBER, YATAGARASU_SIGN_IDENTITY, YATAGARASU_TEAM_ID.
# YATAGARASU_BUILD_DIR overrides the temporary build folder.
#
# Output (apps/macos/dist/):
#   Yatagarasu.app
#   Yatagarasu-<version>-macOS.zip
#   Yatagarasu-<version>-macOS.dmg
#   SHA256SUMS.txt

set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Build outside the repo: folders synced by iCloud Drive (e.g. ~/Documents) tag
# files with Finder metadata, which codesign rejects.
BUILD_DIR="${YATAGARASU_BUILD_DIR:-${TMPDIR:-/tmp}/yatagarasu-package}"
DIST_DIR="$APP_ROOT/dist"
APP_NAME="Yatagarasu"
DEFAULT_TEAM_ID="75896D6FVL"

install=false
install_dir="/Applications"
make_dmg=true
version="${YATAGARASU_VERSION:-}"
build_number="${YATAGARASU_BUILD_NUMBER:-1}"
sign_identity="${YATAGARASU_SIGN_IDENTITY:--}"
team_id="${YATAGARASU_TEAM_ID:-$DEFAULT_TEAM_ID}"

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) install=true ;;
    --install-dir) install_dir="${2:?--install-dir needs a directory}"; shift ;;
    --version) version="${2:?--version needs a value}"; shift ;;
    --build-number) build_number="${2:?--build-number needs a value}"; shift ;;
    --sign) sign_identity="${2:?--sign needs an identity}"; shift ;;
    --team) team_id="${2:?--team needs a team ID}"; shift ;;
    --no-dmg) make_dmg=false ;;
    -h|--help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

if [[ -z "$version" ]]; then
  version="$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$APP_ROOT/package.json" | head -n 1)"
fi
[[ "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || die "version must look like 1, 1.2 or 1.2.3 (got '$version')"
[[ "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || die "build number must be numeric (got '$build_number')"

# Ad-hoc signing works on any Mac without an Apple account; a real identity
# (e.g. Developer ID) is needed for Gatekeeper-friendly distribution.
if [[ "$sign_identity" == "-" ]]; then
  signing_settings=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
else
  signing_settings=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$sign_identity" "DEVELOPMENT_TEAM=$team_id" "OTHER_CODE_SIGN_FLAGS=--timestamp")
fi

step "Building $APP_NAME $version ($build_number), signing: $sign_identity"
rm -rf "$BUILD_DIR/$APP_NAME.xcarchive" "$BUILD_DIR/stage" "$DIST_DIR"
mkdir -p "$BUILD_DIR/stage" "$DIST_DIR"

xcodebuild archive \
  -quiet \
  -project "$APP_ROOT/yatagarasu.xcodeproj" \
  -scheme yatagarasu \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  "MARKETING_VERSION=$version" \
  "CURRENT_PROJECT_VERSION=$build_number" \
  "${signing_settings[@]}"

archived_app="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/yatagarasu.app"
[[ -d "$archived_app" ]] || die "archive did not contain $archived_app"

# The bundle folder is renamed for a tidy Applications folder; the signature
# doesn't cover the folder name, so this is safe. Packages are made from this
# staged copy so they never pick up Finder metadata from the repo folder.
app="$BUILD_DIR/stage/$APP_NAME.app"
ditto "$archived_app" "$app"

step "Verifying"
codesign --verify --deep --strict "$app"
echo "signature OK"
echo "architectures: $(lipo -archs "$app/Contents/MacOS/yatagarasu")"
echo "version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist"))"

step "Packaging"
zip_path="$DIST_DIR/$APP_NAME-$version-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip_path"
echo "$(basename "$zip_path")"

if $make_dmg; then
  dmg_path="$DIST_DIR/$APP_NAME-$version-macOS.dmg"
  staging="$BUILD_DIR/dmg"
  rm -rf "$staging"
  mkdir -p "$staging"
  ditto "$app" "$staging/$APP_NAME.app"
  ln -s /Applications "$staging/Applications"
  # hdiutil occasionally fails with "Resource busy" on CI machines; retry a few times.
  for attempt in 1 2 3; do
    if hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$staging" -ov -format UDZO "$dmg_path"; then
      break
    fi
    [[ $attempt -lt 3 ]] || die "hdiutil create failed"
    sleep 5
  done
  rm -rf "$staging"
  echo "$(basename "$dmg_path")"
fi

ditto "$app" "$DIST_DIR/$APP_NAME.app"

(
  cd "$DIST_DIR"
  shopt -s nullglob
  shasum -a 256 -- *.zip *.dmg > SHA256SUMS.txt
)

if $install; then
  step "Installing into $install_dir"
  [[ -d "$install_dir" && -w "$install_dir" ]] || die "can't write to $install_dir (try --install-dir ~/Applications)"
  if pgrep -xq yatagarasu; then
    echo "note: Yatagarasu is running; quit and reopen it to use the new build."
  fi
  rm -rf "${install_dir:?}/$APP_NAME.app"
  ditto "$app" "$install_dir/$APP_NAME.app"
  echo "installed $install_dir/$APP_NAME.app"
fi

step "Done"
echo "$DIST_DIR"

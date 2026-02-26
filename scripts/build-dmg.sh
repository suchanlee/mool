#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build a distributable DMG for Mool.

Usage:
  ./scripts/build-dmg.sh [options]

Options:
  --project PATH               Xcode project path (default: Mool.xcodeproj)
  --scheme NAME                Xcode scheme (default: Mool)
  --configuration NAME         Build configuration (default: Release)
  --derived-data PATH          DerivedData output path (default: build/DerivedData-dmg)
  --output-dir PATH            Output directory for DMG assets (default: build)
  --dmg-name NAME              DMG file base name without extension (default: Mool)
  --volume-name NAME           Mounted DMG volume name (default: Mool)
  --app-path PATH              Use existing .app bundle instead of building
  --skip-xcodegen              Skip xcodegen generate
  --skip-build                 Skip xcodebuild (requires --app-path)
  --clean                      Remove previous staging directory and target DMG first
  --sign-identity NAME         Sign app and DMG with this identity
  --notarize                   Notarize DMG (requires --sign-identity)
  --apple-id EMAIL             Apple ID for notarytool (when not using keychain profile)
  --team-id TEAMID             Apple team ID for notarytool
  --app-password PASSWORD      App-specific password for notarytool
  --keychain-profile NAME      notarytool keychain profile (preferred over apple-id/team-id/password)
  -h, --help                   Show this help

Examples:
  ./scripts/build-dmg.sh
  ./scripts/build-dmg.sh --sign-identity "Developer ID Application: Name (TEAMID)"
  ./scripts/build-dmg.sh --sign-identity "Developer ID Application: Name (TEAMID)" --notarize --keychain-profile "AC_NOTARY"
EOF
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

project="Mool.xcodeproj"
scheme="Mool"
configuration="Release"
derived_data_path="build/DerivedData-dmg"
output_dir="build"
dmg_name="Mool"
volume_name="Mool"
app_path=""

skip_xcodegen=false
skip_build=false
clean=false

sign_identity=""
notarize=false
apple_id=""
team_id=""
app_password=""
keychain_profile=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      project="$2"
      shift 2
      ;;
    --scheme)
      scheme="$2"
      shift 2
      ;;
    --configuration)
      configuration="$2"
      shift 2
      ;;
    --derived-data)
      derived_data_path="$2"
      shift 2
      ;;
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --dmg-name)
      dmg_name="$2"
      shift 2
      ;;
    --volume-name)
      volume_name="$2"
      shift 2
      ;;
    --app-path)
      app_path="$2"
      shift 2
      ;;
    --skip-xcodegen)
      skip_xcodegen=true
      shift
      ;;
    --skip-build)
      skip_build=true
      shift
      ;;
    --clean)
      clean=true
      shift
      ;;
    --sign-identity)
      sign_identity="$2"
      shift 2
      ;;
    --notarize)
      notarize=true
      shift
      ;;
    --apple-id)
      apple_id="$2"
      shift 2
      ;;
    --team-id)
      team_id="$2"
      shift 2
      ;;
    --app-password)
      app_password="$2"
      shift 2
      ;;
    --keychain-profile)
      keychain_profile="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$skip_build" == true && -z "$app_path" ]]; then
  echo "--skip-build requires --app-path" >&2
  exit 2
fi

if [[ "$notarize" == true && -z "$sign_identity" ]]; then
  echo "--notarize requires --sign-identity" >&2
  exit 2
fi

if [[ "$notarize" == true && -z "$keychain_profile" ]]; then
  if [[ -z "$apple_id" || -z "$team_id" || -z "$app_password" ]]; then
    echo "Notarization requires either --keychain-profile or all of --apple-id, --team-id, --app-password" >&2
    exit 2
  fi
fi

require_tool xcodebuild
require_tool hdiutil

if [[ "$skip_xcodegen" == false ]]; then
  require_tool xcodegen
fi

if [[ "$notarize" == true ]]; then
  require_tool xcrun
fi

mkdir -p "$output_dir"

dmg_root="$output_dir/dmg-root"
dmg_path="$output_dir/$dmg_name.dmg"

if [[ "$clean" == true ]]; then
  rm -rf "$dmg_root"
  rm -f "$dmg_path"
fi

if [[ -z "$app_path" ]]; then
  if [[ "$skip_xcodegen" == false ]]; then
    echo "==> Generating Xcode project"
    xcodegen generate
  fi

  if [[ "$skip_build" == false ]]; then
    echo "==> Building app ($scheme, $configuration)"
    xcodebuild -project "$project" -scheme "$scheme" -configuration "$configuration" -destination 'platform=macOS' -derivedDataPath "$derived_data_path" build
  fi

  app_path="$derived_data_path/Build/Products/$configuration/$scheme.app"
fi

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 1
fi

if [[ -n "$sign_identity" ]]; then
  echo "==> Signing app bundle"
  codesign --force --deep --options runtime --timestamp --sign "$sign_identity" "$app_path"
fi

echo "==> Preparing DMG payload"
rm -rf "$dmg_root"
mkdir -p "$dmg_root"
cp -R "$app_path" "$dmg_root/$scheme.app"
ln -s /Applications "$dmg_root/Applications"

echo "==> Creating DMG: $dmg_path"
rm -f "$dmg_path"
hdiutil create -volname "$volume_name" -srcfolder "$dmg_root" -ov -format UDZO "$dmg_path" >/dev/null

if [[ -n "$sign_identity" ]]; then
  echo "==> Signing DMG"
  codesign --force --timestamp --sign "$sign_identity" "$dmg_path"
fi

if [[ "$notarize" == true ]]; then
  echo "==> Submitting DMG for notarization"
  if [[ -n "$keychain_profile" ]]; then
    xcrun notarytool submit "$dmg_path" --keychain-profile "$keychain_profile" --wait
  else
    xcrun notarytool submit "$dmg_path" --apple-id "$apple_id" --password "$app_password" --team-id "$team_id" --wait
  fi

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
fi

echo "Done: $dmg_path"

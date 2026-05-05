#!/usr/bin/env bash
# Release helper: builds Android, iOS (if macOS), and web outputs.
set -euo pipefail

echo "Release helper script"

case "${1:-}" in
  android)
    echo "Building Android APK"
    cd ALS-LMS/apps/mobile_app
    flutter build apk --release
    ;;
  appbundle)
    echo "Building Android App Bundle"
    cd ALS-LMS/apps/mobile_app
    flutter build appbundle --release
    ;;
  ios)
    echo "Building iOS (requires macOS and signing configured)"
    cd ALS-LMS/apps/mobile_app
    flutter build ipa --release
    ;;
  web)
    echo "Building web"
    cd ALS-LMS/apps/admin_web
    flutter build web --release
    ;;
  pub)
    echo "Prepare packages for pub (only for packages with publish_to not 'none')"
    echo "Check each package's pubspec.yaml and run 'flutter pub publish --dry-run' as needed"
    ;;
  *)
    echo "Usage: $0 {android|appbundle|ios|web|pub}"
    exit 1
    ;;
esac

# Copilot Island – Just recipes
# Run `just` or `just --list` to see commands.

project := "copilot-island"
scheme := "copilot-island"
destination := "platform=macOS"
app_bundle := "Copilot Island"

default:
    @just --list

# Build Release (used by dmg)
build:
    xcodebuild -project "{{project}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -configuration Release \
        -derivedDataPath build/DerivedData \
        -destination "{{destination}}" \
        CONFIGURATION_BUILD_DIR="build/Release" \
        clean build

# Build and run the app
run:
    xcodebuild -project "{{project}}.xcodeproj" \
        -scheme "{{scheme}}" \
        -destination "{{destination}}" \
        build
    open "build/Build/Products/Debug/{{app_bundle}}.app"

# Run tests
test:
    xcodebuild test -scheme "{{scheme}}" -destination "{{destination}}" -enableCodeCoverage YES

# Create a fancy DMG (Release build + gradient background, icon layout)
# Usage: `just dmg` or `just dmg true` to skip the build step
dmg skip_build="false":
    #!/usr/bin/env bash
    if [ "{{skip_build}}" = "true" ]; then
        ./scripts/build-dmg.sh --skip-build
    else
        ./scripts/build-dmg.sh
    fi

# Set version across app and plugin (e.g. `just set-version 0.3.0`)
set-version version:
    ./scripts/set-version.sh "{{version}}"

# Show current version
version:
    ./scripts/set-version.sh

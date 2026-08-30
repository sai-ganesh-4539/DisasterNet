#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

export GRADLE_USER_HOME="$SCRIPT_DIR/.gradle-local"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"

echo "Using GRADLE_USER_HOME=$GRADLE_USER_HOME"
echo "Using JAVA_HOME=$JAVA_HOME"
flutter pub get --offline
flutter run --android-skip-build-dependency-validation "$@"

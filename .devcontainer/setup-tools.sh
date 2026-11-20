#!/usr/bin/env bash
set -euo pipefail

# Installs Android command-line tools and a current stable API/build-tools set.
# This only prepares the Codespace container; it does not build, sign, or publish an app.
ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
CMDLINE_TOOLS_REVISION="11076708"
mkdir -p "${ANDROID_HOME}/cmdline-tools"
archive="$(mktemp --suffix=.zip)"
curl --fail --location --retry 3 \
  "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_REVISION}_latest.zip" \
  --output "${archive}"
unzip -q "${archive}" -d "${ANDROID_HOME}/cmdline-tools"
mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest"
rm -f "${archive}"

export PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"
yes | sdkmanager --licenses >/dev/null
sdkmanager \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0"

# Use the supported npx invocation; do not install Supabase CLI globally.
npx --yes supabase@latest --version
psql --version
java -version
docker --version

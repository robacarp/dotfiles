#!/usr/bin/env bash
# Rebuilds and re-signs SoundHelper.app in place. NOTE: every rebuild
# produces a new ad-hoc signature, which macOS treats as a new identity -
# expect a fresh kTCCServiceAudioCapture permission prompt after running
# this, even though it's "the same" app to a human.
set -euo pipefail
cd "$(dirname "$0")"

APP=~/.hammerspoon/SoundHelper.app
swiftc main.swift -o soundhelper_bin
mkdir -p "$APP/Contents/MacOS"
cp soundhelper_bin "$APP/Contents/MacOS/SoundHelper"
cp Info.plist "$APP/Contents/Info.plist"
codesign -s - --force --deep "$APP"
echo "Built and signed $APP - relaunch it (or reload Hammerspoon) and approve the permission prompt."

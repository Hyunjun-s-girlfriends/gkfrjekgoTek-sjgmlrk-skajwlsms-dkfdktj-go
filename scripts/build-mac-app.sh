#!/bin/sh
set -eu

APP_NAME="StudyPulsDashboard"
BUILD_DIR=".build/release"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

swift build -c release --product "${APP_NAME}"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>local.studypuls.dashboard</string>
	<key>CFBundleName</key>
	<string>StudyPuls</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSMotionUsageDescription</key>
	<string>StudyPuls uses AirPods head motion to detect long head-drop drowsiness during study sessions.</string>
</dict>
</plist>
PLIST

echo "Created ${APP_DIR}"

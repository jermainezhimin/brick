#!/bin/bash

# Build the app in release mode
echo "Building Brick..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Create .app bundle structure
APP_NAME="Brick"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp .build/release/Brick "${MACOS_DIR}/"

# Copy entitlements
cp Brick.entitlements "${RESOURCES_DIR}/"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Brick</string>
    <key>CFBundleIdentifier</key>
    <string>com.brick.app</string>
    <key>CFBundleName</key>
    <string>Brick</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Sign the app bundle with ad-hoc signature and entitlements
echo "Signing app bundle..."
codesign --force --deep --sign - --entitlements Brick.entitlements "${APP_BUNDLE}"

if [ $? -ne 0 ]; then
    echo "Warning: Code signing failed, but app may still work"
fi

echo ""
echo "Success! App bundle created at: ${APP_BUNDLE}"
echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "Or double-click ${APP_BUNDLE} in Finder"

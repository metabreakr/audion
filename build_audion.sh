#!/bin/bash
set -e

echo "=== Building Audion with Playlist Feature ==="
echo ""

cd "/Volumes/WD Black 2TB/Claude/audion"

# Check if we need to add files to project
echo "Note: The playlist Swift files need to be manually added to the Xcode project"
echo "before building. However, I'll attempt to build anyway in case they're already added."
echo ""

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project Audion.xcodeproj -scheme Audion -configuration Release

# Build the app
echo ""
echo "Building Audion..."
xcodebuild build \
  -project Audion.xcodeproj \
  -scheme Audion \
  -configuration Release \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo ""
    echo "=== Build Successful! ==="
    echo ""
    echo "Application location:"
    find ./DerivedData -name "Audion.app" -type d | head -1
    echo ""
    echo "To run the app:"
    echo "  open '$(find ./DerivedData -name "Audion.app" -type d | head -1)'"
else
    echo ""
    echo "=== Build Failed ==="
    echo ""
    echo "This is likely because the playlist Swift files haven't been added to the Xcode project yet."
    echo "Please follow these steps:"
    echo "  1. Open Audion.xcodeproj in Xcode"
    echo "  2. Right-click the 'Audion' folder"
    echo "  3. Select 'Add Files to Audion...'"
    echo "  4. Add these files:"
    echo "     - PlaylistModels.swift"
    echo "     - PlaylistManager.swift"
    echo "     - PlaylistViewController.swift"
    echo "     - PlaylistWindowManager.swift"
    echo "     - PlaylistPreferencesViewController.swift"
    echo "     - PlaylistView.xib"
    echo "  5. Run this script again"
fi

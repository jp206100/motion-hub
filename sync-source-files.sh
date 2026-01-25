#!/bin/bash
#
# sync-source-files.sh
# Syncs repository source files to Xcode project location
#

echo "🔄 Syncing source files to Xcode project..."

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$REPO_ROOT/MotionHub/MotionHub"
TARGET_DIR="$REPO_ROOT/MotionHubApp/MotionHub/MotionHub"

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Target directory not found: $TARGET_DIR"
    echo "   Make sure your Xcode project is in MotionHubApp/"
    exit 1
fi

# Sync files
echo "   Source: $SOURCE_DIR"
echo "   Target: $TARGET_DIR"
echo ""

# Sync each directory
for dir in App Models Views Services Rendering Resources; do
    if [ -d "$SOURCE_DIR/$dir" ]; then
        echo "   ✓ Syncing $dir/"
        rsync -av --delete "$SOURCE_DIR/$dir/" "$TARGET_DIR/$dir/"
    fi
done

# Sync Info.plist if it exists
if [ -f "$SOURCE_DIR/Info.plist" ]; then
    echo "   ✓ Syncing Info.plist"
    cp "$SOURCE_DIR/Info.plist" "$TARGET_DIR/Info.plist"
fi

echo ""
echo "✅ Sync complete! All source files are now up to date."
echo ""
echo "In Xcode:"
echo "1. Clean Build Folder (⇧⌘K)"
echo "2. Build (⌘B)"

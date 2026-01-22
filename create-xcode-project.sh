#!/bin/bash
#
# create-xcode-project.sh
# Creates an Xcode project for Motion Hub using manual GUI steps
#

echo "📱 Creating Xcode Project for Motion Hub"
echo "========================================"
echo ""
echo "Since we're in a terminal environment, I'll guide you through creating"
echo "the Xcode project using Xcode's GUI, which is the standard approach."
echo ""
echo "STEP-BY-STEP INSTRUCTIONS:"
echo ""
echo "1. Open Xcode on your Mac"
echo ""
echo "2. Click 'Create New Project' or File > New > Project"
echo ""
echo "3. Select 'macOS' tab at the top"
echo ""
echo "4. Choose 'App' template and click 'Next'"
echo ""
echo "5. Fill in project details:"
echo "   - Product Name: MotionHub"
echo "   - Team: (leave as None for now)"
echo "   - Organization Identifier: com.motionhub"
echo "   - Bundle Identifier: com.motionhub.MotionHub"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - [ ] Include Tests (unchecked)"
echo ""
echo "6. Click 'Next'"
echo ""
echo "7. IMPORTANT: Navigate to your motion-hub directory"
echo "   Location: $(pwd)"
echo "   Save as: MotionHub"
echo ""
echo "8. Click 'Create'"
echo ""
echo "9. Xcode will create a basic project. Now we need to add our files:"
echo ""
echo "10. In Xcode, RIGHT-CLICK on 'MotionHub' folder in the navigator"
echo "    Select 'Add Files to MotionHub...'"
echo ""
echo "11. Navigate to: MotionHub/MotionHub/"
echo "    Select ALL folders (App, Models, Views, Services, Rendering, Resources)"
echo "    Make sure 'Copy items if needed' is UNCHECKED"
echo "    Make sure 'Create groups' is SELECTED"
echo "    Click 'Add'"
echo ""
echo "12. Delete the auto-generated files Xcode created:"
echo "    - ContentView.swift (we have our own)"
echo "    - MotionHubApp.swift (we have our own)"
echo "    - Right-click > Delete > Move to Trash"
echo ""
echo "13. Select your project in the navigator (blue icon at top)"
echo "    Select 'MotionHub' target"
echo "    Go to 'Info' tab"
echo "    Set 'Custom macOS Application Target Properties'"
echo "    Click '+' to add:"
echo "    - NSMicrophoneUsageDescription: Motion Hub needs access to audio input"
echo ""
echo "14. Go to 'Signing & Capabilities' tab"
echo "    Add capability: Audio Input"
echo ""
echo "15. Go to 'Build Settings' tab"
echo "    Search for 'Deployment'"
echo "    Set 'macOS Deployment Target' to 14.0"
echo ""
echo "16. Try building with ⌘B"
echo ""
echo "That's it! Your project should be set up."
echo ""
echo "==========================================="
echo ""
echo "Alternative: Let me create a Package.swift file instead..."
read -p "Would you like me to try creating a Package.swift for Swift Package Manager? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Creating Package.swift..."
    cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MotionHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MotionHub",
            targets: ["MotionHub"])
    ],
    targets: [
        .executableTarget(
            name: "MotionHub",
            path: "MotionHub/MotionHub",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
EOF
    echo "✅ Created Package.swift"
    echo ""
    echo "You can now:"
    echo "1. Run: swift build"
    echo "2. Or open Package.swift in Xcode"
    echo ""
    echo "Note: SPM may have limitations with Metal shaders and Info.plist"
fi

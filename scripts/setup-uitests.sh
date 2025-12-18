#!/bin/bash
#
# Setup script for Food1 UI Tests
#
# This script helps configure the UI test target.
# Run after adding the target in Xcode.
#
# MANUAL SETUP REQUIRED:
# 1. Open Food1.xcodeproj in Xcode
# 2. File → New → Target → iOS → UI Testing Bundle
# 3. Name: Food1UITests
# 4. Run this script to verify setup
#

set -e

echo "🧪 Food1 UI Tests Setup"
echo "========================"
echo ""

# Check if UI test files exist
if [ ! -d "Food1UITests" ]; then
    echo "❌ Food1UITests directory not found"
    echo "   Please create UI test target in Xcode first:"
    echo "   File → New → Target → iOS → UI Testing Bundle"
    exit 1
fi

# Check for test files
TEST_FILES=$(ls Food1UITests/*.swift 2>/dev/null | wc -l)
if [ "$TEST_FILES" -eq 0 ]; then
    echo "❌ No test files found in Food1UITests/"
    exit 1
fi

echo "✅ Found $TEST_FILES test file(s) in Food1UITests/"
ls -la Food1UITests/*.swift

# Check if target exists in project
if xcodebuild -project Food1.xcodeproj -list 2>/dev/null | grep -q "Food1UITests"; then
    echo "✅ Food1UITests target found in Xcode project"
else
    echo "⚠️  Food1UITests target NOT found in Xcode project"
    echo ""
    echo "To add the target:"
    echo "1. Open Food1.xcodeproj in Xcode"
    echo "2. File → New → Target"
    echo "3. Choose 'UI Testing Bundle'"
    echo "4. Product Name: Food1UITests"
    echo "5. Click Finish"
    echo "6. Add existing test files to the new target:"
    echo "   - Select Food1UITestCase.swift"
    echo "   - Select AccountDeletionUITests.swift"
    echo "   - Select AuthUITests.swift"
    echo "   - In the File Inspector, check 'Food1UITests' under Target Membership"
    exit 1
fi

echo ""
echo "📋 To run UI tests:"
echo "   xcodebuild test -project Food1.xcodeproj -scheme Food1 \\"
echo "     -only-testing:Food1UITests \\"
echo "     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"
echo ""
echo "📋 To run a specific test:"
echo "   xcodebuild test -project Food1.xcodeproj -scheme Food1 \\"
echo "     -only-testing:Food1UITests/AccountDeletionUITests \\"
echo "     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'"

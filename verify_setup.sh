#!/bin/bash

# Food Recognition Setup Verification Script
# Run this to verify all components are properly installed

echo "🔍 Verifying Food Recognition Setup..."
echo ""

errors=0

# Check Core ML Model
if [ -f "Food1/SeeFood.mlmodel" ]; then
    echo "✅ Core ML Model: SeeFood.mlmodel ($(ls -lh Food1/SeeFood.mlmodel | awk '{print $5}'))"
else
    echo "❌ Core ML Model: NOT FOUND"
    errors=$((errors + 1))
fi

# Check Services
if [ -f "Food1/Services/FoodRecognitionService.swift" ]; then
    echo "✅ Service: FoodRecognitionService.swift"
else
    echo "❌ Service: FoodRecognitionService.swift NOT FOUND"
    errors=$((errors + 1))
fi

if [ -f "Food1/Services/USDANutritionService.swift" ]; then
    echo "✅ Service: USDANutritionService.swift"
else
    echo "❌ Service: USDANutritionService.swift NOT FOUND"
    errors=$((errors + 1))
fi

# Check Tabbed Interface
if [ -f "Food1/Views/Components/AddMealTabView.swift" ]; then
    echo "✅ Component: AddMealTabView.swift (tabbed interface)"
else
    echo "❌ Component: AddMealTabView.swift NOT FOUND"
    errors=$((errors + 1))
fi

if [ -f "Food1/Views/Recognition/NutritionReviewView.swift" ]; then
    echo "✅ View: NutritionReviewView.swift"
else
    echo "❌ View: NutritionReviewView.swift NOT FOUND"
    errors=$((errors + 1))
fi

# Check Camera Component
if [ -f "Food1/Views/Components/CameraPicker.swift" ]; then
    echo "✅ Component: CameraPicker.swift"
else
    echo "❌ Component: CameraPicker.swift NOT FOUND"
    errors=$((errors + 1))
fi

# Check TodayView Integration
if grep -q "AddMealTabView" "Food1/Views/Today/TodayView.swift" 2>/dev/null; then
    echo "✅ Integration: TodayView updated with tabbed interface"
else
    echo "❌ Integration: TodayView NOT updated"
    errors=$((errors + 1))
fi

# Check Permissions in project.pbxproj
if grep -q "NSCameraUsageDescription" "Food1.xcodeproj/project.pbxproj" 2>/dev/null; then
    echo "✅ Permissions: Camera usage description added"
else
    echo "❌ Permissions: Camera usage description NOT found"
    errors=$((errors + 1))
fi

if grep -q "NSPhotoLibraryUsageDescription" "Food1.xcodeproj/project.pbxproj" 2>/dev/null; then
    echo "✅ Permissions: Photo library usage description added"
else
    echo "❌ Permissions: Photo library usage description NOT found"
    errors=$((errors + 1))
fi

# Check Model Reference
if grep -q "SeeFood" "Food1/Services/FoodRecognitionService.swift" 2>/dev/null; then
    echo "✅ Configuration: Model reference set to SeeFood"
else
    echo "❌ Configuration: Model reference NOT updated"
    errors=$((errors + 1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $errors -eq 0 ]; then
    echo "✅ Setup Complete! All components verified."
    echo ""
    echo "Next steps:"
    echo "1. Open Food1.xcodeproj in Xcode"
    echo "2. Build the project (⌘+B)"
    echo "3. Run on a device (⌘+R)"
    echo "4. Tap the camera icon to test!"
    echo ""
    echo "📖 See SETUP_COMPLETE.md for details"
else
    echo "❌ Setup Incomplete: $errors error(s) found"
    echo ""
    echo "Please check the missing files and try again."
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

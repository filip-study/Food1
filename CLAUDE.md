# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Food1 is an iOS nutrition tracking app with AI-powered food recognition. Users can log meals by taking photos (automatically recognized) or manual entry, track nutrition metrics, and view historical data.

**Key Technologies:**
- SwiftUI + SwiftData (iOS 26.0+)
- Core ML + Vision framework for food recognition
- USDA FoodData Central API for nutrition data
- Python scripts for ML model conversion (CoreML)

## Build & Run Commands

### iOS App (Xcode)
```bash
# Build the project
xcodebuild -project Food1.xcodeproj -scheme Food1 -configuration Debug build

# Clean build folder
xcodebuild clean -project Food1.xcodeproj -scheme Food1

# Run on simulator (requires Xcode CLI)
xcodebuild -project Food1.xcodeproj -scheme Food1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test

# Verify setup (check all components are in place)
./verify_setup.sh
```

**Important:** Camera and photo recognition require a physical device. The simulator has limited camera functionality.

### Python ML Model Conversion
```bash
# Setup virtual environment (one-time)
cd model_conversion
python3 -m venv mlenv
source mlenv/bin/activate
pip install coremltools torch torchvision transformers pillow

# Check available models
python check_models.py

# Convert Swin Transformer to CoreML
python convert_swin_to_coreml.py

# Search for alternative models on Hugging Face
python search_huggingface.py
```

## Architecture

### Data Layer
- **SwiftData Models:** `Meal` (Food1/Models/Meal.swift) stores nutrition data with UUID, name, emoji, timestamp, macros, and notes
- **Persistence:** SwiftData ModelContainer initialized in Food1App.swift with schema for Meal entities
- **Preview Support:** PreviewContainer utility provides in-memory ModelContainer for SwiftUI previews

### Service Layer

**FoodRecognitionService** (Food1/Services/FoodRecognitionService.swift)
- Core ML model integration via Vision framework
- Currently configured for FoodSwin92 model (92.14% accuracy, 101 food categories)
- Fallback to SeeFood model mentioned in setup docs (86.97% accuracy, 150+ dishes)
- Returns top 5 predictions with confidence scores above 5%
- Image preprocessing to 224x224 for optimal model input

**USDANutritionService** (Food1/Services/USDANutritionService.swift)
- Fetches nutrition data from USDA FoodData Central API
- Uses DEMO_KEY (rate-limited) - production should use registered API key
- Search foods by name, fetch detailed nutrition (calories, protein, carbs, fat, serving sizes)
- API Base: https://api.nal.usda.gov/fdc/v1

### View Architecture

**Navigation Structure:**
```
MainTabView (root)
├── TodayView (tab 0) - Daily meal log with date navigation
├── HistoryView (tab 1) - Historical meal data
├── StatsView (tab 2) - Analytics and trends
└── SettingsView (tab 3) - User preferences
```

**Meal Input Flow:**
```
TodayView FAB (+) → AddMealTabView
  ├── Photo Tab (default)
  │   └── CameraPicker → FoodRecognitionService → NutritionReviewView → Save
  └── Manual Tab
      └── Form Entry → Save
```

**Key Components:**
- **AddMealTabView:** Tabbed interface with Photo recognition and Manual entry. Defaults to Photo for new meals, Manual when editing.
- **CameraPicker:** UIImagePickerController wrapper supporting camera and photo library
- **NutritionReviewView:** Review and edit recognized food nutrition before saving
- **MealCard:** Displays meal summary with emoji, name, calories, and macros
- **MetricsDashboardView:** Progress rings showing daily nutrition vs goals
- **DateNavigationHeader:** Date picker in toolbar for viewing different days

### ML Model Integration

**Current Model:** FoodSwin92.mlpackage (Swin Transformer)
- Location: Food1/FoodSwin92.mlpackage
- Accuracy: 92.14% Top-1 on Food-101 dataset
- Categories: 101 food classes
- Input: 224x224 RGB image
- Output: Classification predictions with confidence scores

**Model Loading Pattern:**
1. Bundle.main.url(forResource: "FoodSwin92", withExtension: "mlmodelc")
2. MLModel(contentsOf: modelURL)
3. VNCoreMLModel(for: mlModel)
4. VNCoreMLRequest performs inference

**Adding New Models:**
1. Convert to CoreML format using Python scripts in model_conversion/
2. Add .mlpackage or .mlmodel to Xcode project
3. Update FoodRecognitionService.swift model loading logic (line 52)
4. Test recognition accuracy with representative food images

## Development Patterns

### SwiftData Queries
```swift
@Query(sort: \Meal.timestamp, order: .reverse) private var allMeals: [Meal]
```
Filter by date using Calendar.current.isDate(_:inSameDayAs:)

### Adding/Updating Meals
```swift
// Insert new meal
modelContext.insert(newMeal)

// Update existing meal (properties are automatically tracked)
existingMeal.name = "Updated Name"
```

### Camera Permissions
Required in Info.plist (already configured in project.pbxproj):
- NSCameraUsageDescription: "We need access to your camera to recognize food items..."
- NSPhotoLibraryUsageDescription: "We need access to your photo library..."

### Async/Await Pattern
All ML and API operations use async/await:
```swift
let predictions = await recognitionService.recognizeFood(in: image)
let nutrition = try await nutritionService.searchAndGetNutrition(query: "apple")
```

## File Organization

```
Food1/
├── App/
│   ├── Food1App.swift           - App entry point, ModelContainer setup
│   └── MainTabView.swift         - Tab navigation root
├── Models/
│   ├── Meal.swift                - SwiftData meal entity
│   ├── UserProfile.swift         - User settings enums (Gender, ActivityLevel, etc.)
│   └── AppSettings.swift         - App configuration
├── Services/
│   ├── FoodRecognitionService.swift  - Core ML food recognition
│   └── USDANutritionService.swift    - USDA API client
├── Views/
│   ├── Today/                    - Daily meal logging
│   ├── History/                  - Historical data
│   ├── Stats/                    - Analytics
│   ├── Settings/                 - User preferences
│   ├── Recognition/              - Nutrition review after recognition
│   └── Components/               - Reusable UI components
├── Utilities/
│   └── PreviewContainer.swift    - SwiftData preview helper
├── Data/
│   └── MockData.swift            - Sample data for previews
├── FoodSwin92.mlpackage/         - Current ML model (92.14% accuracy)
└── SeeFood.mlmodel               - Alternative model (86.97% accuracy)
```

## Common Tasks

### Testing Food Recognition
1. Run on physical device (camera required)
2. Tap purple FAB (+) button
3. Photo tab opens automatically
4. Take photo or select from library
5. Review predictions (top 5 with confidence %)
6. Select correct match → proceeds to nutrition review
7. Edit nutrition if needed → Save

### Debugging Model Issues
- Check Xcode console for model loading: "✅ Food recognition model loaded successfully"
- Verify .mlpackage is in Copy Bundle Resources build phase
- Ensure model file is not corrupted (check file size)
- Test with well-lit, single-item food photos first

### Switching ML Models
1. Add new .mlmodel or .mlpackage to Xcode project
2. Update FoodRecognitionService.swift:
   - Line 52: Change "FoodSwin92" to new model name
   - Line 59: Update accuracy/category count in log message
3. Adjust preprocessing if needed (target size, normalization)
4. Test with Food-101 dataset images if available

### API Configuration
**USDA API Key:** Currently using "DEMO_KEY" with rate limits. For production:
1. Register at https://fdc.nal.usda.gov/api-key-signup.html
2. Update USDANutritionService.swift line 35: `private let apiKey = "YOUR_KEY"`

## Project Specifics

### Date Navigation
TodayView supports:
- Swipe right: Previous day
- Swipe left: Next day (blocked for future dates)
- Toolbar button: Jump to today

### Goal Tracking
Default goals defined in DailyGoals.standard (Meal.swift:63):
- Calories: 2000
- Protein: 150g
- Carbs: 225g
- Fat: 65g

### Theme Support
AppTheme enum (referenced in MainTabView) supports system/light/dark modes via @AppStorage("appTheme")

## Notes

- Swift Concurrency uses @MainActor isolation by default (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor)
- Minimum iOS version: 26.0 (IPHONEOS_DEPLOYMENT_TARGET)
- Development Team: UJ4482ZF9C (for code signing)
- Bundle ID: com.filipolszak.Food1
- Purple/pink gradient is the app's primary branding color scheme

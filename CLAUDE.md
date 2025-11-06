# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Maintenance Instructions for Claude Code

**This project is built primarily via AI with minimal human intervention. Follow these rules:**

1. **Keep CLAUDE.md Updated:**
   - After ANY significant code changes, update relevant sections in this file
   - Remove outdated instructions or references to removed features
   - Add new sections for new features or architectural changes
   - Keep examples current with actual code

2. **Prevent Bloat:**
   - Delete unused dependencies immediately
   - Remove commented-out code blocks
   - Clean up temporary files after tasks complete
   - Don't create documentation files unless explicitly requested
   - Consolidate similar functionality into single files

3. **Git Commit Policy:**
   - After major milestones (feature complete, significant refactor, etc.), ask user: "Should I commit these changes to git?"
   - Wait for explicit confirmation before committing
   - Use descriptive commit messages that explain WHY, not just WHAT
   - NEVER commit secrets (APIConfig.swift, .env files, etc.)

4. **Code Quality:**
   - Keep files focused (one responsibility per file)
   - Remove duplicate code
   - Update stale comments
   - Fix compiler warnings immediately

## Project Overview

Food1 is an iOS nutrition tracking app with AI-powered food recognition. Users can log meals by taking photos (automatically recognized via GPT-4o), manual entry, track nutrition metrics, and view historical data.

**Key Technologies:**
- SwiftUI + SwiftData (iOS 26.0+)
- OpenAI GPT-4o Vision API for food recognition (via secure Cloudflare Worker proxy)
- URLSession for networking (no external dependencies)

## Build & Run Commands

### iOS App (Xcode)
```bash
# Build the project
xcodebuild -project Food1.xcodeproj -scheme Food1 -configuration Debug build

# Clean build folder
xcodebuild clean -project Food1.xcodeproj -scheme Food1

# Run on simulator
xcodebuild -project Food1.xcodeproj -scheme Food1 -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test
```

## Architecture

### Data Layer
- **SwiftData Models:** `Meal` (Food1/Models/Meal.swift) stores nutrition data with UUID, name, emoji, timestamp, macros, and notes
- **Persistence:** SwiftData ModelContainer initialized in Food1App.swift with schema for Meal entities
- **Preview Support:** PreviewContainer utility provides in-memory ModelContainer for SwiftUI previews

### Service Layer

**FoodRecognitionService** (Food1/Services/FoodRecognitionService.swift)
- Abstraction layer for AI vision-based food recognition
- Delegates to OpenAIVisionService for GPT-4o Vision API calls
- Returns FoodPrediction structs with food name, confidence, description, and nutrition data
- Handles preprocessing and error handling
- Easy to swap API providers (Claude, Gemini) by changing underlying service

**OpenAIVisionService** (Food1/Services/OpenAIVisionService.swift)
- URLSession-based client for GPT-4o Vision API
- Communicates with secure Cloudflare Worker proxy (never exposes API key in iOS app)
- Image encoding to base64 JPEG with compression (0.7 quality)
- Automatic image resizing (max 2048px) for optimal processing
- Structured JSON response parsing into FoodPrediction objects
- Comprehensive error handling (rate limits, network errors, API errors)

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
  ├── Photo Tab (AI-powered recognition)
  │   └── CameraPicker → FoodRecognitionService → GPT-4o Vision API → Predictions → NutritionReviewView → Save
  └── Manual Tab
      └── Form Entry → Save
```

**Key Components:**
- **AddMealTabView:** Tabbed interface with Photo recognition and Manual entry. Photo recognition uses GPT-4o Vision API.
- **CameraPicker:** UIImagePickerController wrapper supporting camera and photo library
- **NutritionReviewView:** Review and edit AI-generated nutrition data before saving. Supports serving size multiplier.
- **MealCard:** Displays meal summary with emoji, name, calories, and macros
- **MetricsDashboardView:** Progress rings showing daily nutrition vs goals
- **DateNavigationHeader:** Date picker in toolbar for viewing different days
- **PredictionRow:** Displays AI prediction with confidence score, description, and nutrition summary

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
Service operations use async/await:
```swift
let predictions = await recognitionService.recognizeFood(in: image)  // Currently returns []
// Future: API calls will use async/await for vision model requests
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
│   ├── FoodRecognitionService.swift  - Abstraction layer for AI vision
│   └── OpenAIVisionService.swift     - GPT-4o Vision API client
├── Config/
│   ├── APIConfig.swift               - API endpoint & auth token (gitignored)
│   └── APIConfig.swift.example       - Template for developers
├── Views/
│   ├── Today/                    - Daily meal logging
│   ├── History/                  - Historical data
│   ├── Stats/                    - Analytics
│   ├── Settings/                 - User preferences
│   ├── Recognition/              - Nutrition review after recognition
│   └── Components/               - Reusable UI components
├── Utilities/
│   └── PreviewContainer.swift    - SwiftData preview helper
└── Data/
    └── MockData.swift            - Sample data for previews
```

## Common Tasks

### Adding Meals via Photo Recognition
1. Tap purple FAB (+) button on TodayView
2. **Photo tab** opens automatically
3. Take photo or select from library
4. AI analyzes image and returns predictions with confidence scores
5. Select the correct food item from predictions
6. Review and edit nutrition data if needed
7. Adjust serving size multiplier if needed
8. Save meal

### Adding Meals Manually
1. Tap purple FAB (+) button on TodayView
2. Switch to **Manual tab**
3. Enter meal name, select emoji
4. Enter nutrition values (calories, protein, carbs, fat)
5. Add optional notes
6. Save meal

### GPT-4o Vision API Setup

**Prerequisites:**
1. OpenAI API key: https://platform.openai.com/api-keys
2. Cloudflare account (free): https://dash.cloudflare.com/sign-up

**Setup Steps:**

1. **Deploy Cloudflare Worker Proxy:**
   ```bash
   cd proxy/food-vision-api
   npm install
   npx wrangler login
   npx wrangler secret put OPENAI_API_KEY  # Paste your OpenAI key
   npx wrangler secret put AUTH_TOKEN      # Generate random UUID
   npx wrangler deploy
   ```

   Or use dashboard: See `proxy/food-vision-api/README.md` for detailed instructions

2. **Configure iOS App:**
   ```bash
   cd Food1/Config
   cp APIConfig.swift.example APIConfig.swift
   # Edit APIConfig.swift and add:
   # - Your Cloudflare Worker URL (e.g., https://food-vision-api.YOUR_USERNAME.workers.dev/analyze)
   # - Your AUTH_TOKEN (same as Cloudflare secret)
   ```

3. **Build and Test:**
   ```bash
   xcodebuild -project Food1.xcodeproj -scheme Food1 build
   ```

   Test on device or simulator:
   - Take photo of food
   - Verify predictions appear
   - Check nutrition data accuracy
   - Review Xcode console logs for debugging

**Cost Estimation:**
- OpenAI GPT-4o: ~$0.01 per image analysis
- Cloudflare Worker: Free (100k requests/day)
- Total: $1 per 100 food scans

**Troubleshooting:**

- **"Unauthorized" error:** Check APIConfig.swift matches Cloudflare AUTH_TOKEN
- **"Rate limit exceeded":** OpenAI tier limits reached. Check https://platform.openai.com/account/limits
- **No predictions:** Try better lighting, clearer food photos, closer crop
- **Wrong food identified:** Select different prediction or use Manual tab
- **Slow response:** Network latency or OpenAI API load. Normal: 2-5 seconds

**Monitoring:**
- Cloudflare: https://dash.cloudflare.com → Workers → food-vision-api → Analytics
- OpenAI: https://platform.openai.com/usage
- iOS logs: Check Xcode console for "📸", "🌐", "✅", "❌" emoji logs

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

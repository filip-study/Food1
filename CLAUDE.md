# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Maintenance Instructions for Claude Code

**This project is built primarily via AI with minimal human intervention. Follow these rules:**

1. **Keep CLAUDE.md Updated:**
   - After ANY significant code changes, update relevant sections in this file
   - Remove outdated instructions or references to removed features
   - Add new sections for new features or architectural changes
   - Keep examples current with actual code
   - **CRITICAL:** Continuously update the "Project Goals & User Preferences" section as you learn more about the user's preferences, goals, and approaches

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

## Project Goals & User Preferences

**Project Vision:**
- Build a practical, fast, AI-powered nutrition tracking iOS app
- Minimize user friction: photo → instant nutrition data → save
- Prioritize speed and accuracy over feature complexity
- Use API-based AI (GPT-4o) instead of on-device models for flexibility and accuracy

**User's Development Preferences:**

*Communication Style:*
- Prefer concise, direct communication - avoid excessive explanations
- Show results, not just plans
- Use TodoWrite to track progress transparently
- Provide clear summaries of what was done after completing work
- When errors occur, fix them immediately without asking permission

*Technical Approach:*
- **Performance is critical:** Users complained about timeouts → led to aggressive optimization (0.4 compression, 768px, low-detail mode)
- **Practical features over theoretical perfection:** User requested packaging detection + label scanning as real-world improvement
- **API-first architecture:** Switched from local ML models (FastVLM, USDA) to GPT-4o API for better accuracy and flexibility
- **Security matters:** Use Cloudflare Worker proxy to protect API keys, never expose secrets in iOS app
- **No external dependencies:** Prefer URLSession over third-party networking libraries
- **Minimal, focused UI:** Remove unused features (History tab), move non-essential UI elements (Settings) to less prominent positions
- **Clean design preferences:** User dislikes "disgusting" UI elements (chevron indicators, popovers). Prefers clean, simple interactions and neutral colors (blue over purple/pink)

*Workflow Preferences:*
- Use TodoWrite tool to track all multi-step tasks
- Mark todos as completed immediately after finishing each step
- When building iOS app, ALWAYS use `DEVELOPER_DIR` environment variable and `-destination` flag (see Build & Run Commands section)
- Deploy changes immediately when working on backend (Cloudflare Worker)
- Update CLAUDE.md continuously as you learn new information

*Decision-Making:*
- User prefers fast iteration over asking clarifying questions
- When user says "improve latency", investigate and implement comprehensive optimizations without asking for permission on each change
- When user reports issues (like timeouts), implement solutions proactively

**Feature Evolution:**
1. **Initial State (2025-11-04):** Local ML models (FastVLM, FoodSwin92) + USDA API
2. **Phase 1 Cleanup (2025-11-06):** Removed FastVLM (~1.8GB), USDA service (never worked)
3. **Phase 2 API Integration (2025-11-06):** Added GPT-4o Vision API via Cloudflare Worker proxy
4. **Phase 3 Performance (2025-11-06):** Optimized for speed (0.4 compression, 768px, low-detail mode, 60s timeout)
5. **Phase 4 Packaging Detection (2025-11-06):** Added automatic packaging detection + optional nutrition label scanning
6. **Bug Fix (2025-11-06):** Fixed LaunchServices errors and photo library lag by adding NSPhotoLibraryAddUsageDescription permission
7. **UI Simplification (2025-11-06):** Removed History tab, moved Settings to less obtrusive toolbar icon in TodayView
8. **Date Picker Redesign (2025-11-06):** Moved date picker from toolbar to inline section header with left/right arrows, calendar opens as sheet
9. **Theme Change (2025-11-06):** Changed from purple/pink gradient to neutral blue accent color per user feedback
10. **Add Meal Button Relocated (2025-11-06):** Moved FAB from bottom-right to top-right toolbar for cleaner layout

**Future Considerations:**
- User is open to switching APIs (OpenAI → Claude/Gemini) if better accuracy/cost
- Abstraction layer (FoodRecognitionService) designed for easy API swapping
- May want to add more practical features like barcode scanning, meal templates, or nutrition goals customization

## Project Overview

Food1 is an iOS nutrition tracking app with AI-powered food recognition. Users can log meals by taking photos (automatically recognized via GPT-4o), manual entry, track nutrition metrics, and view historical data.

**Key Technologies:**
- SwiftUI + SwiftData (iOS 26.0+)
- OpenAI GPT-4o Vision API for food recognition (via secure Cloudflare Worker proxy)
- URLSession for networking (no external dependencies)

## Build & Run Commands

### iOS App (Xcode)

**IMPORTANT: This project requires Xcode 26.0+ and MUST use DEVELOPER_DIR environment variable.**

```bash
# Set Xcode path (REQUIRED - Xcode 26.0.1 is installed)
export DEVELOPER_DIR=/Applications/Xcode-26.0.1.app/Contents/Developer

# Build for iOS Simulator (ALWAYS use -destination)
xcodebuild -project Food1.xcodeproj -scheme Food1 -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Clean build folder
xcodebuild -project Food1.xcodeproj -scheme Food1 clean

# Open in Xcode (preferred for development)
open Food1.xcodeproj
```

**CRITICAL BUILD RULES:**
1. **ALWAYS** set `DEVELOPER_DIR=/Applications/Xcode-26.0.1.app/Contents/Developer` before xcodebuild
2. **ALWAYS** specify `-destination` when building (don't build without it)
3. **NEVER** build without destination - causes provisioning profile errors
4. For simulator builds: Use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
5. For device builds: Use `-destination 'platform=iOS,id=<device-id>'`
6. Command line tools alone won't work - full Xcode required

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
- Two endpoints:
  - `/analyze`: Food recognition with packaging detection (low-detail mode, fast)
  - `/analyze-label`: Nutrition label OCR extraction (high-detail mode, accurate)
- Image encoding to base64 JPEG with compression (0.4 quality, optimized for speed)
- Automatic image resizing (max 768px) for fast uploads and processing
- 60-second timeout for GPT-4o processing
- Structured JSON response parsing into FoodPrediction objects and NutritionLabelData
- Comprehensive error handling (rate limits, network errors, API errors)

### View Architecture

**Navigation Structure:**
```
MainTabView (root)
├── TodayView (tab 0) - Daily meal log with date navigation
│   └── Settings button in toolbar (leading position, gear icon)
└── StatsView (tab 1) - Analytics and trends

SettingsView - Accessed via gear icon in TodayView toolbar (sheet presentation)
```

**Meal Input Flow:**
```
TodayView + button (toolbar) → AddMealTabView
  ├── Photo Tab (AI-powered recognition)
  │   └── CameraPicker → FoodRecognitionService → GPT-4o Vision API → Predictions → NutritionReviewView → Save
  └── Manual Tab
      └── Form Entry → Save
```

**Key Components:**
- **AddMealTabView:** Tabbed interface with Photo recognition and Manual entry. Photo recognition uses GPT-4o Vision API with automatic packaging detection.
- **CameraPicker:** UIImagePickerController wrapper supporting camera and photo library
- **NutritionReviewView:** Review and edit AI-generated nutrition data before saving. Supports serving size multiplier and nutrition label data.
- **MealCard:** Displays meal summary with emoji, name, calories, and macros
- **MetricsDashboardView:** Progress rings showing daily nutrition vs goals
- **DateNavigationHeader:** Inline date picker with left/right arrows. Shows "Today" for current date, "Yesterday", or formatted date. Click to open calendar popover.
- **PredictionRow:** Displays AI prediction with confidence score, description, and nutrition summary

**Packaging Detection & Nutrition Label Scanning:**
- GPT-4o automatically detects if food is in packaging (unopened or partially opened)
- When packaging detected, user is prompted to optionally scan nutrition label
- Nutrition label endpoint (/analyze-label) uses high-detail mode for accurate OCR
- Label data automatically merged with food recognition results
- Flow: Food photo → Packaging detection → Optional label scan → Merged nutrition data

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

### Camera & Photo Library Permissions
Required in Info.plist (configured in project.pbxproj):
- NSCameraUsageDescription: "We need access to your camera to recognize food items and automatically log nutrition information."
- NSPhotoLibraryUsageDescription: "We need access to your photo library so you can select food photos for recognition."
- NSPhotoLibraryAddUsageDescription: "We need permission to save photos you capture for meal logging." (Required for iOS 11+, prevents LaunchServices errors)

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

**Debugging API Issues:**

To monitor requests/responses in real-time:

1. **Live Cloudflare Worker Logs:**
   ```bash
   cd proxy/food-vision-api
   npx wrangler tail
   ```
   Shows:
   - Image size being sent
   - OpenAI response status
   - Full error messages
   - Request/response data

2. **Cloudflare Dashboard Logs:**
   - Go to https://dash.cloudflare.com
   - Navigate to: Workers & Pages → food-vision-api → Logs (Real-time)
   - View console.log output from worker

3. **OpenAI Platform:**
   - Usage: https://platform.openai.com/usage (shows call count, costs, tokens)
   - API Keys: https://platform.openai.com/api-keys (shows last usage time)
   - NOTE: OpenAI does NOT show actual prompts/images for privacy

4. **iOS App Logs:**
   - Run app in Xcode
   - Watch Console for detailed logs:
     - `📦 Image size: XXkB (WxH)` - Image preprocessing
     - `🌐 Sending request to proxy` - Network request
     - `✅ Received response: HTTP 200` - Success
     - `❌ Vision API error: ...` - Error details

**Common Issues:**
- HTTP 500 + "No response from AI": OpenAI returned empty content (check logs)
- HTTP 401: AUTH_TOKEN mismatch between iOS and Worker
- HTTP 429: OpenAI rate limit exceeded
- Timeout: Image too large or network slow (check image size in logs)

**Performance Optimization:**

The app is optimized for fast GPT-4o Vision API responses (typically 2-5 seconds):

**Client-side optimizations (OpenAIVisionService.swift):**
- **Image compression:** 0.4 quality (40%) for JPEG encoding
  - Food photos compress well, minimal quality loss
  - Reduces upload time significantly
- **Image resizing:** Max 768px dimension (down from 2048px)
  - 768px sufficient for food recognition accuracy
  - ~85% reduction in file size
- **Timeout:** 60 seconds for GPT-4o processing
  - Handles network variability and API processing time

**Server-side optimizations (proxy/food-vision-api/worker.js):**
- **Low-detail mode:** `detail: 'low'` on GPT-4o Vision API
  - 3-5x faster processing than high-detail mode
  - Food recognition doesn't require high-res analysis
- **Optimized prompt:** Concise instructions for faster token generation
- **Reduced tokens:** 600 max_tokens (down from 800)
  - Faster responses, lower costs
  - Still sufficient for 5 food predictions with nutrition

**If experiencing timeout issues:**
1. Check image size in Xcode console logs ("📦 Image size: XXkB")
2. Verify Cloudflare Worker is deployed with latest code (low-detail mode)
3. Test with smaller/simpler food photos first
4. Check OpenAI API status: https://status.openai.com
5. Monitor Cloudflare Worker logs for errors

**To further optimize if needed:**
- Reduce compression quality: 0.4 → 0.3 (line 25 in OpenAIVisionService.swift)
- Reduce max dimension: 768px → 512px (line 26 in OpenAIVisionService.swift)
- Reduce max_tokens: 600 → 400 (line 94 in worker.js)

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
- Blue is the app's primary accent color (changed from purple/pink gradient per user preference)

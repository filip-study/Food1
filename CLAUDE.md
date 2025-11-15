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

5. **Architectural Decisions:**
   - **ALWAYS reference existing documentation** (`docs/` folder and CLAUDE.md) when making architectural decisions
   - When invoking specialized agents (production-architect, debugging-engineer, etc.), explicitly instruct them to consult CLAUDE.md and existing docs
   - Maintain consistency with established patterns and user preferences documented in this file
   - Don't reinvent or contradict existing architectural decisions without user approval
   - New agents should be given context from CLAUDE.md to align with project goals

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
11. **Performance Optimization (2025-11-07):** Further reduced image size (0.3 compression, 512px) for faster uploads and lower API costs
12. **UI Bug Fixes (2025-11-07):** Fixed serving size picker buttons not responding (added .borderless button style)
13. **Character Limit Enforcement (2025-11-07):** Implemented 25-character limit for AI-generated food names to prevent UI truncation
14. **Character Limit Increase + MealCard Redesign (2025-11-07):** Increased limit to 40 chars for more descriptive names, redesigned MealCard with 2-line name support and time+calories combined
15. **Loading State Redesign - Phase 1 (2025-11-07):** Replaced camera background with blurred captured photo during food recognition, added smooth fade transitions, implemented 800ms minimum display time to prevent flashing
16. **Camera Dismissal Fix (2025-11-07):** Fixed camera briefly visible during meal save dismissal by hiding camera once photo captured and showing static photo background instead
17. **Loading State Phase 2 (2025-11-07):** Added engaging loading experience with rotating blue sparkles indicator, rotating status messages (4 messages every 2s), photo thumbnail in corner, and reduced motion accessibility support
18. **Macro Color Standardization (2025-11-07):** Fixed inconsistent macro colors across views - standardized to Protein=Blue, Carbs=Orange, Fat=Green everywhere
19. **Cartoon Food Icons Feature (2025-11-07):** Added AI-generated cartoon food illustrations using pre-generated icon library (500 icons, ~10MB), 3-layer image hierarchy (photo > cartoon > emoji), interactive flip animation in detail view, fuzzy name matching with 70-80% coverage, Settings toggles for show/hide and auto-flip behavior
20. **Micronutrient Tracking (2025-11-08):** Implemented local SQLite USDA database for comprehensive micronutrient tracking. Background enrichment matches ingredients to 12 key micronutrients (Calcium, Iron, Magnesium, Potassium, Zinc, Vitamins A/C/D/E/B12, Folate, Sodium) with RDA progress tracking. 100% offline, zero API calls, <10ms queries. Deleted HTTP-based USDAService (scalability issues) and manual ingredient search UI (violates "minimize friction" philosophy).

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
- **SwiftData Models:**
  - `Meal` (Food1/Models/Meal.swift) - Stores nutrition data with UUID, name, emoji, timestamp, macros, notes, and ingredient relationships
  - `MealIngredient` (Food1/Models/MealIngredient.swift) - Ingredient breakdown with USDA linking (fdcId) and micronutrient caching (JSON blob)
  - `Micronutrient` (Food1/Models/Micronutrient.swift) - Individual nutrient data structure with RDA percentage calculations
- **Persistence:** SwiftData ModelContainer initialized in Food1App.swift with schema for Meal and MealIngredient entities
- **Preview Support:** PreviewContainer utility provides in-memory ModelContainer for SwiftUI previews
- **Local USDA Database:** SQLite database (`Food1/Data/usda_nutrients.db`) bundled in app for offline micronutrient lookups (FTS5 indexed, ~8MB compressed)

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

**LocalUSDAService** (Food1/Services/LocalUSDAService.swift)
- SQLite-based USDA food database queries (100% offline, zero API calls)
- FTS5 full-text search for ingredient name matching (<10ms per query)
- Nutrient data retrieval scaled to gram amounts (<5ms per food)
- Returns micronutrient data with RDA percentages
- Handles 12 key micronutrients: Calcium, Iron, Magnesium, Potassium, Zinc, Vitamins A/C/D/E/B12, Folate, Sodium
- Memory-efficient: ~5MB active memory, query results cached

**FuzzyMatchingService** (Food1/Services/FuzzyMatchingService.swift)
- Matches ingredient names from GPT-4o to USDA foods
- Text normalization and cleaning (removes "grilled", "fresh", "organic", etc.)
- FTS5 full-text search with Porter stemming
- Conservative matching (rejects low-confidence matches <50%)
- Target accuracy: >70% auto-match rate on common foods

**BackgroundEnrichmentService** (Food1/Services/BackgroundEnrichmentService.swift)
- Orchestrates async micronutrient enrichment in background (non-blocking)
- Processes ingredients in parallel after meal save
- Uses FuzzyMatchingService + LocalUSDAService for offline enrichment
- Caches micronutrients in MealIngredient.cachedMicronutrientsJSON
- SwiftData observation updates UI automatically when complete (100-200ms typical)

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
- **NutritionReviewView:** Review and edit AI-generated nutrition data before saving. Supports serving size multiplier, nutrition label data, and ingredient editing.
- **IngredientListView:** Shows meal ingredients with gram amounts. Users can edit names/grams or delete ingredients. No manual "Add Ingredient" button (MVP decision - AI-detected only).
- **IngredientRow:** Inline editing component for ingredient gram amounts with stepper controls.
- **MealCard:** Displays meal summary with photo/cartoon/emoji, name, calories, and macros. 3-layer image hierarchy with sparkle badge for AI icons.
- **MealDetailView:** Detailed meal view with photo, macros, micronutrients (if available), and notes. Micronutrient section shows RDA progress bars.
- **MicronutrientRow:** Displays individual micronutrient with name, amount, unit, and color-coded RDA progress bar (Red <20%, Orange 20-50%, Green 50-100%, Blue ≥100%).
- **MetricsDashboardView:** Progress rings showing daily nutrition vs goals
- **DateNavigationHeader:** Inline date picker with left/right arrows. Shows "Today" for current date, "Yesterday", or formatted date. Click to open calendar popover.
- **PredictionRow:** Displays AI prediction with confidence score, description, and nutrition summary
- **FlippableImageView:** Interactive view that flips between real photo and cartoon icon with 3D rotation animation. Auto-flips on appear, manual flip on tap.

**Packaging Detection & Nutrition Label Scanning:**
- GPT-4o automatically detects if food is in packaging (unopened or partially opened)
- When packaging detected, user is prompted to optionally scan nutrition label
- Nutrition label endpoint (/analyze-label) uses high-detail mode for accurate OCR
- Label data automatically merged with food recognition results
- Flow: Food photo → Packaging detection → Optional label scan → Merged nutrition data

**Food Name Character Limit:**
- **Evolution:** Initially limited to 25 chars (time inline with name), increased to 40 chars (2025-11-07)
- **Problem:** 25-char limit made names too concise ("Chicken" vs "Grilled Chicken Breast")
- **Solution:** Multi-layered approach with UI redesign
  - **API Layer (Primary):** GPT-4o prompt instructs 40-character limit with emphasis on descriptiveness (worker.js:92, 257)
    - Instruction: "Keep food names under 40 characters but be descriptive"
    - Example: "Grilled Chicken Caesar Salad" (good) vs "Grilled Chicken Caesar Salad Bowl with Extra Dressing" (too long)
    - Removed "be concise" to encourage clarity within the limit
  - **UI Redesign:** MealCard.swift layout changed to accommodate longer names
    - Food name: `.lineLimit(2)` allows up to 2 lines (was 1 line)
    - Time moved below name and combined with calories (was inline with name)
    - New layout: Name (2 lines) → Time • Calories → Macros
    - Available space increased from ~208px to ~278px (+34%)
  - **Client Layer (Safety Net):** Smart truncation at 45 chars for edge cases (StringExtensions.swift)
    - Truncates at word boundaries (not mid-word)
    - Applied in OpenAIVisionService.swift:294
    - Handles rare cases where GPT-4o exceeds 40 chars
- **Benefits:**
  - More descriptive names: "Grilled Chicken Caesar Salad" (35 chars) vs "Chicken Salad" (13 chars)
  - Better UX: Natural reading flow (what → when+how much → details)
  - Backward compatible: Existing 25-char names still display correctly
  - Consistent card heights: lineLimit(2) prevents runaway expansion

**Food Recognition Loading State:**
- **Problem:** Camera viewfinder visible in background during API call (2-5s wait) - user found this unappealing
- **Solution - Phase 1 (Shipped 2025-11-07):**
  - **Blurred Photo Background:** Shows captured photo with 40pt blur + dark overlay instead of camera view
    - Provides visual context (user sees what's being analyzed)
    - Hides distracting camera viewfinder
    - Smooth transition from capture to analysis
  - **Improved Messaging:** Changed from "Recognizing food..." to "Analyzing nutrition" + "Identifying ingredients and portions"
  - **Smooth Transitions:** Added .opacity fade in/out (0.3s easeInOut)
  - **Minimum Display Time:** 800ms minimum prevents jarring flash on quick API responses (<1s)
    - Uses parallel Task with async/await for clean state management
    - Waits for both API completion AND minimum time before showing results
- **Solution - Phase 2 (Shipped 2025-11-07):**
  - **Rotating Sparkles Indicator:** Custom SF Symbol "sparkles" with blue-cyan gradient, 2s rotation animation
    - Replaces generic ProgressView with branded, themed indicator
    - Respects `accessibilityReduceMotion` - no rotation if user has this enabled
  - **Dynamic Status Messages:** 4 messages rotate every 2 seconds during wait
    - "Analyzing nutrition" → "Reading the image" → "Calculating macros" → "Almost there"
    - Smooth opacity transitions between messages (0.3s easeInOut)
    - Makes wait feel shorter and more engaging
  - **Photo Thumbnail:** 80x80 thumbnail in top-right corner with rounded corners, white border, shadow
    - Additional visual context during analysis
    - User can see what photo is being analyzed
  - **Camera Dismissal Fix:** Camera hidden once photo captured, replaced with static photo background
    - Prevents camera flash during sheet dismissals
    - Cleaner UX when saving meals
- **Technical Implementation:** QuickAddMealView.swift (lines 39-287)
  - Custom rotating animation: `.rotationEffect(.degrees(rotationAngle))` with `withAnimation(.linear(duration: 2).repeatForever())`
  - Message rotation: Task loop with 2s sleep + modulo cycling through array
  - Accessibility: `@Environment(\.accessibilityReduceMotion)` integration
  - Camera hiding: Conditional rendering based on `capturedImage == nil`
  - Async/await pattern prevents memory leaks (automatic Task cancellation)

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
│   ├── Meal.swift                - SwiftData meal entity with ingredient relationships
│   ├── MealIngredient.swift      - Ingredient breakdown with USDA data caching
│   ├── Micronutrient.swift       - Micronutrient data structure with RDA values
│   ├── UserProfile.swift         - User settings enums (Gender, ActivityLevel, etc.)
│   └── AppSettings.swift         - App configuration
├── Services/
│   ├── FoodRecognitionService.swift     - Abstraction layer for AI vision
│   ├── OpenAIVisionService.swift        - GPT-4o Vision API client
│   ├── LocalUSDAService.swift           - Local USDA database queries (SQLite)
│   ├── FuzzyMatchingService.swift       - Ingredient name matching algorithm
│   ├── BackgroundEnrichmentService.swift - Async micronutrient enrichment
│   └── FoodIconMapper.swift             - Maps meal names to cartoon icons
├── Config/
│   ├── APIConfig.swift               - API endpoint & auth token (gitignored)
│   └── APIConfig.swift.example       - Template for developers
├── Views/
│   ├── Today/                    - Daily meal logging
│   │   ├── TodayView.swift
│   │   ├── MealDetailView.swift      - Shows macros + micronutrients
│   │   └── MetricsDashboardView.swift
│   ├── History/                  - Historical data
│   ├── Stats/                    - Analytics
│   ├── Settings/                 - User preferences
│   ├── Recognition/              - Nutrition review after recognition
│   │   └── NutritionReviewView.swift  - Includes ingredient editing
│   └── Components/               - Reusable UI components
│       ├── GradientProgressRing.swift  - Progress ring with gradient + glow
│       ├── IngredientListView.swift   - Ingredient list with editing
│       ├── IngredientRow.swift        - Inline gram editing
│       ├── MicronutrientRow.swift     - RDA progress bars
│       ├── MealCard.swift
│       ├── InsightCard.swift          - Daily insights with frosted glass
│       ├── FlippableImageView.swift   - Photo/cartoon flip animation
│       └── ...
├── Utilities/
│   ├── ColorPalette.swift           - Centralized color definitions (gradients, accents)
│   ├── PreviewContainer.swift       - SwiftData preview helper
│   ├── StringExtensions.swift       - String truncation utilities
│   ├── HapticManager.swift          - Centralized haptic feedback
│   ├── NutritionFormatter.swift     - Nutrition value formatting
│   └── RDAValues.swift              - FDA recommended daily allowances
└── Data/
    ├── usda_nutrients.db         - Local USDA food database (SQLite, FTS5 indexed)
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
- **Image compression:** 0.3 quality (30%) for JPEG encoding
  - Aggressive compression for maximum speed
  - Food photos still recognizable at this quality level
  - Significantly reduces upload time and API costs
- **Image resizing:** Max 512px dimension (down from 768px → 2048px)
  - 512px sufficient for food recognition accuracy
  - ~90% reduction in file size vs original
  - Faster uploads and lower token costs
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

**Note:** Image optimization is already aggressive (0.3 quality, 512px max). Further reduction may impact recognition accuracy.

## Project Specifics

### Macro Color Standards
**IMPORTANT:** Use these colors consistently across ALL views for nutrition macros:
- **Protein:** `.orange`
- **Carbs:** `.green`
- **Fat:** `.yellow`

**Rationale:** These colors follow the industry standard (MacroFactor) and align with cognitive associations:
- Orange = Protein (warmth, meat/fish, energy, attention-grabbing for target macro)
- Green = Carbs (plants, vegetables, grains, natural foods)
- Yellow = Fat (butter, oils, cheese, concentrated energy)

These colors are used in:
- MealCard.swift (macro dots below meal cards)
- MetricsDashboardView.swift (progress bars on Today tab)
- MealDetailView.swift (nutrition rows - removed for cleaner design, using .secondary)

**DO NOT** use different colors for macros in any new views or features. Consistency is critical for UX.

### Premium UI Visual Design (2025-11-14)

The app uses a premium visual design inspired by Oura Ring and Function Health apps. Key patterns:

**Gradient Backgrounds:**
- TodayView has subtle gradient background using `LinearGradient`
- Light mode: white → blue (0.05 opacity)
- Dark mode: black → blue (0.08 opacity)
- Pattern:
  ```swift
  .background(
      LinearGradient(
          colors: colorScheme == .light
              ? [Color.white, Color.blue.opacity(0.05)]
              : [Color.black, Color.blue.opacity(0.08)],
          startPoint: .top,
          endPoint: .bottom
      )
  )
  ```

**Frosted Glass Cards:**
- All cards use `.thinMaterial` with 97% opacity
- MetricsDashboardView, MealCard, InsightCard
- Pattern:
  ```swift
  .background(
      RoundedRectangle(cornerRadius: 20)
          .fill(.thinMaterial)
          .opacity(0.97)
          .overlay(
              RoundedRectangle(cornerRadius: 20)
                  .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
          )
          .shadow(...)  // Layered shadows
  )
  ```

**Gradient Progress Rings:**
- `GradientProgressRing` component (Food1/Views/Components/GradientProgressRing.swift)
- Uses `ColorPalette.gradientForProgress()` for dynamic gradient bands:
  - 0-30%: Muted blue
  - 30-70%: Teal → Blue
  - 70-100%: Green → Mint
  - >100%: Orange → Coral
- Layered shadow glow effects (4pt inner + 12pt outer)
- Adaptive shadow opacity (light: 0.6, dark: 0.8)

**Color Palette (Food1/Utilities/ColorPalette.swift):**
- Accent colors: `accentPrimary` (#007AFF), `accentSecondary` (#00D4AA teal), `accentTertiary` (#00E5FF cyan)
- Progress gradients: `progressLowGradient`, `progressMediumGradient`, `progressHighGradient`, `progressOverGradient`
- Macro colors: `macroProtein` (orange), `macroCarbs` (green), `macroFat` (yellow) - NON-NEGOTIABLE

**Shadow Standards:**
- Adaptive opacity for light/dark mode
- Light mode: 6-8% primary, 2% secondary
- Dark mode: 12-15% primary, 4% secondary
- Layered approach: large radius (12-16pt) + small radius (4pt)

**Corner Radius Standards:**
- Hero cards (MetricsDashboard): 24pt
- Meal/Insight cards: 20pt
- Smaller components: 14-16pt

**Implementation Files:**
- ColorPalette.swift - Centralized color definitions
- GradientProgressRing.swift - Reusable progress ring component
- TodayView.swift - Gradient background
- MetricsDashboardView.swift - Frosted glass + gradient ring
- MealCard.swift - Frosted glass
- InsightCard.swift - Frosted glass

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
- dont fucking commit and push if i havent confirmed it works after ur fix
- dont just make up stuff about what features you plan to add. its my call what features to add. you can include RECOMMENDATIONS but it should be clearly stated they are comming from you as AI agent and I need to sign off on them and i may have a different opinion. it should be clear. technical improvements that dont affect functionality much is a different story and i can be a bit less involved
- our software architects should reference existing docs and the CLAUDE.md file whenever making decisions
- dont over document things just for the sake of documenting ........ we are not creating ahistory book here

## Active Technologies
- Swift 5.9+ (Xcode 16.0+, iOS 18.0 deployment target) + SwiftUI, SwiftData (existing - no new dependencies) (001-polished-ui)
- N/A (UI-only changes, existing SwiftData models unchanged) (001-polished-ui)
- Swift 5.9+ (iOS 18.0+ target) + SwiftUI (system framework), SwiftData (persistence - unchanged), SF Pro font family (002-premium-ui-redesign)
- N/A (UI enhancement only - existing SwiftData meal storage unchanged) (002-premium-ui-redesign)

## Recent Changes
- 001-polished-ui: Added Swift 5.9+ (Xcode 16.0+, iOS 18.0 deployment target) + SwiftUI, SwiftData (existing - no new dependencies)

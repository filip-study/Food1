# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## IMPORTANT: Maintenance Instructions

**This project is a PRODUCTION nutritional tracking and guidance, lifestyle app built primarily via AI with some human intervention. Follow these rules:**


1. **Prevent Bloat:**
   - Delete unused dependencies immediately
   - Remove commented-out code blocks
   - Clean up temporary files after tasks complete
   - Consolidate similar functionality when it makes sense

2. **Git Commit Policy:**
   - After major milestones (feature complete, significant refactor, etc.), ask user: "Should I commit these changes to git?"
   - Wait for explicit confirmation before committing
   - Use descriptive commit messages that explain WHY, not just WHAT
   - NEVER commit secrets

3. **Code Quality:**
   - Keep files focused 
   - Remove duplicate code
   - Update stale comments
   - Fix compiler warnings 

4. **Architectural Decisions:**
   - Keep up to date short documentation at the top of each code file
   - When invoking specialized agents (production-architect, debugging-engineer, etc.), explicitly instruct them to consult CLAUDE.md and existing docs
   - Maintain consistency with established patterns and user preferences documented in this file
   - Don't reinvent or contradict existing architectural decisions without user approval
   - Don't remove existing functionality without explicit user approval

5. **Test Protection Policy (CRITICAL):**
   - **NEVER modify files in `Food1Tests/` without explicit user approval**
   - Test files are protected from AI agent edits - ask before changing
   - If tests fail, fix the implementation code, not the tests (unless tests are clearly wrong)
   - When adding new features, suggest new tests but wait for user approval before creating them
   - Tests serve as the source of truth for expected behavior

## Project Goals & User Preferences

**Project Vision:**
- Build a practical, fast, AI-powered nutrition tracking iOS app
- "UX everything" - rewarding user experience is our keep focus
- Minimize user friction: photo → instant nutrition data → save

**User's Development Preferences:**

*Communication Style:*
- Use TodoWrite to track progress transparently, mark todos completed immediately after each step
- Provide concise, clear summaries of what was done after completing work

*Technical Approach:*
- **Production-ready app**: Running in beta via Apple TestFlight, planned for wider release soon
- **Performance is critical:** Users complained about timeouts → led to aggressive optimization (0.4 image compression, 768px, low-detail mode)
- **Practical features over theoretical perfection:** User requested packaging detection + label scanning as real-world improvement
- **Security matters:** Protect secrets and never expose risky stuff in the app itself
- **API flexibility:** Open to switching APIs (OpenAI → Claude/Gemini) if better accuracy/cost. FoodRecognitionService designed for easy API swapping

*Workflow Preferences:*
- When building iOS app, ALWAYS use `DEVELOPER_DIR` environment variable and `-destination` flag (see Build & Run Commands section)
- Make it clear when you leave something undone. For example, you made backend code changes (eg. Cloudflare Worker) but are unsure if you should deploy. Offer to deploy changes immediately, or instruct user how to do it

## Project Overview

Prismae ("Food1") is an iOS nutrition tracking app with AI-powered food recognition (GPT-4o vision). Users log meals via photo or manual entry. The app automatically enriches meals with USDA nutrition data in background, tracks macros and micronutrients, and provides historical views with trend analysis.

**Design:** App icon uses iOS 26 Liquid Glass format (`food1.icon/`) with three overlapping MacroRings (Protein/blue, Carbs/teal, Fat/coral) in triangular arrangement. Launch screen (LaunchScreenView.swift) recreates this design with animated sequential appearance. Icon config details in `food1.icon/icon.json`.

## Build & Run Commands

### iOS App (Xcode)

**IMPORTANT: This project requires Xcode 26.0+ (iOS 26.0+) and MUST use DEVELOPER_DIR environment variable.**

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

# Run unit tests
xcodebuild test -project Food1.xcodeproj -scheme Food1 -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**CRITICAL BUILD RULES:**
1. **ALWAYS** set `DEVELOPER_DIR=/Applications/Xcode-26.0.1.app/Contents/Developer` before xcodebuild
2. **ALWAYS** specify `-destination` when building (don't build without it)
3. **NEVER** build without destination - causes provisioning profile errors
4. For simulator builds: Use `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
5. For device builds: Use `-destination 'platform=iOS,id=<device-id>'`
6. Command line tools alone won't work - full Xcode required

## Architecture

Architecture documentation is maintained in individual code files. See file headers for detailed explanations of design decisions and rationale.

**Key Files:**
- **Data Models:** Meal.swift, MealIngredient.swift, Micronutrient.swift
- **Services:** FoodRecognitionService.swift, OpenAIVisionService.swift, LocalUSDAService.swift, FuzzyMatchingService.swift, BackgroundEnrichmentService.swift
- **Views:** MainTabView.swift, TodayView.swift, QuickAddMealView.swift, NutritionReviewView.swift, MealCard.swift, MealDetailView.swift, MetricsDashboardView.swift

## USDA Nutrition Database

**Overview:** App uses USDA FoodData Central for offline nutrition data enrichment. Meals are initially saved with AI predictions, then enriched in background with detailed USDA data via fuzzy matching.

**Key Services:**
- **LocalUSDAService.swift:** SQLite database queries and management
- **FuzzyMatchingService.swift:** Matches food names to USDA database entries
- **BackgroundEnrichmentService.swift:** Background task scheduling and enrichment logic

**Setup:** USDA API key required for database population. See service file headers for setup details and architecture decisions.

## GPT-4o Vision API Setup

**Prerequisites:** OpenAI API key (https://platform.openai.com/api-keys) and Cloudflare account (free: https://dash.cloudflare.com/sign-up)

**Quick Setup:**

1. **Deploy Cloudflare Worker Proxy:**
   ```bash
   cd proxy/food-vision-api
   npm install && npx wrangler login
   npx wrangler secret put OPENAI_API_KEY  # Paste your OpenAI key
   npx wrangler secret put AUTH_TOKEN      # Generate random UUID
   npx wrangler deploy
   ```

2. **Configure iOS App:**
   ```bash
   cd Food1/Config
   cp APIConfig.swift.example APIConfig.swift
   # Edit APIConfig.swift: Add Cloudflare Worker URL and AUTH_TOKEN
   ```

**Costs:** ~$0.01 per image (OpenAI), Cloudflare free (100k requests/day)

**Troubleshooting:**
- **"Unauthorized":** Check APIConfig.swift AUTH_TOKEN matches Cloudflare secret
- **"Rate limit exceeded":** OpenAI tier limits reached (check https://platform.openai.com/account/limits)
- **Debug logs:** Run `npx wrangler tail` in proxy/food-vision-api directory for real-time request/response monitoring
- **More details:** See `proxy/food-vision-api/README.md`


## Testing & CI/CD

**Unit Tests:** Located in `Food1Tests/`. Run via Xcode or command line (see Build & Run Commands).

**Test Coverage:**
- `NutritionFormatterTests` - Unit conversion and formatting
- `RDAValuesTests` - FDA recommended daily allowances by gender/age
- `MicronutrientTests` - RDA color thresholds, categories, formatting
- `MealCalculationsTests` - Nutrition aggregation math
- `FuzzyMatchingTests` - USDA shortcuts, blacklist, name cleaning

**GitHub Actions:** `.github/workflows/ios-tests.yml` runs tests on push to `main` and `claude/*` branches using a self-hosted macOS runner with Xcode 26.0.1.

**Test Protection:** Tests are protected from AI modification. See "Test Protection Policy" in Maintenance Instructions.

## Development Tools

**evaluation/** - Fuzzy matching evaluation toolkit for improving USDA ingredient matching accuracy. Includes scripts to run test images through GPT-4o pipeline, analyze ingredient patterns, find USDA matches, and generate verified shortcuts for FuzzyMatchingService.swift. See evaluation/README.md for usage.

## Notes

- dont fucking commit and push if i havent confirmed it works after ur fix
- dont just make up stuff about what features you plan to add. its my call what features to add. you can include RECOMMENDATIONS but it should be clearly stated they are comming from you as AI agent and I need to sign off on them and i may have a different opinion. it should be clear. technical improvements that dont affect functionality much is a different story and i can be a bit less involved
- why did you put the api key directly in the code? are you crazy? this is a production app never do that again
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

5. **Test Policy:**
   - Tests define expected behavior and MUST NOT be modified without explicit user approval
   - When tests fail after code changes, fix the CODE, not the tests (unless the test itself is wrong)
   - To add new tests, ask user for test case definitions and expected behavior first
   - Never change test assertions or expected values without explicit confirmation
   - Test files are located in Food1Tests/ directory
   - All tests run automatically on GitHub Actions CI for every push

## Production Readiness

**Status:** Beta (TestFlight) - See `PRODUCTION_READINESS.md` for full assessment

**Critical Blockers (Must Fix Before App Store):**

1. **Legal Pages Missing:**
   - `prismae.net/terms` - Needs actual Terms of Use
   - `prismae.net/privacy` - Needs actual Privacy Policy
   - Referenced in: `PaywallView.swift:198-200`

2. **Account Deletion:** ✅ IMPLEMENTED
   - Two-step confirmation in `AccountView.swift`
   - Deletes all user data from Supabase + local storage

3. **StoreKit Product Verification:**
   - Verify `com.prismae.food1.premium.monthly` exists in App Store Connect
   - Test sandbox purchase flow

**What's Ready:**
- ✅ All 38 tests passing (34 active, 4 skipped)
- ✅ Security (secrets in xcconfig, Cloudflare proxy)
- ✅ Auth flow (Apple Sign In + Email)
- ✅ Subscription system (StoreKit 2)
- ✅ CI/CD (GitHub Actions)

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

**IMPORTANT: This project requires Xcode 26.0+ (iOS 26.0+) 

**Test Infrastructure:**
- Test target: Food1Tests
- Test files: Food1Tests/*.swift
- CI/CD: GitHub Actions runs tests automatically on every push
- See `.github/workflows/ios-tests.yml` for CI configuration
- **CI Runner Choice:** Default is `macos-26` (GitHub-hosted, free, has Xcode 26). To run on self-hosted (for watching UI tests locally): `gh workflow run ios-tests.yml -f runner=self-hosted`
- **Use XcodeBuildMCP tools**: After UI changes, use `xcrun simctl` to take screenshots and verify in both light/dark modes

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

## Backend API (Separate Repository)

The Cloudflare Worker backend is maintained in a **separate repository**:

**Backend Repo:** https://github.com/filip-study/food-vision-api

This separation enables:
- Cloudflare Git integration for auto-deploy on push to main
- Independent versioning from the iOS app
- Cleaner CI/CD (iOS tests don't run for backend changes)

When making backend changes, clone that repo:
```bash
cd ~/Documents/git
git clone https://github.com/filip-study/food-vision-api.git
cd food-vision-api
npm install
```

**Preview deployments:** Push to `dev` branch → Cloudflare creates preview at `https://dev.food-vision-api.filipfood1.workers.dev`

## GPT-4o Vision API Setup

**Prerequisites:** OpenAI API key (https://platform.openai.com/api-keys) and Cloudflare account (free: https://dash.cloudflare.com/sign-up)

**Quick Setup:**

1. **Deploy Cloudflare Worker Proxy:** (in the food-vision-api repo)
   ```bash
   cd ~/Documents/git/food-vision-api
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
- **Debug logs:** Run `npx wrangler tail` in food-vision-api directory for real-time logs
- **More details:** See food-vision-api repo README.md


## Development Tools

**evaluation/** - Fuzzy matching evaluation toolkit for improving USDA ingredient matching accuracy. Includes scripts to run test images through GPT-4o pipeline, analyze ingredient patterns, find USDA matches, and generate verified shortcuts for FuzzyMatchingService.swift. See evaluation/README.md for usage.

## Notes

- NEVER run destructive commands (delete, drop, wrangler delete, etc.) without explicit user approval
- dont fucking commit and push if i havent confirmed it works after ur fix
- dont just make up stuff about what features you plan to add. its my call what features to add. you can include RECOMMENDATIONS but it should be clearly stated they are comming from you as AI agent and I need to sign off on them and i may have a different opinion. it should be clear. technical improvements that dont affect functionality much is a different story and i can be a bit less involved
- why did you put the api key directly in the code? are you crazy? this is a production app never do that again
- never do risky things like what you just did "Now try uploading a photo again - I've simplified the policy to just check if the user is authenticated, removing the
  folder-based restriction. This will tell us if the issue is with the folder validation or something else." without getting explicit approval fromt he user to do an unsafe, non-production ready test that has to be fixed afterwards
- always ultrathink for every prompt, careful design and planning matters
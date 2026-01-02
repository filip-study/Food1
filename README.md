# Prismae (Food1)

**AI-Powered Nutrition Tracking for iOS**

Prismae is a production-ready iOS app that uses GPT-4o Vision to instantly analyze food photos and provide detailed nutritional information. Snap a photo of your meal, and get comprehensive macro and micronutrient data in seconds.

[![Tests](https://github.com/user/Food1/actions/workflows/ios-tests.yml/badge.svg)](https://github.com/user/Food1/actions/workflows/ios-tests.yml)
[![TestFlight](https://img.shields.io/badge/TestFlight-Beta-blue)](https://testflight.apple.com/join/YOUR_LINK)
[![iOS 26+](https://img.shields.io/badge/iOS-26.0+-000000?logo=apple)](https://developer.apple.com/ios/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-FA7343?logo=swift)](https://swift.org/)

---

## Features

- **Instant Food Recognition** - Take a photo, get nutrition data in ~2 seconds
- **Packaging Detection** - Automatically reads nutrition labels when visible
- **Detailed Micronutrients** - Track vitamins, minerals, and more via USDA database enrichment
- **Manual Entry** - Describe meals in natural language when photos aren't practical
- **Historical Trends** - View nutrition patterns over days, weeks, and months
- **Meal Reminders** - Live Activities and widgets to stay on track
- **Cloud Sync** - Seamless sync across devices via Supabase
- **Offline Support** - Local-first architecture with background sync
- **Dark Mode** - Full support for light and dark themes

## Screenshots

| Today View | Meal Detail | Stats |
|------------|-------------|-------|
| *Daily meal feed with nutrition summary* | *Per-ingredient breakdown with micronutrients* | *Historical trends and insights* |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **UI** | SwiftUI + SwiftData |
| **Vision AI** | OpenAI GPT-4o / Google Gemini |
| **Backend** | Supabase (PostgreSQL, Auth, Storage) |
| **API Proxy** | Cloudflare Workers |
| **Nutrition DB** | USDA FoodData Central (SQLite) |
| **Subscriptions** | StoreKit 2 |
| **CI/CD** | GitHub Actions + Fastlane |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                        │
│  (TodayView, MealDetailView, StatsView, SettingsView, ...)  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ FoodRecog-   │  │ SyncService  │  │ Subscription-    │   │
│  │ nitionService│  │ + Coordinator│  │ Service          │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ LocalUSDA-   │  │ Background-  │  │ Authentication-  │   │
│  │ Service      │  │ Enrichment   │  │ Service          │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       ┌───────────┐   ┌───────────┐   ┌───────────┐
       │ SwiftData │   │  SQLite   │   │ Supabase  │
       │  (Local)  │   │  (USDA)   │   │  (Cloud)  │
       └───────────┘   └───────────┘   └───────────┘
```

**Key Patterns:**
- **MVVM + Clean Architecture** - Clear separation of concerns
- **Local-First** - Save immediately, sync in background
- **Service Abstraction** - Easy to swap AI providers (OpenAI ↔ Gemini)
- **Optimistic Updates** - UI never blocks on network

---

## Getting Started

### Prerequisites

- **Xcode 26.0+** (iOS 26.0 SDK)
- **macOS 15.0+** (Sequoia)
- **Node.js 18+** (for Cloudflare Worker)
- **OpenAI API Key** ([Get one here](https://platform.openai.com/api-keys))
- **Cloudflare Account** ([Free signup](https://dash.cloudflare.com/sign-up))
- **Supabase Project** ([Create project](https://supabase.com/dashboard))

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/Food1.git
cd Food1
```

### 2. Deploy the API Proxy (Cloudflare Worker)

The proxy keeps your OpenAI API key secure and adds rate limiting.

```bash
cd proxy/food-vision-api
npm install
npx wrangler login

# Set required secrets
npx wrangler secret put OPENAI_API_KEY      # Your OpenAI key
npx wrangler secret put AUTH_TOKEN          # Generate: uuidgen
npx wrangler secret put SUPABASE_URL        # Your Supabase project URL
npx wrangler secret put SUPABASE_SERVICE_KEY # Supabase service role key
npx wrangler secret put SUPABASE_JWT_SECRET  # From Supabase dashboard

# Deploy
npx wrangler deploy
```

Note the deployed URL (e.g., `https://food-vision-api.your-subdomain.workers.dev`).

### 3. Configure the iOS App

```bash
cd Food1/Config

# Copy the template
cp APIConfig.swift.template APIConfig.swift
```

Edit `APIConfig.swift` with your credentials:

```swift
enum APIConfig {
    static let proxyEndpoint = "https://food-vision-api.your-subdomain.workers.dev"
    static let proxyAuthToken = "your-auth-token-from-step-2"

    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
}
```

### 4. Set Up Supabase

1. Create a new Supabase project
2. Run the migrations in `supabase/migrations/` via SQL editor
3. Enable Apple Sign In provider in Authentication settings
4. Create storage bucket named `meal-photos`

### 5. Build and Run

```bash
# Open in Xcode
open Food1.xcodeproj

# Or build from command line
xcodebuild -scheme Food1 \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

---

## Project Structure

```
Food1/
├── App/                    # App entry point, main navigation
├── Models/                 # Data models (Meal, MealIngredient, etc.)
├── Services/               # Business logic layer
│   ├── FoodRecognitionService.swift    # AI food analysis orchestrator
│   ├── OpenAIVisionService.swift       # GPT-4o Vision integration
│   ├── LocalUSDAService.swift          # USDA database queries
│   ├── FuzzyMatchingService.swift      # Ingredient-to-USDA matching
│   ├── BackgroundEnrichmentService.swift # Async nutrition enrichment
│   ├── SyncService.swift               # Cloud sync orchestrator
│   └── SubscriptionService.swift       # StoreKit 2 handling
├── Views/                  # SwiftUI views (51 files)
│   ├── Today/              # Main feed views
│   ├── Recognition/        # Meal logging views
│   ├── Stats/              # Analytics views
│   ├── Settings/           # Settings & account views
│   └── Components/         # Reusable UI components
├── ViewModels/             # State management
├── Utilities/              # Helpers, extensions, design system
├── Config/                 # API configuration (git-ignored)
├── Data/                   # SwiftData + USDA SQLite database
└── Resources/              # Assets, launch screen

Food1Tests/                 # Unit tests
Food1UITests/               # UI integration tests
MealReminderWidget/         # iOS Widget extension
proxy/food-vision-api/      # Cloudflare Worker proxy
```

---

## Configuration

### Environment Variables (CI/CD)

Set these in GitHub Secrets for automated builds:

| Secret | Description |
|--------|-------------|
| `PROXY_ENDPOINT` | Cloudflare Worker URL |
| `PROXY_AUTH_TOKEN` | Worker authentication token |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous key |
| `APP_STORE_CONNECT_API_KEY_KEY` | App Store Connect API key |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `MATCH_PASSWORD` | Fastlane match password |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Git auth for certificates |

### Local Development

Create `Food1/Config/Secrets.xcconfig`:

```
PROXY_ENDPOINT = https://your-worker.workers.dev
PROXY_AUTH_TOKEN = your-auth-token
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
```

---

## Testing

### Run All Tests

```bash
# Via Xcode
xcodebuild test \
  -scheme Food1 \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -testPlan Food1

# Or use the MCP tools
# mcp__XcodeBuildMCP__test_sim
```

### Test Structure

| File | Coverage |
|------|----------|
| `FuzzyMatchingServiceTests.swift` | USDA ingredient matching |
| `MealCalculationTests.swift` | Macro/micro calculations |
| `MicronutrientTests.swift` | Micronutrient data handling |
| `NutritionFormatterTests.swift` | Display formatting |

**CI Status:** All 38 tests passing (34 active, 4 skipped)

---

## Deployment

### TestFlight (Automated)

Push to `main` branch triggers:
1. **ios-tests.yml** - Runs all tests
2. **testflight.yml** - Builds and uploads to TestFlight (if tests pass)

### Manual Deployment

```bash
# Install Fastlane
bundle install

# Deploy to TestFlight
bundle exec fastlane beta
```

---

## API Costs

| Service | Cost | Notes |
|---------|------|-------|
| OpenAI GPT-4o Vision | ~$0.01/image | Primary recognition |
| Google Gemini | ~$0.002/image | Optional alternative |
| Cloudflare Workers | Free | 100K requests/day |
| Supabase | Free tier | 500MB database, 1GB storage |

**Estimated monthly cost:** $5-20 for active development/testing

---

## Security

- **No hardcoded secrets** - All credentials in xcconfig/environment
- **API proxy** - OpenAI key never exposed to client
- **Rate limiting** - Per-user daily limits via Cloudflare KV
- **JWT validation** - Subscription status verified server-side
- **RLS policies** - Row-level security in Supabase

See [SECURITY_CREDENTIAL_ROTATION.md](SECURITY_CREDENTIAL_ROTATION.md) for credential management.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`xcodebuild test ...`)
5. Commit (`git commit -m 'Add amazing feature'`)
6. Push (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Follow Swift style guidelines
- Add tests for new functionality
- Update documentation for API changes
- Keep commits focused and descriptive

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

---

## Documentation

| Document | Description |
|----------|-------------|
| [CLAUDE.md](CLAUDE.md) | Development guidelines & architecture |
| [PRODUCTION_READINESS.md](PRODUCTION_READINESS.md) | Release checklist |
| [TESTING.md](TESTING.md) | Testing strategy |
| [proxy/food-vision-api/README.md](proxy/food-vision-api/README.md) | Cloudflare Worker setup |

---

## Roadmap

- [x] Core food recognition
- [x] USDA micronutrient enrichment
- [x] Cloud sync with Supabase
- [x] Apple Sign In authentication
- [x] Subscription system (StoreKit 2)
- [x] Meal reminders (Live Activities)
- [x] CI/CD pipeline
- [ ] App Store release
- [ ] Apple Watch companion app
- [ ] Social features (meal sharing)
- [ ] AI-powered meal suggestions

---

## License

This project is proprietary software. All rights reserved.

---

## Acknowledgments

- [OpenAI](https://openai.com/) - GPT-4o Vision API
- [Supabase](https://supabase.com/) - Backend infrastructure
- [USDA FoodData Central](https://fdc.nal.usda.gov/) - Nutrition database
- [Cloudflare](https://cloudflare.com/) - Edge computing platform

---

<p align="center">
  <strong>Built with SwiftUI</strong><br>
  <sub>Prismae - Nutrition tracking, simplified.</sub>
</p>

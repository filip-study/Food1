# Testing Strategy

> **Living Document:** Update as testing infrastructure evolves.

## Overview

Prismae uses a three-tier testing approach:

| Tier | Type | Speed | Runs In CI | Tests |
|------|------|-------|------------|-------|
| 1 | **Unit Tests** | Fast (~5s) | Every push | Logic, calculations, mocked services |
| 2 | **Integration Tests** | Medium (~30s) | On demand | Real Supabase with test accounts |
| 3 | **UI Tests (XCUITest)** | Slow (~2min) | On demand | Full user flows |

## Test Targets

| Target | Purpose | Location |
|--------|---------|----------|
| `Food1Tests` | Unit tests (Tier 1) | `Food1Tests/` |
| `Food1IntegrationTests` | Integration tests (Tier 2) | `Food1IntegrationTests/` |
| `Food1UITests` | UI tests (Tier 3) | `Food1UITests/` |

---

## Tier 1: Unit Tests

**Run:** `xcodebuild test -scheme Food1 -only-testing:Food1Tests`

### What's Tested
- Micronutrient calculations and RDA percentages
- Fuzzy matching service logic
- AuthViewModel logic (with mocked Supabase)
- Data model transformations

### Mocking Strategy
Services are abstracted behind protocols to enable testing:

```swift
// Protocol allows mocking
protocol SupabaseClientProtocol {
    func from(_ table: String) -> PostgrestQueryBuilder
    // ... other methods
}

// Real implementation
class SupabaseService: SupabaseClientProtocol { ... }

// Test mock
class MockSupabaseClient: SupabaseClientProtocol { ... }
```

---

## Tier 2: Integration Tests

**Run:** `xcodebuild test -scheme Food1 -only-testing:Food1IntegrationTests`

### Purpose
Test actual Supabase integration with real network calls against a **test project**.

### Setup Required
1. Create a separate Supabase project for testing (or use staging)
2. Add secrets to `.env.test` (git-ignored):
   ```
   TEST_SUPABASE_URL=https://xxx.supabase.co
   TEST_SUPABASE_ANON_KEY=eyJ...
   TEST_USER_EMAIL=test@example.com
   TEST_USER_PASSWORD=testpassword123
   ```
3. CI uses GitHub Secrets for these values

### Test Accounts
Integration tests create temporary test users:
```swift
// Create test user before each test
let testUser = try await createTestUser()

// Run test...

// Cleanup after test
try await deleteTestUser(testUser.id)
```

### What's Tested
- Account creation and deletion flow
- Meal sync to Supabase
- Subscription status updates
- Profile updates

---

## Tier 3: UI Tests (XCUITest)

**Run:** `xcodebuild test -scheme Food1 -only-testing:Food1UITests`

### Purpose
Automate critical user journeys through the actual UI.

### Test Flows
1. **Account Deletion Flow**
   - Navigate to Settings → Account
   - Tap "Delete Account"
   - Confirm in first dialog
   - Type "DELETE" in second dialog
   - Verify user is signed out

2. **Sign In Flow**
   - Launch app
   - Enter credentials
   - Verify main screen appears

3. **Meal Logging Flow** (future)
   - Add meal via photo/manual
   - Verify meal appears in history

### Running UI Tests
```bash
# Run all UI tests
xcodebuild test -scheme Food1 -only-testing:Food1UITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run specific test
xcodebuild test -scheme Food1 -only-testing:Food1UITests/AccountDeletionUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## CI/CD Integration

### GitHub Actions Workflows

| Workflow | Trigger | Tests Run |
|----------|---------|-----------|
| `ios-tests.yml` | Every push | Tier 1 (Unit) |
| `ios-integration.yml` | Manual / Nightly | Tier 2 (Integration) |
| `ios-e2e.yml` | Manual / Pre-release | Tier 3 (UI) |

### Running Tests Locally

```bash
# All unit tests (fast)
xcodebuild test -scheme Food1 -only-testing:Food1Tests

# Integration tests (needs env vars)
source .env.test && xcodebuild test -scheme Food1 -only-testing:Food1IntegrationTests

# UI tests (slow, needs simulator)
xcodebuild test -scheme Food1 -only-testing:Food1UITests

# Everything
xcodebuild test -scheme Food1
```

---

## Test Data Management

### Fixtures
Test fixtures are stored in `Food1Tests/Fixtures/`:
- `sample_meal.json` - Sample meal response from GPT-4o
- `usda_match.json` - Sample USDA match result

### Test Database
Unit tests use an in-memory SQLite database populated with a subset of USDA data.

---

## Writing New Tests

### Unit Test Template
```swift
final class MyServiceTests: XCTestCase {
    var sut: MyService!  // System Under Test
    var mockDependency: MockDependency!

    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = MyService(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    func testSomeBehavior() async {
        // Given
        mockDependency.returnValue = expectedValue

        // When
        let result = await sut.doSomething()

        // Then
        XCTAssertEqual(result, expectedValue)
    }
}
```

### UI Test Template
```swift
final class MyFeatureUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testFeatureFlow() {
        // Navigate to feature
        app.buttons["Settings"].tap()

        // Interact with UI
        app.buttons["My Feature"].tap()

        // Assert outcome
        XCTAssertTrue(app.staticTexts["Success"].exists)
    }
}
```

---

## Coverage Goals

| Area | Target | Current |
|------|--------|---------|
| Models | 80% | TBD |
| ViewModels | 70% | TBD |
| Services | 60% | TBD |
| Views | 30% | TBD |

---

## Change Log

| Date | Change |
|------|--------|
| 2024-12-19 | Initial testing strategy document |

# Production Readiness Assessment

**Last Updated:** December 19, 2024
**App Version:** 1.02
**Status:** Beta (TestFlight)

> **Living Document:** This is a living document that evolves as we identify new requirements, complete tasks, or discover issues. Update it whenever production readiness status changes. Add new sections as needed for areas not yet covered.

This document tracks Prismae's readiness for public App Store release.

---

## Executive Summary

| Category | Status | Notes |
|----------|--------|-------|
| **Code Quality** | ✅ Ready | All 33 tests pass, proper logging, no critical warnings |
| **Security** | ✅ Ready | Secrets in xcconfig, Cloudflare proxy, no hardcoded keys |
| **Architecture** | ✅ Ready | Clean separation, documented patterns |
| **Legal/Compliance** | ❌ Blocking | Missing Terms, Privacy, Account Deletion |
| **Monetization** | ⚠️ Verify | StoreKit product needs App Store Connect verification |

**Bottom Line:** The app is technically solid but has **blocking legal/compliance gaps** that must be resolved before App Store submission.

---

## Critical Blockers (Must Fix Before Release)

### 1. Terms of Use - NOT FUNCTIONAL
- **Current State:** `prismae.app/terms` redirects to `/lander` (no actual content)
- **Referenced In:** `PaywallView.swift:198`
- **Requirement:** Apple requires functional legal links for subscription apps
- **Action Required:**
  - [ ] Create actual Terms of Use content (consult legal counsel)
  - [ ] Host at `prismae.app/terms` (not redirect)
  - [ ] Include: usage rights, liability disclaimers, subscription terms, termination policy

### 2. Privacy Policy - NOT FUNCTIONAL
- **Current State:** `prismae.app/privacy` redirects to `/lander` (no actual content)
- **Referenced In:** `PaywallView.swift:200`
- **Requirement:** Apple requires privacy policy for all apps collecting user data
- **Action Required:**
  - [ ] Create actual Privacy Policy content (consult legal counsel)
  - [ ] Host at `prismae.app/privacy` (not redirect)
  - [ ] Include: data collection, storage, sharing, GDPR compliance, user rights

### 3. Account Deletion - NOT IMPLEMENTED
- **Current State:** No way to delete account (only sign out exists)
- **Location:** `AccountView.swift` - only has "Sign Out"
- **Requirement:** Apple requires account deletion for all apps with account creation (since June 2022)
- **Action Required:**
  - [ ] Add "Delete Account" button to AccountView
  - [ ] Implement confirmation flow (prevent accidental deletion)
  - [ ] Create Supabase function to delete user data:
    - Delete from `profiles` table
    - Delete from `subscription_status` table
    - Delete from `meals` table (user's meal data)
    - Handle cascade deletions properly
  - [ ] Optional: 14-day grace period before permanent deletion
  - [ ] Send confirmation email after deletion request

### 4. StoreKit Product Verification
- **Current State:** Code references `com.prismae.food1.premium.monthly`
- **Location:** `SubscriptionService.swift:21`
- **Action Required:**
  - [ ] Verify product exists in App Store Connect
  - [ ] Verify pricing is set correctly ($5.99/month as shown in PaywallView)
  - [ ] Test purchase flow in sandbox environment
  - [ ] Verify subscription group configuration

---

## Completed Items

### Code Quality ✅
- [x] All 33 unit tests passing
- [x] Proper `os.Logger` instead of `print()` statements
- [x] Fixed Supabase deprecated API warnings
- [x] Fixed unused variable warnings in tests
- [x] Test expectations match production code (nutrient naming)

### Security ✅
- [x] API keys in `Secrets.xcconfig` (git-ignored)
- [x] OpenAI key protected via Cloudflare Worker proxy
- [x] No hardcoded secrets in codebase
- [x] `fatalError` guards for missing config in Release builds
- [x] DEBUG fallbacks for local development

### Architecture ✅
- [x] Clean MVVM pattern
- [x] SwiftData for local persistence
- [x] Supabase for cloud sync
- [x] StoreKit 2 for subscriptions
- [x] Background enrichment service
- [x] Proper error handling

### CI/CD ✅
- [x] GitHub Actions runs tests on every push
- [x] Self-hosted runner with Xcode 26
- [x] Test artifacts uploaded
- [x] Code coverage reporting

---

## Recommendations (Non-Blocking)

### Before Public Release
1. **App Store Screenshots:** Prepare marketing screenshots for all device sizes
2. **App Store Description:** Write compelling copy highlighting AI food recognition
3. **Support Contact:** Set up support email (required by Apple)
4. **Age Rating:** Complete App Store Connect questionnaire

### Technical Debt
1. **Duplicate Bundle Resource:** `usda_nutrients.db` appears twice in Copy Bundle Resources
2. **Print Statements:** Other files still have `print()` (SubscriptionService, OnboardingView)
3. **TODO Comment:** `TodayView.swift:1` has unimplemented insight redesign

### Future Improvements
1. **Analytics:** Consider adding privacy-respecting analytics
2. **Crash Reporting:** Consider adding crash reporting (e.g., Sentry, Firebase Crashlytics)
3. **Deep Links:** Verify email confirmation deep links work correctly
4. **Widget:** Consider iOS widget for quick meal logging

---

## Testing Checklist (Pre-Release)

### Authentication
- [ ] Apple Sign In works on fresh install
- [ ] Email sign up sends confirmation
- [ ] Email confirmation deep link works
- [ ] Sign out clears local state
- [ ] Session persists across app restarts

### Subscription
- [ ] Paywall displays correctly
- [ ] Trial countdown is accurate
- [ ] Purchase flow completes (sandbox)
- [ ] Restore purchases works
- [ ] Subscription syncs to Supabase

### Core Features
- [ ] Photo meal logging works
- [ ] Manual meal entry works
- [ ] USDA enrichment runs in background
- [ ] Stats display correctly
- [ ] Cloud sync works across devices

### Edge Cases
- [ ] No network handling
- [ ] Trial expiration behavior
- [ ] Subscription expiration behavior
- [ ] Large meal history performance

---

## Contacts & Resources

- **App Store Connect:** [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
- **Supabase Dashboard:** [supabase.com/dashboard](https://supabase.com/dashboard)
- **Cloudflare Dashboard:** [dash.cloudflare.com](https://dash.cloudflare.com)
- **GitHub Repo:** (internal)

---

## Change Log

| Date | Change |
|------|--------|
| 2024-12-19 | Initial document creation. Identified 4 critical blockers. |

---

*Add new entries to the change log when significant updates are made.*

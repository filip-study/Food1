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
| **Legal/Compliance** | ⚠️ Partial | Missing Terms & Privacy pages; Account Deletion ✅ |
| **Monetization** | ⚠️ Verify | StoreKit product needs App Store Connect verification |
| **API Protection** | 🔴 Missing | No rate limiting; unlimited API cost exposure |
| **Subscription Security** | 🟡 Acceptable | Client-side verification only; server-side recommended post-launch |

**Bottom Line:** The app is technically solid but has **blocking legal/compliance gaps** and **missing API rate limiting** (financial risk) that should be resolved before App Store submission.

---

## Critical Blockers (Must Fix Before Release)

### 1. Terms of Use - NOT FUNCTIONAL
- **Current State:** `prismae.net/terms` needs to be created
- **Referenced In:** `PaywallView.swift:198`
- **Requirement:** Apple requires functional legal links for subscription apps
- **Action Required:**
  - [ ] Create actual Terms of Use content (consult legal counsel)
  - [ ] Host at `prismae.net/terms`
  - [ ] Include: usage rights, liability disclaimers, subscription terms, termination policy

### 2. Privacy Policy - NOT FUNCTIONAL
- **Current State:** `prismae.net/privacy` needs to be created
- **Referenced In:** `PaywallView.swift:200`
- **Requirement:** Apple requires privacy policy for all apps collecting user data
- **Action Required:**
  - [ ] Create actual Privacy Policy content (consult legal counsel)
  - [ ] Host at `prismae.net/privacy`
  - [ ] Include: data collection, storage, sharing, GDPR compliance, user rights

### 3. Account Deletion - ✅ IMPLEMENTED
- **Current State:** Two-step deletion flow in AccountView
- **Location:** `AccountView.swift`, `AuthViewModel.swift`
- **Implementation:**
  - [x] Add "Delete Account" button in "Danger Zone" section
  - [x] Two-step confirmation (dialog → type "DELETE" to confirm)
  - [x] Deletes from Supabase: `meals`, `subscription_status`, `profiles` tables
  - [x] Clears local UserDefaults data
  - [x] Signs out user after deletion
  - [ ] Optional: 14-day grace period (not implemented - immediate deletion)
  - [ ] Optional: Confirmation email after deletion (not implemented)

### 4. StoreKit Product Verification
- **Current State:** Code references `com.prismae.food1.premium.monthly`
- **Location:** `SubscriptionService.swift:21`
- **Action Required:**
  - [ ] Verify product exists in App Store Connect
  - [ ] Verify pricing is set correctly ($5.99/month as shown in PaywallView)
  - [ ] Test purchase flow in sandbox environment
  - [ ] Verify subscription group configuration

### 5. API Rate Limiting - NOT IMPLEMENTED 🔴
- **Current State:** Cloudflare Worker has NO per-user rate limiting
- **Location:** `proxy/food-vision-api/worker.js`
- **Risk:** A single user (malicious or power user) could run up significant Vision API costs
- **Financial Exposure:** Unlimited — no caps on requests per user
- **Action Required:**
  - [ ] Add per-user daily request limits (recommend: 50 meals/day)
  - [ ] Add Cloudflare KV for rate limit tracking
  - [ ] Return 429 status when limit exceeded
  - [ ] Consider different limits for trial vs. paid users

### 6. Subscription Verification at API Layer - NOT IMPLEMENTED 🟡
- **Current State:** Vision API only checks AUTH_TOKEN, not subscription status
- **Location:** `proxy/food-vision-api/worker.js`
- **Risk:** Expired/cancelled users can still use the Vision API (costs you money)
- **Action Required:**
  - [ ] Pass subscription status from iOS to Worker (or verify via Supabase)
  - [ ] Reject requests from expired users at API layer
  - [ ] Alternative: Rely on iOS-side paywall gate (current approach)

---

## High Priority (Post-Launch or If Issues Arise)

### Server-Side Receipt Verification
- **Current State:** iOS app directly updates Supabase subscription_status
- **Risk Level:** Low-Medium — requires sophisticated attacker, limited financial exposure
- **Recommendation:** Implement App Store Server Notifications v2 if subscription fraud detected
- **Action Required (if needed):**
  - [ ] Set up webhook endpoint (Supabase Edge Function)
  - [ ] Configure App Store Server Notifications v2 in App Store Connect
  - [ ] Verify Apple's signed notifications server-side
  - [ ] Remove client's ability to directly update subscription_status

### RLS Policy Hardening
- **Current State:** INSERT policies allow inserting without verifying user_id matches
- **Location:** Supabase RLS policies
- **Risk:** Low — user can only affect their own data anyway
- **Action Required:**
  - [ ] Add `WITH CHECK (auth.uid() = user_id)` to INSERT policies

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
| 2024-12-21 | Added API rate limiting (critical blocker) and subscription security sections after deep investigation. |
| 2024-12-19 | Implemented account deletion feature (2-step confirmation). 3 blockers remain. |
| 2024-12-19 | Initial document creation. Identified 4 critical blockers. |

---

*Add new entries to the change log when significant updates are made.*

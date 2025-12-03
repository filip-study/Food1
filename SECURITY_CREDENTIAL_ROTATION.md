# Security Credential Rotation Guide

## URGENT: AUTH_TOKEN Exposed in Git History

**Status**: The AUTH_TOKEN `a4ef35f9-233b-44ff-9347-c279cb4477af` was previously hardcoded in `APIConfig.swift` and is visible in git history.

**Risk**: Anyone with access to the repository history can use this token to make requests to your Cloudflare Worker, consuming your OpenAI API quota.

---

## Immediate Action Required

### 1. Rotate AUTH_TOKEN in Cloudflare Worker

```bash
cd proxy/food-vision-api

# Generate new secure token (macOS)
NEW_TOKEN=$(uuidgen)
echo "New token: $NEW_TOKEN"

# Update Cloudflare Worker secret
npx wrangler secret put AUTH_TOKEN
# Paste the new token when prompted

# Redeploy worker
npx wrangler deploy
```

### 2. Update Secrets.xcconfig

Edit `Food1/Config/Secrets.xcconfig`:

```
AUTH_TOKEN = YOUR_NEW_TOKEN_HERE
```

### 3. Rebuild and Test iOS App

```bash
# Clean build
export DEVELOPER_DIR=/Applications/Xcode-26.0.1.app/Contents/Developer
xcodebuild -project Food1.xcodeproj -scheme Food1 clean

# Build and test
xcodebuild -project Food1.xcodeproj -scheme Food1 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### 4. Remove Exposed Token from Git History (Optional but Recommended)

**WARNING**: This rewrites git history and requires force push. Coordinate with all collaborators.

```bash
# Backup first!
git branch backup-before-history-rewrite

# Remove APIConfig.swift from all commits
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch Food1/Config/APIConfig.swift" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (dangerous!)
# git push origin --force --all
```

**Alternative (safer)**: Accept that the old token is exposed and rely on rotation. Monitor Cloudflare Worker logs for abuse.

---

## Monitoring for Unauthorized Usage

### Check Cloudflare Worker Logs

```bash
cd proxy/food-vision-api
npx wrangler tail
```

Watch for:
- Unusual request patterns
- Requests from unexpected IPs
- High volume spikes

### Monitor OpenAI Usage

1. Visit https://platform.openai.com/usage
2. Check daily spending for anomalies
3. Set up billing alerts if not already configured

---

## Long-Term Security Improvements

### Option 1: Move to Backend Authentication (Recommended for Scale)

Instead of shared AUTH_TOKEN, implement:
1. User authentication (Firebase, Auth0, etc.)
2. Backend issues signed JWTs
3. Cloudflare Worker validates JWTs
4. Per-user rate limiting

### Option 2: Device Fingerprinting + Rate Limiting

- Generate unique device ID on first launch
- Store in Keychain
- Track per-device usage in Cloudflare Worker KV
- Implement aggressive rate limits (e.g., 10 requests/hour/device)

### Option 3: Rotate Tokens Regularly

- Generate new AUTH_TOKEN monthly
- Update via remote config (Firebase Remote Config)
- iOS app fetches current token on launch
- Cloudflare Worker accepts multiple tokens during transition

---

## Current Security Architecture

**Secure** ✅:
- OpenAI API key stored in Cloudflare Worker secrets (never exposed)
- Gemini API key stored in Cloudflare Worker secrets (never exposed)
- USDA database is offline/local (no API key needed)

**Exposed** ⚠️:
- AUTH_TOKEN in iOS app binary (reverse-engineerable)
- AUTH_TOKEN in git history (if not cleaned)

**Mitigation**:
- Cloudflare Worker implements rate limiting (100 req/15min per IP)
- iOS app has 60-second timeout (limits abuse)
- AUTH_TOKEN only grants access to your Worker, not OpenAI directly
- Regular monitoring of usage

---

## Questions?

If you suspect unauthorized usage:
1. Rotate AUTH_TOKEN immediately
2. Check Cloudflare analytics for request sources
3. Review OpenAI usage dashboard
4. Consider implementing backend authentication

**Last Updated**: 2025-12-03 (after security review)

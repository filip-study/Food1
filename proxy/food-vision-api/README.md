# Food Vision API Proxy

Secure Cloudflare Worker proxy for OpenAI GPT-4o Vision API. This proxy keeps your OpenAI API key secure and never exposes it in the iOS app.

## Features

- ✅ Secure API key storage (server-side only)
- ✅ CORS handling for iOS requests
- ✅ Rate limiting protection
- ✅ Error handling and user-friendly messages
- ✅ Structured JSON response format
- ✅ **Free tier**: 100,000 requests/day on Cloudflare
- ✅ **NEW: Geographic routing** - Automatically routes through AWS proxy when in OpenAI-blocked regions (HKG, China, Russia, etc.)

## Prerequisites

1. **Cloudflare Account** (free): https://dash.cloudflare.com/sign-up
2. **OpenAI API Key**: https://platform.openai.com/api-keys
3. **Node.js** (for deployment): https://nodejs.org/

## Setup Instructions

### Option A: Deploy via Cloudflare Dashboard (No CLI needed)

1. **Create Cloudflare Worker:**
   - Go to https://dash.cloudflare.com/
   - Navigate to "Workers & Pages"
   - Click "Create Application" → "Create Worker"
   - Name it: `food-vision-api`
   - Click "Deploy"

2. **Add Worker Code:**
   - Click "Edit Code" on the deployed worker
   - Copy the contents of `worker.js`
   - Paste into the code editor
   - Click "Save and Deploy"

3. **Set Environment Variables:**
   - In your worker page, go to "Settings" → "Variables"
   - Click "Add variable"
   - Add two secrets (encrypted):
     - Name: `OPENAI_API_KEY`, Value: `your-openai-api-key`
     - Name: `AUTH_TOKEN`, Value: `generate-random-token-here` (e.g., use a UUID)
   - Click "Deploy" after adding both

4. **Get Your Endpoint URL:**
   - Format: `https://food-vision-api.YOUR_USERNAME.workers.dev/analyze`
   - Copy this URL for iOS app configuration

### Option B: Deploy via CLI (Wrangler)

1. **Install Wrangler:**
   ```bash
   cd proxy/food-vision-api
   npm install
   ```

2. **Login to Cloudflare:**
   ```bash
   npx wrangler login
   ```

3. **Set Secrets:**
   ```bash
   npx wrangler secret put OPENAI_API_KEY
   # Paste your OpenAI API key when prompted

   npx wrangler secret put AUTH_TOKEN
   # Generate a random token (e.g., UUID) and paste when prompted
   ```

4. **Deploy:**
   ```bash
   npx wrangler deploy
   ```

5. **Get Your Endpoint:**
   ```bash
   npx wrangler deployments list
   ```
   - Copy the URL ending with `/analyze`

## Geographic Routing (Optional but Recommended)

**Problem:** Cloudflare Workers sometimes execute in regions where OpenAI blocks API access (Hong Kong, China, Russia, etc.), causing requests to fail.

**Solution:** Set up an AWS EC2 proxy in Singapore that automatically handles requests from blocked regions.

### When to set this up:
- You're experiencing intermittent failures (HTTP 403 errors)
- Your users are in Asia/Pacific regions
- You want global reliability

### Setup Guide:

**New to AWS?** → [QUICK_START.md](./QUICK_START.md) - 30 min setup with **$0 cost** on free tier

**Detailed guide:** → [AWS_PROXY_SETUP.md](./AWS_PROXY_SETUP.md) - Complete reference

**Quick setup (30 minutes):**
1. Launch EC2 t2.micro in Singapore (FREE TIER!)
2. Install nginx reverse proxy with BasicAuth
3. Set `PROXY_URL` secret in Cloudflare Worker
4. Deploy worker - automatic routing enabled!

**Cost:**
- With free tier: **$0/month** for first 12 months
- After free tier: ~$3-5/month (Smart Placement reduces usage by 60-80%)

**How it works:**
- Worker detects its execution region (COLO)
- If in blocked region → Routes through AWS proxy
- If in normal region → Direct to OpenAI
- Automatic fallback if proxy fails

## Testing the Proxy

### Test with curl:

```bash
# Replace with your actual endpoint and auth token
curl -X POST https://food-vision-api.YOUR_USERNAME.workers.dev/analyze \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{
    "image": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
    "userId": "test-user"
  }'
```

### Expected Response:

```json
{
  "success": true,
  "data": {
    "predictions": [
      {
        "label": "Grilled Chicken Breast",
        "confidence": 0.92,
        "description": "A seasoned grilled chicken breast with visible char marks",
        "nutrition": {
          "calories": 165,
          "protein": 31.0,
          "carbs": 0.0,
          "fat": 3.6,
          "serving_size": "3 oz (85g)"
        }
      }
    ]
  },
  "usage": {
    "promptTokens": 1234,
    "completionTokens": 156,
    "totalTokens": 1390
  }
}
```

## Cost Estimation

**OpenAI GPT-4o Pricing (as of 2024):**
- Input: $5 per 1M tokens (~$0.005 per 1K tokens)
- Output: $15 per 1M tokens (~$0.015 per 1K tokens)

**Typical Request:**
- Input: ~1,500 tokens (prompt + image)
- Output: ~200 tokens (JSON response)
- **Cost per request: ~$0.01**

**Example usage:**
- 100 requests/day = $1/day = $30/month
- 1,000 requests/day = $10/day = $300/month

**Cloudflare Worker:**
- Free tier: 100,000 requests/day
- No additional costs for this proxy

## iOS App Configuration

After deployment, update your iOS app:

1. Create `Food1/Config/APIConfig.swift`:
   ```swift
   struct APIConfig {
       static let proxyEndpoint = "https://food-vision-api.YOUR_USERNAME.workers.dev/analyze"
       static let authToken = "YOUR_AUTH_TOKEN"
   }
   ```

2. Add to `.gitignore`:
   ```
   Food1/Config/APIConfig.swift
   ```

## Security Notes

- ✅ OpenAI API key is NEVER exposed in iOS app
- ✅ AUTH_TOKEN adds basic authentication (iOS → proxy)
- ✅ CORS restricts requests to allowed origins
- ⚠️ For production, consider adding user-based rate limiting
- ⚠️ Monitor Cloudflare Worker logs for suspicious activity

## Troubleshooting

### Error: "Unauthorized"
- Check that AUTH_TOKEN in iOS app matches Cloudflare secret
- Verify `Authorization: Bearer TOKEN` header format

### Error: "Rate limit exceeded"
- OpenAI has rate limits (tier-based)
- Check https://platform.openai.com/account/limits
- Consider implementing request queuing in iOS app

### Error: "No response from AI"
- Check OpenAI API status: https://status.openai.com/
- Verify OPENAI_API_KEY is set correctly in Cloudflare
- Check Cloudflare Worker logs for details

### Viewing Logs:

**Dashboard:**
- Go to your worker → "Logs" → "Begin log stream"

**CLI:**
```bash
npx wrangler tail
```

## Monitoring

**Cloudflare Dashboard:**
- Analytics: https://dash.cloudflare.com/ → Workers → food-vision-api → Analytics
- View request count, success rate, error rate
- Monitor CPU time usage

**OpenAI Dashboard:**
- Usage: https://platform.openai.com/usage
- Monitor token consumption and costs

## Development vs Production

Use separate workers for dev/prod:

```bash
# Development
npx wrangler deploy --env development

# Production
npx wrangler deploy --env production
```

Update iOS app configuration accordingly.

## Support

- **Cloudflare Workers Docs**: https://developers.cloudflare.com/workers/
- **OpenAI API Docs**: https://platform.openai.com/docs/guides/vision
- **Wrangler CLI Docs**: https://developers.cloudflare.com/workers/wrangler/

## License

MIT

# Smart Placement Teaching Strategy

## The Problem

Even with Smart Placement enabled, Cloudflare might still route some requests through blocked regions (HKG, China, Russia) due to:
- Load balancing across datacenters
- Geographic proximity to users in Asia
- Initial learning period
- Network conditions

**Result:** Higher AWS proxy costs than necessary.

## The Solution: Artificial Latency Penalty

Add a configurable delay before proxying requests in blocked regions. This makes those regions appear "slow" to Cloudflare's Smart Placement algorithm.

**Over time (weeks), Smart Placement learns:**
- Blocked regions = slow response times
- US/Europe regions = fast response times
- **Result:** Automatically prefers US/Europe, reducing AWS proxy usage toward ~0%

## How It Works

```javascript
if (isBlockedRegion && env.PROXY_URL) {
  // Add artificial delay (configurable)
  await sleep(SMART_PLACEMENT_PENALTY_MS);

  // Then proxy through AWS
  // Smart Placement sees: "This region took (actual_time + penalty) ms"
}
```

Cloudflare tracks request latencies and optimizes future routing decisions.

## Implementation Phases

### Phase 1: Baseline (Current - No Penalty)
**Setup:**
```bash
# Don't set SMART_PLACEMENT_PENALTY_MS
# OR set to 0
npx wrangler secret put SMART_PLACEMENT_PENALTY_MS
# Enter: 0
```

**Behavior:**
- No artificial delays
- Natural Smart Placement learning
- Measure baseline: What % of requests use proxy?

**Duration:** 1-2 weeks

**Monitor:**
```bash
npx wrangler tail | grep "Routing:" | tee routing.log
# After a day, analyze:
grep "AWS Proxy" routing.log | wc -l    # Proxy count
grep "Direct OpenAI" routing.log | wc -l # Direct count
```

**Expected:** 20-40% proxy usage for global traffic

---

### Phase 2: Gentle Teaching (Recommended Start)
**Setup:**
```bash
npx wrangler secret put SMART_PLACEMENT_PENALTY_MS
# Enter: 200
npx wrangler deploy
```

**Behavior:**
- Adds 200ms delay before proxying in blocked regions
- Modest UX impact (~10% slower for Asia users)
- Gentle signal to Smart Placement

**Duration:** 2-4 weeks

**Monitor:** Same as Phase 1, watch for declining proxy percentage

**Expected results after 2-4 weeks:**
- Proxy usage drops from 20-40% → 10-20%
- AWS costs reduced by ~50%

---

### Phase 3: Aggressive Teaching (If Phase 2 Insufficient)
**Setup:**
```bash
npx wrangler secret put SMART_PLACEMENT_PENALTY_MS
# Enter: 500
npx wrangler deploy
```

**Behavior:**
- Adds 500ms delay before proxying
- Stronger signal to Smart Placement
- More UX impact for Asia users (temporary)

**Duration:** 2-3 weeks

**Expected results:**
- Proxy usage drops to 5-10%
- AWS costs reduced by 70-80%
- After learning, can reduce penalty back to 200ms

---

### Phase 4: Maintenance Mode
**Setup:**
```bash
npx wrangler secret put SMART_PLACEMENT_PENALTY_MS
# Enter: 100
npx wrangler deploy
```

**Behavior:**
- Small 100ms penalty to maintain learned behavior
- Minimal UX impact
- Prevents Smart Placement from "forgetting"

**Duration:** Indefinite

**Expected:**
- Proxy usage stays at 5-10%
- AWS costs: $1-3/month (near-zero goal achieved!)

---

## Monitoring Commands

### Real-time routing decisions:
```bash
cd proxy/food-vision-api
npx wrangler tail | grep "🌍"
```

Output:
```
🌍 COLO: LAX, Routing: Direct OpenAI          ← Good!
🌍 COLO: HKG (BLOCKED), Routing: AWS Proxy    ← Costs money
⏱️  Adding 200ms penalty to teach Smart Placement
```

### Daily statistics:
```bash
# Collect 24 hours of logs
npx wrangler tail | grep "Routing:" > routing-$(date +%Y%m%d).log

# Analyze next day:
DIRECT=$(grep "Direct OpenAI" routing-20251109.log | wc -l)
PROXY=$(grep "AWS Proxy" routing-20251109.log | wc -l)
TOTAL=$((DIRECT + PROXY))
PCT=$(echo "scale=1; $PROXY * 100 / $TOTAL" | bc)

echo "Proxy usage: $PROXY/$TOTAL ($PCT%)"
```

### Cost impact tracking:
```bash
# AWS billing dashboard
open https://console.aws.amazon.com/billing/

# Check CloudWatch metrics for EC2
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=InstanceId,Value=YOUR_INSTANCE_ID \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --region ap-southeast-1
```

## Expected Timeline

```
Week 0: No penalty, baseline measurement
        ├─ Proxy usage: 30%
        └─ AWS cost: $5/month

Week 2: Enable 200ms penalty
        ├─ Proxy usage: 25%
        └─ AWS cost: $4/month

Week 4: Smart Placement learning
        ├─ Proxy usage: 18%
        └─ AWS cost: $3/month

Week 8: Increase to 500ms if needed
        ├─ Proxy usage: 12%
        └─ AWS cost: $2/month

Week 12: Reduce to 100ms maintenance
         ├─ Proxy usage: 8%
         └─ AWS cost: $1-2/month ✅
```

## Trade-offs

### Pros:
- ✅ Reduces AWS costs by 70-90% over time
- ✅ Automated learning (no manual intervention after setup)
- ✅ Can disable anytime if causing issues
- ✅ Protects against future Cloudflare routing changes

### Cons:
- ❌ Temporary UX degradation for Asia users (200-500ms slower)
- ❌ Takes weeks to see full effect
- ❌ Might not reach 0% (some requests may still need proxy)
- ❌ Could "unlearn" if traffic patterns change dramatically

## Recommendations

### For new deployments:
1. Start with Phase 1 (no penalty) for 1 week
2. Measure baseline proxy usage
3. If >20%, enable Phase 2 (200ms penalty)
4. Monitor for 4 weeks
5. Adjust based on results

### For production apps:
1. Start conservative: 100ms penalty
2. Monitor UX impact (check app analytics for Asia users)
3. Gradually increase if no complaints
4. Max out at 500ms (don't go higher, too much UX impact)

### For apps with mostly US/Europe users:
- Skip teaching entirely
- Smart Placement already prefers nearby datacenters
- Proxy usage likely <10% naturally

### For apps with mostly Asia users:
- Teaching is VERY effective
- Asia users would hit blocked regions frequently otherwise
- 200-300ms penalty is worth the cost savings

## Disabling the Teaching

To turn off completely:
```bash
npx wrangler secret delete SMART_PLACEMENT_PENALTY_MS
npx wrangler deploy
```

Or set to 0:
```bash
npx wrangler secret put SMART_PLACEMENT_PENALTY_MS
# Enter: 0
npx wrangler deploy
```

## Questions?

**Q: Won't this hurt my Asia users?**
A: Yes, temporarily. But over time, Smart Placement learns and they'll get routed to US datacenters which are actually faster for reaching OpenAI (US-based).

**Q: How long to see results?**
A: 2-4 weeks minimum. Cloudflare needs traffic volume to learn patterns.

**Q: What if it doesn't work?**
A: Disable it. You're not worse off than without the penalty.

**Q: Can I set penalty = 1000ms for faster learning?**
A: Not recommended. 500ms is max. Higher delays hurt UX too much and might cause timeouts.

**Q: Will this work forever?**
A: Likely yes, but monitor monthly. If traffic patterns change drastically, Smart Placement might re-learn. Keep a small maintenance penalty (100ms) active.

## Alternative: Route Hints (Not Available)

Cloudflare doesn't currently support manual datacenter selection for Workers. If they add this feature, we could explicitly prefer US datacenters instead of using artificial delays.

Until then, teaching via latency penalties is the best approach.

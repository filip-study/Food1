# Fuzzy Matching Test Cases

## Purpose
Validate fixes for fuzzy matching issues where "Oatmeal, cooked" incorrectly matched baby food and "Banana, medium" failed to match.

## Changes Made
1. Added size descriptors to cleaning removal list: medium, large, small, thick, thin, tiny, giant, jumbo
2. Added "oatmeal" shortcut → fdcId 173905 (Cereals, oats, regular and quick, unenriched, cooked with water)
3. Enhanced logging for debugging matching decisions

## Critical Test Cases (Original Failures)

### Test 1: Banana with Size Descriptor
**Input:** `"Banana, medium"`
**Expected Cleaning:** `"banana, medium"` → `"banana"`
**Expected Match:** fdcId 173944 (Bananas, raw)
**Expected Method:** Shortcut
**Validation:** Size descriptor "medium" should be removed during cleaning, allowing shortcut match to "banana"

### Test 2: Oatmeal (Generic Term)
**Input:** `"Oatmeal, cooked"`
**Expected Cleaning:** `"oatmeal, cooked"` → `"oatmeal"`
**Expected Match:** fdcId 173905 (Cereals, oats, regular and quick, unenriched, cooked with water)
**Expected Method:** Shortcut
**Validation:** Should hit shortcut immediately, NOT search database and return baby food

## Additional Test Cases

### Size Descriptors
- **Large apple** → Should clean to "apple" and search database
- **Small chicken breast** → Should clean to "chicken breast" → fdcId 171477 (Shortcut)
- **Thick bacon** → Should clean to "bacon" → fdcId 167914 (Shortcut)
- **Thin pizza** → Should clean to "pizza" and search database
- **Jumbo shrimp** → Should clean to "shrimp" → fdcId 175180 (Shortcut)

### Existing Shortcuts (Regression Testing)
- **Egg** → fdcId 171287 (Egg, whole, raw, fresh)
- **Chicken breast, grilled** → Should clean to "chicken breast" → fdcId 171477
- **Strawberries, fresh** → Should clean to "strawberries" → fdcId 167762
- **Rice white, cooked** → Should clean to "rice white" → fdcId 168878
- **Banana** → fdcId 173944 (Bananas, raw)

### Generic Terms (Pollution Risk)
- **Milk** → fdcId 171265 (Milk, whole, 3.25% milkfat) [Shortcut - should NOT return baby formula]
- **Chicken** → Should search database with LLM (no "chicken" only shortcut)
- **Oats** → fdcId 171662 (Cereals, oats, instant, fortified, plain)

### Edge Cases
- **Medium-sized banana** → Should remove "medium" (not "sized")
- **Extra large eggs** → Should remove "extra" and "large"
- **Small, diced tomatoes** → Should remove "small" and "diced" → "tomatoes" → fdcId 170457

## How to Test

### Option 1: Run in Xcode with Breakpoints
1. Open Food1.xcodeproj
2. Set breakpoint in `FuzzyMatchingService.matchWithMethod()` at line 249
3. Log a meal with test ingredients via app UI
4. Check console output for:
   - ✅ Cleaned query transformation
   - ✅ Shortcut hit/miss logging
   - ✅ Final match with fdcId
   - ✅ Match method (Shortcut/LLM/Exact)

### Option 2: Use Evaluation Scripts
```bash
cd evaluation
# Create test images with banana and oatmeal
python run_evaluation.py --images test_banana.jpg test_oatmeal.jpg
python find_usda_matches.py --check-shortcuts
```

### Option 3: Manual Testing in App
1. Launch app in simulator
2. Quick Add Meal → Manual Entry
3. Enter "Banana, medium" with 100g
4. Save and check if enriched with correct USDA data
5. Repeat with "Oatmeal, cooked"

## Success Criteria

✅ "Banana, medium" matches fdcId 173944 via Shortcut
✅ "Oatmeal, cooked" matches fdcId 173905 via Shortcut (NOT baby food)
✅ Size descriptors are removed during cleaning (logged in console)
✅ All existing shortcuts still work (no regressions)
✅ Console logs show clear matching decision path
✅ No NULL results for common foods with size descriptors

## Expected Console Output Examples

### Successful Banana Match
```
🔍 Cleaned query: 'Banana, medium' → 'banana'
⚡ Shortcut match: 'Bananas, raw' (fdcId: 173944)
```

### Successful Oatmeal Match
```
🔍 Cleaned query: 'Oatmeal, cooked' → 'oatmeal'
⚡ Shortcut match: 'Cereals, oats, regular and quick, unenriched, cooked with water' (fdcId: 173905)
```

### Size Descriptor Removal Working
```
🔍 Cleaned query: 'Chicken breast, large' → 'chicken breast'
⚡ Shortcut match: 'Chicken, broilers or fryers, breast, meat only, cooked, roasted' (fdcId: 171477)
```

## Failure Patterns to Watch For

❌ "Banana, medium" returns NULL (AND search failed)
❌ "Oatmeal" returns baby food (database pollution)
❌ Size descriptors NOT removed (shortcut miss when should hit)
❌ Existing shortcuts broken by changes

## Next Steps After Validation

1. If tests pass: Run full evaluation suite on 49 images
2. If tests fail: Check console logs for specific failure point
3. Add any new common foods discovered to shortcuts
4. Update CLAUDE.md with findings

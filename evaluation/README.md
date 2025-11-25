# Fuzzy Matching Evaluation

Tools and scripts for evaluating and improving the USDA ingredient matching pipeline.

## Quick Start

### 1. Add Test Images
Place food images in `images/` with naming like:
```
01_scrambled_eggs.jpg
02_chicken_salad.jpg
```

### 2. Run Evaluation
```bash
OPENAI_API_KEY="your-key" python3 run_evaluation.py
```

### 3. Analyze Results
```bash
python3 analyze_results.py     # Frequency analysis
python3 analyze_cleaned.py     # Cleaned name patterns
python3 find_usda_matches.py   # Database matches
python3 create_shortcuts.py    # Generate shortcuts
```

## Files

### Scripts
- `download_images.py` - Download test images from Pexels (requires API key)
- `download_google_images.py` - Download 50 diverse food images from Google Custom Search API
- `run_evaluation.py` - Run images through GPT-4o pipeline
- `analyze_results.py` - Analyze ingredient frequency
- `analyze_cleaned.py` - Analyze cleaned ingredient names
- `find_usda_matches.py` - Find USDA database matches
- `create_shortcuts.py` - Generate verified shortcuts

### Results
- `results/evaluation_results.json` - Raw GPT-4o responses
- `results/ingredient_analysis.json` - Frequency data
- `results/cleaned_analysis.json` - Cleaned name patterns
- `results/usda_matches.json` - Database search results
- `results/verified_shortcuts.json` - Final shortcut mappings

### Documentation
- `docs/EVALUATION_FINDINGS.md` - Detailed analysis and recommendations

## Cost

- ~1,000 tokens per image
- ~$0.005 per image
- 50 images ≈ $0.25

## Process for Future Evaluations

1. Collect new test images representing real usage
2. Run evaluation pipeline
3. Analyze patterns in cleaned names
4. Find USDA matches for top ingredients
5. Add verified shortcuts to FuzzyMatchingService.swift
6. Test and measure improvement

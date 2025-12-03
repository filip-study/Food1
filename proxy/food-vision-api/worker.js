/**
 * Cloudflare Worker Proxy for Vision APIs (OpenAI GPT-4o & Google Gemini 2.0 Flash)
 *
 * This proxy:
 * - Securely stores API keys (never exposed to iOS app)
 * - Supports multiple vision providers: GPT-4o (default) and Gemini 2.0 Flash
 * - Handles CORS for iOS requests
 * - Forwards image analysis requests to selected provider
 * - Returns structured JSON nutrition data
 * - SMART ROUTING: Preemptively routes through AI Gateway for blocked regions (OpenAI)
 * - MONITORING: Logs metrics for observability
 *
 * Production improvements (2025-11-28):
 * - Multi-provider support with easy switching via VISION_PROVIDER env var
 * - Gemini 2.5 Flash for vision (78% cheaper than GPT-4o, $63/month for 1K users)
 * - Gemini 2.0 Flash-Lite for USDA matching (~$12/month for 1K users)
 * - Backward compatible with existing GPT-4o implementation
 * - Comprehensive error handling for all paths
 * - Monitoring metrics for performance tracking
 */

// Cloudflare data centers in OpenAI-blocked regions
// Workers executing here will route through AI Gateway proactively
const BLOCKED_COLOS = new Set([
  // China
  'PEK', 'SHA', 'SZX', 'HKG', 'TPE', 'CAN', 'HGH', 'CTU', 'WUH',
  // Russia
  'SVO', 'DME', 'LED',
  // Iran
  'THR', 'IKA',
  // Other potentially blocked
  'KHI'  // Pakistan (sometimes blocked)
]);

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS();
    }

    // Only accept POST requests
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405);
    }

    // Log execution location for debugging
    const colo = request.cf?.colo;
    console.log(`📍 Worker executing in: ${colo || 'unknown'}`);

    try {
      // Route to appropriate handler
      const url = new URL(request.url);

      if (url.pathname.endsWith('/analyze')) {
        return await handleFoodAnalysis(request, env);
      } else if (url.pathname.endsWith('/analyze-label')) {
        return await handleNutritionLabel(request, env);
      } else if (url.pathname.endsWith('/analyze-meal-text')) {
        return await handleMealTextAnalysis(request, env);
      } else if (url.pathname.endsWith('/match-usda')) {
        return await handleUSDAMatching(request, env);
      } else {
        return jsonResponse({ error: 'Not found' }, 404);
      }
    } catch (error) {
      console.error('Routing error:', error);
      return jsonResponse({
        error: 'Internal server error',
        message: error.message
      }, 500);
    }
  }
};

/**
 * Shared function to call OpenAI API with smart geographic routing
 * Routes requests through AWS proxy when executing in OpenAI-blocked regions
 *
 * @param {Request} request - Original request (for COLO detection)
 * @param {Object} env - Environment variables
 * @param {Object} openaiRequest - OpenAI API request body
 * @returns {Promise<{response: Response, colo: string, usedProxy: boolean, startTime: number}>}
 */
async function callOpenAI(request, env, openaiRequest) {
  const startTime = Date.now();
  const colo = request.cf?.colo || 'unknown';
  const isBlockedRegion = BLOCKED_COLOS.has(colo);

  // Determine routing strategy
  let targetUrl, headers, routingMethod;

  if (isBlockedRegion) {
    // SMART PLACEMENT TEACHING: Add large delay in blocked regions
    // Goal: Teach Smart Placement to NEVER route through these regions
    // Since we don't have AWS proxy yet, these fail anyway - might as well make them slow too
    // Over 2-4 weeks, Smart Placement should learn to avoid HKG, China, Russia entirely
    const teachingDelayMs = parseInt(env.SMART_PLACEMENT_PENALTY_MS || '3000');
    if (teachingDelayMs > 0) {
      console.log(`⏱️  Teaching penalty: Adding ${teachingDelayMs}ms delay in blocked region`);
      await new Promise(resolve => setTimeout(resolve, teachingDelayMs));
    }

    if (env.PROXY_URL) {
      // Route through AWS proxy if configured
      console.log(`🌍 COLO: ${colo} (BLOCKED), Routing: AWS Proxy`);

      // Parse proxy URL to extract credentials and base URL
      const proxyUrlObj = new URL(env.PROXY_URL);
      targetUrl = `${proxyUrlObj.origin}/v1/chat/completions`;

      headers = {
        'Content-Type': 'application/json',
        'X-OpenAI-API-Key': env.OPENAI_API_KEY  // Pass API key as custom header
      };

      // Add Basic Auth if proxy URL contains credentials
      if (proxyUrlObj.username && proxyUrlObj.password) {
        const auth = btoa(`${proxyUrlObj.username}:${proxyUrlObj.password}`);
        headers['Authorization'] = `Basic ${auth}`;
      }

      routingMethod = 'proxy';
    } else {
      // No proxy configured - try direct (will likely fail with 403)
      console.log(`🌍 COLO: ${colo} (BLOCKED), No proxy - attempting direct (will likely fail)`);
      targetUrl = 'https://api.openai.com/v1/chat/completions';
      headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`
      };
      routingMethod = 'direct-blocked';
    }
  } else {
    // Direct connection to OpenAI (normal regions)
    console.log(`🌍 COLO: ${colo}, Routing: Direct OpenAI`);
    targetUrl = 'https://api.openai.com/v1/chat/completions';
    headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`
    };
    routingMethod = 'direct';
  }

  try {
    const response = await fetch(targetUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(openaiRequest)
    });

    console.log(`✅ ${routingMethod} request completed: HTTP ${response.status}`);
    return { response, colo, usedProxy: routingMethod === 'proxy', startTime };

  } catch (error) {
    console.error(`❌ ${routingMethod} request failed:`, error.message);

    // Fallback: Try direct OpenAI if proxy fails and we haven't tried it yet
    if (routingMethod === 'proxy') {
      console.log('🔄 Proxy failed, attempting direct OpenAI as fallback...');
      try {
        const fallbackResponse = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${env.OPENAI_API_KEY}`
          },
          body: JSON.stringify(openaiRequest)
        });

        console.log(`✅ Fallback successful: HTTP ${fallbackResponse.status}`);
        return { response: fallbackResponse, colo, usedProxy: false, startTime };
      } catch (fallbackError) {
        console.error('❌ Fallback also failed:', fallbackError.message);
        throw fallbackError;
      }
    }

    throw error;
  }
}

/**
 * Validate and handle OpenAI API response with comprehensive error handling
 *
 * @param {Response} response - OpenAI API response
 * @param {string} colo - Cloudflare data center code
 * @param {boolean} usedProxy - Whether AWS proxy was used
 * @returns {Promise<Response>} - JSON response or throws error
 */
async function handleOpenAIResponse(response, colo, usedProxy) {
  console.log(`✅ Response status: ${response.status} (${usedProxy ? 'AWS Proxy' : 'Direct'})`);

  if (!response.ok) {
    const error = await response.json();
    console.error('❌ OpenAI error:', error);

    // Handle specific error codes
    if (response.status === 429) {
      return jsonResponse({
        error: 'Rate limit exceeded. Please try again later.'
      }, 429);
    }

    if (response.status === 401) {
      return jsonResponse({
        error: 'API authentication failed',
        details: 'OpenAI API key is invalid or expired'
      }, 500);
    }

    if (response.status === 403) {
      // This shouldn't happen with proxy routing, but log for monitoring
      console.error(`⚠️ Geographic block despite routing logic. COLO: ${colo}, Proxy: ${usedProxy}`);
      return jsonResponse({
        error: 'Geographic restriction',
        details: 'OpenAI API unavailable from this region. Please contact support.',
        colo: colo,
        debugInfo: `Routed via ${usedProxy ? 'AWS Proxy' : 'Direct'}`
      }, 503);
    }

    // Generic error
    return jsonResponse({
      error: 'AI service error',
      details: error.error?.message || 'Unknown error',
      status: response.status
    }, response.status);
  }

  return null; // Success - no error response
}

/**
 * Call Gemini API for vision tasks
 *
 * @param {Object} env - Environment variables
 * @param {string} prompt - Text prompt for analysis
 * @param {string} imageBase64 - Base64-encoded image data (without data:image prefix)
 * @param {Object} options - Additional options (maxTokens, temperature)
 * @returns {Promise<{response: Response, startTime: number}>}
 */
async function callGemini(env, prompt, imageBase64, options = {}) {
  const startTime = Date.now();

  if (!env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  // Remove data URL prefix if present
  const cleanBase64 = imageBase64.replace(/^data:image\/[a-z]+;base64,/, '');

  // Build Gemini API request
  const geminiRequest = {
    contents: [
      {
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: 'image/jpeg',
              data: cleanBase64
            }
          }
        ]
      }
    ],
    generationConfig: {
      temperature: options.temperature || 0.0,
      maxOutputTokens: options.maxTokens || 600,
      topP: 1.0,
      responseMimeType: 'application/json'  // Request JSON response
    }
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${env.GEMINI_API_KEY}`;

  console.log('📤 Calling Gemini 2.0 Flash API...');

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(geminiRequest)
  });

  console.log(`✅ Gemini response: HTTP ${response.status}`);
  return { response, startTime };
}

/**
 * Handle Gemini API response and convert to OpenAI-compatible format
 *
 * @param {Response} response - Gemini API response
 * @returns {Promise<Object>} - Plain object with success/error flag
 */
async function handleGeminiResponse(response) {
  if (!response.ok) {
    const error = await response.json();
    console.error('❌ Gemini error:', error);

    // Return error object (not Response)
    return {
      error: 'AI service error',
      details: error.error?.message || 'Unknown error',
      status: response.status
    };
  }

  // Parse Gemini response
  const data = await response.json();

  // Extract text from Gemini response structure
  const candidates = data.candidates;
  if (!candidates || candidates.length === 0) {
    console.error('No candidates in Gemini response:', data);
    return {
      error: 'No response from AI',
      details: 'Gemini returned no candidates',
      status: 500
    };
  }

  const content = candidates[0]?.content?.parts?.[0]?.text;
  if (!content) {
    console.error('No content in Gemini response:', data);
    return {
      error: 'No response from AI',
      details: 'Gemini returned empty content',
      status: 500
    };
  }

  // Parse JSON response
  let analysisResult;
  try {
    analysisResult = JSON.parse(content);
  } catch (e) {
    console.error('Failed to parse Gemini response:', content);
    return {
      error: 'Invalid response format from AI',
      raw: content,
      status: 500
    };
  }

  // Convert to OpenAI-compatible format
  return {
    success: true,
    data: analysisResult,
    usage: {
      promptTokens: data.usageMetadata?.promptTokenCount || 0,
      completionTokens: data.usageMetadata?.candidatesTokenCount || 0,
      totalTokens: data.usageMetadata?.totalTokenCount || 0
    },
    provider: 'gemini'
  };
}

/**
 * Handle food recognition from image
 */
async function handleFoodAnalysis(request, env) {
  try {
      // Verify authentication token
      const authToken = request.headers.get('Authorization');
      if (!authToken || authToken !== `Bearer ${env.AUTH_TOKEN}`) {
        return jsonResponse({ error: 'Unauthorized' }, 401);
      }

      // Determine which vision provider to use (default: gemini)
      const provider = env.VISION_PROVIDER || 'gemini';
      console.log(`🔧 Vision provider: ${provider}`);

      // Verify appropriate API key is configured
      if (provider === 'gemini' && !env.GEMINI_API_KEY) {
        console.error('GEMINI_API_KEY not configured');
        return jsonResponse({ error: 'Server configuration error' }, 500);
      } else if (provider === 'openai' && !env.OPENAI_API_KEY) {
        console.error('OPENAI_API_KEY not configured');
        return jsonResponse({ error: 'Server configuration error' }, 500);
      }

      // Parse request body
      const body = await request.json();
      const { image, userId } = body;

      if (!image) {
        return jsonResponse({ error: 'Missing image data' }, 400);
      }

      // Log request details for debugging
      console.log('=== Food Analysis Request ===');
      console.log('Image size:', image.length, 'chars');
      console.log('Image prefix:', image.substring(0, 50));

      // Common prompt for both providers
      const foodAnalysisPrompt = `IMPORTANT: I'm using a nutrition tracking app to log my meals. I need you to analyze ONLY the food items in this photo - ignore any people, hands, or faces visible in the image. I am NOT asking you to identify or describe any people. Focus exclusively on the food.

This photo shows food I'm about to eat, and I need to track its nutritional content and ingredients for my health goals.

Please help me by analyzing what food items are visible in this photo and breaking down the key ingredients. Return the results in this JSON format:

{
  "has_packaging": false,
  "predictions": [
    {
      "label": "food name (max 40 chars, descriptive)",
      "confidence": 0.95,
      "description": "brief description",
      "nutrition": {
        "calories": 250,
        "protein": 20.0,
        "carbs": 30.0,
        "fat": 10.0,
        "estimated_grams": 150
      },
      "ingredients": [
        {"name": "romaine lettuce", "grams": 127},
        {"name": "grilled chicken breast", "grams": 102},
        {"name": "cherry tomatoes", "grams": 68}
      ]
    }
  ]
}

Guidelines for your analysis:
- CRITICAL: Keep food names under 40 characters but be descriptive (e.g., "Grilled Chicken Caesar Salad" is good, "Grilled Chicken Caesar Salad Bowl with Extra Dressing" is too long)
- Use specific, natural names that clearly identify the food and cooking method when space allows
- Set has_packaging to true if the food is in packaging/wrapper/box/container (unopened or partially opened)
- Set has_packaging to false for fresh/prepared food on plates/bowls
- Include up to 5 predictions if multiple food items are visible
- Order predictions by confidence (0.0-1.0)
- Use empty array if confidence is below 0.3
- For estimated_grams: estimate the weight in grams of the food VISIBLE IN THE PHOTO (not a standard serving)
- Nutrition values should reflect the entire amount of food visible in the photo (based on estimated_grams)
- Use realistic portion sizes (e.g., apple: 150-200g, chicken breast: 150-250g, bowl of pasta: 200-300g)

INGREDIENT EXTRACTION:
- CRITICAL: Every ingredient MUST be specific enough to have nutritional value in USDA database
- CRITICAL: Use specific, USDA-matchable ingredient names (e.g., "Chicken breast, grilled" not just "chicken")
- Break down composite meals into key ingredients with gram estimates
- Apply 15% conservative reduction to all gram estimates (better to underestimate than overestimate)
- List 3-8 main ingredients (don't list every tiny ingredient like spices)

ABSOLUTELY NEVER use vague placeholder terms:
  * FORBIDDEN: "Topping, shredded" (what topping? cheese? coconut? chocolate?)
  * FORBIDDEN: "Sauce" (what sauce? tomato? soy? cream?)
  * FORBIDDEN: "Seasoning", "Garnish", "Dressing" without specifics
  * REQUIRED: Be specific or skip it entirely
  * GOOD: "Cheese, cheddar, shredded", "Soy sauce", "Ranch dressing", "Cilantro, fresh"
  * If you cannot identify what an ingredient is, DO NOT include it in the ingredients array

Use generic ingredient names that match USDA database:
  * "Chicken breast, grilled" or "Chicken breast, roasted" (specify cooking method)
  * "Lettuce, romaine" or "Lettuce, iceberg" (specify variety)
  * "Rice, brown" or "Rice, white" (specify type)
  * "Olive oil" or "Butter" (use generic fat names)
  * Avoid brand names, adjectives like "organic", "free-range"
  * AVOID generic mixed categories like "Dried fruits, mixed" or "Nuts, mixed" - instead list specific items like "Raisins", "Dates", "Almonds", "Walnuts"
- For simple meals (like an apple or banana), use single ingredient: [{"name": "Apple, raw", "grams": 170}]
- Ingredient grams should roughly sum to estimated_grams (within 10-20% variance for condiments/oils)
- If a meal is too complex to break down confidently, use empty ingredients array []

Return ONLY the JSON object, no additional text.`;

      // Route to appropriate provider
      let result;

      if (provider === 'gemini') {
        // Call Gemini API
        const { response: geminiResponse, startTime } = await callGemini(
          env,
          foodAnalysisPrompt,
          image,
          { maxTokens: 800, temperature: 0.0 }  // Gemini 2.0 Flash has no thinking overhead
        );

        // Handle Gemini response
        const geminiResult = await handleGeminiResponse(geminiResponse);
        if (geminiResult.error) {
          return jsonResponse(geminiResult, geminiResult.status || 500);
        }

        // Log monitoring metrics
        const latencyMs = Date.now() - startTime;
        console.log(JSON.stringify({
          event: 'food_recognition',
          provider: 'gemini',
          status: 'success',
          latency_ms: latencyMs,
          tokens: geminiResult.usage?.totalTokens,
          predictions: geminiResult.data.predictions?.length || 0
        }));

        result = geminiResult;

      } else {
        // Call OpenAI API (default)
        const openaiRequest = {
          model: 'gpt-4o',
          messages: [
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: foodAnalysisPrompt
                },
                {
                  type: 'image_url',
                  image_url: {
                    url: image.startsWith('data:') ? image : `data:image/jpeg;base64,${image}`,
                    detail: 'low'  // Use low-detail mode for 3-5x faster processing
                  }
                }
              ]
            }
          ],
          max_tokens: 600,
          response_format: { type: 'json_object' }
        };

        const { response: openaiResponse, colo, usedProxy, startTime } = await callOpenAI(request, env, openaiRequest);

        // Handle errors
        const errorResponse = await handleOpenAIResponse(openaiResponse, colo, usedProxy);
        if (errorResponse) {
          return errorResponse;
        }

        // Parse OpenAI response
        const data = await openaiResponse.json();
        const message = data.choices?.[0]?.message;
        const content = message?.content;
        const refusal = message?.refusal;

        // Check for refusal
        if (refusal) {
          console.error('GPT-4o refused to analyze:', refusal);
          return jsonResponse({
            error: 'AI refused to analyze image',
            details: refusal
          }, 500);
        }

        if (!content) {
          console.error('No content in OpenAI response');
          return jsonResponse({
            error: 'No response from AI',
            details: 'OpenAI returned empty content'
          }, 500);
        }

        // Parse JSON response
        let analysisResult;
        try {
          analysisResult = JSON.parse(content);
        } catch (e) {
          console.error('Failed to parse AI response:', content);
          return jsonResponse({
            error: 'Invalid response format from AI',
            raw: content
          }, 500);
        }

        // Log monitoring metrics
        const latencyMs = Date.now() - startTime;
        console.log(JSON.stringify({
          event: 'food_recognition',
          provider: 'openai',
          colo: colo,
          routing: usedProxy ? 'aws_proxy' : 'direct',
          status: 'success',
          latency_ms: latencyMs,
          tokens: data.usage?.total_tokens,
          predictions: analysisResult.predictions?.length || 0
        }));

        result = {
          success: true,
          data: analysisResult,
          usage: {
            promptTokens: data.usage?.prompt_tokens,
            completionTokens: data.usage?.completion_tokens,
            totalTokens: data.usage?.total_tokens
          },
          provider: 'openai'
        };
      }

      // Return unified response
      return jsonResponse(result);

  } catch (error) {
    console.error('Food analysis error:', error);
    return jsonResponse({
      error: 'Internal server error',
      message: error.message
    }, 500);
  }
}

/**
 * Handle natural language meal description parsing
 */
async function handleMealTextAnalysis(request, env) {
  try {
    // Verify authentication token
    const authToken = request.headers.get('Authorization');
    if (!authToken || authToken !== `Bearer ${env.AUTH_TOKEN}`) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    // Verify OpenAI API key is configured
    if (!env.OPENAI_API_KEY) {
      console.error('OPENAI_API_KEY not configured');
      return jsonResponse({ error: 'Server configuration error' }, 500);
    }

    // Parse request body
    const body = await request.json();
    const { text, userId } = body;

    if (!text || typeof text !== 'string') {
      return jsonResponse({ error: 'Missing or invalid text data' }, 400);
    }

    // Log request details for debugging
    console.log('=== Meal Text Analysis Request ===');
    console.log('Text:', text);
    console.log('Length:', text.length, 'chars');

    // Build OpenAI API request for text parsing (using chat completion, not vision)
    const openaiRequest = {
      model: 'gpt-4o',
      messages: [
        {
          role: 'user',
          content: `I'm using a nutrition tracking app and need help logging a meal. Please analyze this meal description and provide nutritional estimates.

Meal description: "${text}"

Please parse this description and return a JSON object with estimated nutrition information and ingredients in this format:

{
  "has_packaging": false,
  "predictions": [
    {
      "label": "meal name (max 40 chars, descriptive)",
      "emoji": "🍳",
      "confidence": 0.95,
      "description": "brief description of the meal",
      "nutrition": {
        "calories": 250,
        "protein": 20.0,
        "carbs": 30.0,
        "fat": 10.0,
        "estimated_grams": 150
      },
      "ingredients": [
        {"name": "ingredient 1", "grams": 100},
        {"name": "ingredient 2", "grams": 50}
      ]
    }
  ]
}

Guidelines for your analysis:
- CRITICAL: Keep meal names under 40 characters but be descriptive
- EMOJI: Choose a single emoji that best represents the food (e.g., 🍳 for eggs, 🥗 for salad, 🍕 for pizza, 🥩 for meat, 🍚 for rice dishes, 🍜 for noodles)
- Set has_packaging to false for natural language descriptions (only true for packaged foods)
- Parse quantities from the text (e.g., "3 eggs" → 150g, "2 slices" → estimate grams)
- If no quantities specified, use typical portion sizes
- Set confidence based on how clear the description is (0.7-1.0 for clear descriptions, 0.3-0.7 for vague ones)
- Provide a single prediction (the best interpretation of the meal)
- For estimated_grams: sum of all ingredient weights
- Nutrition values should reflect the total meal based on estimated_grams

INGREDIENT EXTRACTION:
- CRITICAL: Use specific, USDA-matchable ingredient names (e.g., "Eggs, whole, raw" or "Eggs, scrambled")
- Break down the meal into individual ingredients with gram estimates
- Apply 15% conservative reduction to all gram estimates (better to underestimate)
- List all mentioned ingredients
- Use generic ingredient names that match USDA database:
  * "Eggs, whole, raw" or "Eggs, scrambled" (specify preparation if mentioned)
  * "Chicken breast, grilled" or "Chicken breast, raw"
  * "Rice, brown, cooked" or "Rice, white, cooked"
  * "Bacon, cooked" (specify cooking state)
  * "Mayonnaise" or "Mayo, regular"
  * Avoid brand names, adjectives like "organic", "free-range"
  * Be specific about cooking methods when mentioned in the description
- Ingredient grams should sum to estimated_grams (within 10-20% variance)

QUANTITY PARSING:
- "3 eggs" → ~150g (50g per large egg)
- "2 slices bacon" → ~30g (15g per slice)
- "1 teaspoon mayo" → ~5g
- "1 tablespoon" → ~15g
- "1 cup rice" → ~185g cooked
- "100g" → 100g (use exact weight if provided)
- "chicken breast" (no quantity) → ~150g typical serving
- "handful of nuts" → ~30g
- "large apple" → ~200g
- "medium banana" → ~120g

Return ONLY the JSON object, no additional text.`
        }
      ],
      max_tokens: 600,
      response_format: { type: 'json_object' }
    };

    // Call OpenAI API with smart geographic routing
    const { response: openaiResponse, colo, usedProxy, startTime } = await callOpenAI(request, env, openaiRequest);

    // Handle errors with comprehensive error handling
    const errorResponse = await handleOpenAIResponse(openaiResponse, colo, usedProxy);
    if (errorResponse) {
      return errorResponse;
    }

    // Parse OpenAI response
    const data = await openaiResponse.json();
    console.log('OpenAI text analysis response:', JSON.stringify(data));

    const message = data.choices?.[0]?.message;
    const content = message?.content;
    const refusal = message?.refusal;

    // Check for refusal first
    if (refusal) {
      console.error('GPT-4o refused to analyze:', refusal);
      return jsonResponse({
        error: 'AI refused to analyze text',
        details: refusal
      }, 500);
    }

    if (!content) {
      console.error('No content in OpenAI response. Full response:', JSON.stringify(data));
      return jsonResponse({
        error: 'No response from AI',
        details: 'OpenAI returned empty content'
      }, 500);
    }

    // Parse JSON response from GPT-4o
    let analysisResult;
    try {
      analysisResult = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse AI response:', content);
      return jsonResponse({
        error: 'Invalid response format from AI',
        raw: content
      }, 500);
    }

    // Log monitoring metrics for observability
    const latencyMs = Date.now() - startTime;
    console.log(JSON.stringify({
      event: 'meal_text_analysis',
      colo: colo,
      routing: usedProxy ? 'aws_proxy' : 'direct',
      status: 'success',
      latency_ms: latencyMs,
      tokens: data.usage?.total_tokens,
      predictions: analysisResult.predictions?.length || 0,
      text_length: text.length
    }));

    // Return structured response
    return jsonResponse({
      success: true,
      data: analysisResult,
      usage: {
        promptTokens: data.usage?.prompt_tokens,
        completionTokens: data.usage?.completion_tokens,
        totalTokens: data.usage?.total_tokens
      }
    });

  } catch (error) {
    console.error('Meal text analysis error:', error);
    return jsonResponse({
      error: 'Internal server error',
      message: error.message
    }, 500);
  }
}

/**
 * Handle nutrition label extraction from image
 */
async function handleNutritionLabel(request, env) {
  try {
    // Verify authentication token
    const authToken = request.headers.get('Authorization');
    if (!authToken || authToken !== `Bearer ${env.AUTH_TOKEN}`) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    // Parse request body
    const body = await request.json();
    const { image, userId } = body;

    if (!image) {
      return jsonResponse({ error: 'Missing image data' }, 400);
    }

    // Build OpenAI API request for nutrition label extraction
    const openaiRequest = {
      model: 'gpt-4o',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: `IMPORTANT: I'm using a nutrition tracking app and need to log a packaged food item. I need you to analyze ONLY the nutrition facts label in this photo - ignore any people, hands, or faces visible in the image. I am NOT asking you to identify or describe any people. Focus exclusively on the nutrition label text.

This photo shows the nutrition facts label on the package. Please help me by extracting the nutrition information from this label so I can accurately track my intake.

Return the extracted information in this JSON format:

{
  "product_name": "product name (max 40 chars, descriptive)",
  "brand": "brand name if visible",
  "serving_size": "1 container (150g)",
  "servings_per_container": 1,
  "estimated_grams": 150,
  "nutrition": {
    "calories": 250,
    "protein": 20.0,
    "carbs": 30.0,
    "fat": 10.0,
    "fiber": 5.0,
    "sugar": 10.0,
    "sodium": 300
  },
  "confidence": 0.95
}

Guidelines for extraction:
- CRITICAL: Keep product_name under 40 characters but be descriptive (include brand and product type when space allows)
- Extract exact values from the nutrition facts label
- All nutrition values should be in grams except sodium (which is in mg)
- For estimated_grams: extract the serving size weight from the label (e.g., "1 container (150g)" → 150)
- Set confidence based on label clarity (0.0-1.0)
- Use null values if information is not visible or unclear
- Include fiber, sugar, and sodium if they're shown on the label

Return ONLY the JSON object, no additional text.`
            },
            {
              type: 'image_url',
              image_url: {
                url: image.startsWith('data:') ? image : `data:image/jpeg;base64,${image}`,
                detail: 'high'  // Use high-detail for accurate label reading
              }
            }
          ]
        }
      ],
      max_tokens: 500,
      response_format: { type: 'json_object' }
    };

    // Call OpenAI API with smart geographic routing
    const { response: openaiResponse, colo, usedProxy, startTime } = await callOpenAI(request, env, openaiRequest);

    // Handle errors with comprehensive error handling
    const errorResponse = await handleOpenAIResponse(openaiResponse, colo, usedProxy);
    if (errorResponse) {
      return errorResponse;
    }

    // Parse OpenAI response
    const data = await openaiResponse.json();
    const content = data.choices[0]?.message?.content;

    if (!content) {
      return jsonResponse({ error: 'No response from AI' }, 500);
    }

    // Parse JSON response from GPT-4o
    let labelData;
    try {
      labelData = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse AI response:', content);
      return jsonResponse({
        error: 'Invalid response format from AI',
        raw: content
      }, 500);
    }

    // Log monitoring metrics for observability
    const latencyMs = Date.now() - startTime;
    console.log(JSON.stringify({
      event: 'nutrition_label',
      colo: colo,
      routing: usedProxy ? 'aws_proxy' : 'direct',
      status: 'success',
      latency_ms: latencyMs,
      tokens: data.usage?.total_tokens,
      confidence: labelData.confidence
    }));

    // Return structured response
    return jsonResponse({
      success: true,
      data: labelData,
      usage: {
        promptTokens: data.usage?.prompt_tokens,
        completionTokens: data.usage?.completion_tokens,
        totalTokens: data.usage?.total_tokens
      }
    });

  } catch (error) {
    console.error('Label analysis error:', error);
    return jsonResponse({
      error: 'Internal server error',
      message: error.message
    }, 500);
  }
}

/**
 * Helper function to return JSON responses with CORS headers
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

/**
 * Handle USDA food matching/reranking
 */
async function handleUSDAMatching(request, env) {
  try {
    // Verify authentication token
    const authToken = request.headers.get('Authorization');
    if (!authToken || authToken !== `Bearer ${env.AUTH_TOKEN}`) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    // Verify Gemini API key is configured
    if (!env.GEMINI_API_KEY) {
      console.error('GEMINI_API_KEY not configured');
      return jsonResponse({ error: 'Server configuration error' }, 500);
    }

    // Parse request body
    const body = await request.json();
    const { ingredientName, candidates } = body;

    if (!ingredientName || !candidates || !Array.isArray(candidates)) {
      return jsonResponse({
        error: 'Missing or invalid request data',
        details: 'Expected: { ingredientName: string, candidates: array }'
      }, 400);
    }

    console.log(`=== USDA Matching Request ===`);
    console.log(`Ingredient: ${ingredientName}`);
    console.log(`Candidates: ${candidates.length}`);

    // Build prompt for Gemini
    let candidateList = "0. None of these match";
    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i];
      const number = i + 1;
      // Clean up USDA descriptions
      const cleanedDescription = candidate.description
        .replace(/\(Includes foods for USDA's Food Distribution Program\)/g, '')
        .trim();
      candidateList += `\n${number}. ${cleanedDescription}`;
    }

    const prompt = `You are a fuzzy matching agent that finds equivalent database entries.

Match this food: "${ingredientName}", with its best nutritional equivalent from the USDA Food database below.

MATCHING RULES:
- Find the closest equivalent - ideally an alternative name for the same ingredient
- If there is no direct match, but there is a close match with similar nutritional profile (vitamins, minerals), choose it
  Example: "Chocolate, dark" → "Chocolate, dark, 60%" is acceptable
- Do NOT pick processed versions or products made from the initial food
  Example: "Potato" → REJECT "French fries", "Milk" → REJECT "Milk fudge candy", "Brown rice" → REJECT "Brown rice cakes"
- If unbranded food was given, only consider unbranded options

WHEN TO PICK 0 (no match):
- The ingredient name is too vague or generic (e.g., "Topping, shredded", "Sauce", "Seasoning")
- No options are the same ingredient or close nutritional equivalent
- All options are processed/transformed versions of the ingredient
- The ingredient cannot be reasonably matched to any USDA database entry

The format of the USDA database is more or less like this:
Item name, description, description, description, description

For example:
"Oil, olive, salad or cooking" - this means we are talking about olive oil used in either salads or cooking
"Chicken, liver, all classes, cooked, simmered" - this means we are talking about most types of chicken liver in cooked form, specifically simmered

Examples of good picks (format Food given -> List item):
"Broccoli, steamed" -> "Broccoli, cooked, boiled"
"Rice, brown" -> "Rice, brown, long-grain, cooked"
"Salmon, grilled" -> "Fish, salmon, Atlantic, farmed, cooked, dry heat"

Examples of bad picks (format Food given -> List item):
"Olive oil" -> "Mayonnaise, reduced fat, with olive oil" (olive oil is part of mayo, but there is other stuff in mayo too)
"Bacon, cooked" -> "Bacon, turkey, low sodium" (if the list also has pork bacon, the bacon is most likely to be better matched to pork bacon)

Options:
${candidateList}

Analyze the ingredient "${ingredientName}" and find its best match from the options above.

You MUST think through it step-by-step before answering. Follow this exact process:

Step 1: Identify what "${ingredientName}" is (things like raw vs processed etc)
Step 2: Eliminate baby foods, fast foods, and restaurant foods from consideration FIRST
Step 3: Go through remaining options from 0-${candidates.length} and note which ones are the SAME ingredient or a variation of identical nutritional value
Step 4: Of the matching options, determine which is closest nutritionally

After this justify and make your decision.

Respond in this format:
THINKING:
Step 1: [your analysis]
Step 2: [your analysis]
Step 3: [your analysis]
Step 4: [your analysis]

[your decision]

ANSWER: [NUMBER ONLY]`;

    // Call Gemini API
    const geminiRequest = {
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.0,
        maxOutputTokens: 800,
        topP: 1.0
      }
    };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=${env.GEMINI_API_KEY}`;
    const startTime = Date.now();

    console.log('📤 Calling Gemini 2.0 Flash-Lite API...');

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(geminiRequest)
    });

    console.log(`✅ Gemini response: HTTP ${response.status}`);

    if (!response.ok) {
      const error = await response.json();
      console.error('❌ Gemini error:', error);
      return jsonResponse({
        error: 'Gemini API error',
        details: error.error?.message || 'Unknown error',
        status: response.status
      }, response.status);
    }

    // Parse Gemini response
    const data = await response.json();
    const content = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!content) {
      console.error('No content in Gemini response:', data);
      return jsonResponse({
        error: 'No response from Gemini',
        details: 'Empty content'
      }, 500);
    }

    console.log(`📥 Gemini response: ${content.substring(0, 200)}...`);

    // Parse selection from response
    let selectedIndex = null;

    // Try to find "ANSWER: [number]" pattern
    const answerPattern = /ANSWER:\s*(\d+)/i;
    const match = content.match(answerPattern);

    if (match) {
      const number = parseInt(match[1]);
      console.log(`🔍 Found 'ANSWER: ${number}' in response`);

      if (number === 0) {
        selectedIndex = null; // No match
      } else if (number >= 1 && number <= candidates.length) {
        selectedIndex = number - 1; // Convert to 0-indexed
      }
    } else {
      // Try to find last number in string
      const numbers = content.match(/\d+/g);
      if (numbers && numbers.length > 0) {
        const lastNumber = parseInt(numbers[numbers.length - 1]);
        console.log(`🔍 Found last number in response: ${lastNumber}`);

        if (lastNumber === 0) {
          selectedIndex = null;
        } else if (lastNumber >= 1 && lastNumber <= candidates.length) {
          selectedIndex = lastNumber - 1;
        }
      }
    }

    // Log monitoring metrics
    const latencyMs = Date.now() - startTime;
    console.log(JSON.stringify({
      event: 'usda_matching',
      provider: 'gemini',
      status: 'success',
      latency_ms: latencyMs,
      tokens: data.usageMetadata?.totalTokenCount,
      ingredient: ingredientName,
      candidates_count: candidates.length,
      selected_index: selectedIndex
    }));

    // Return result
    return jsonResponse({
      success: true,
      selectedIndex: selectedIndex,
      selectedFood: selectedIndex !== null ? candidates[selectedIndex] : null,
      rawResponse: content,
      usage: {
        promptTokens: data.usageMetadata?.promptTokenCount || 0,
        completionTokens: data.usageMetadata?.candidatesTokenCount || 0,
        totalTokens: data.usageMetadata?.totalTokenCount || 0
      }
    });

  } catch (error) {
    console.error('USDA matching error:', error);
    return jsonResponse({
      error: 'Internal server error',
      message: error.message
    }, 500);
  }
}

/**
 * Handle CORS preflight requests
 */
function handleCORS() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}

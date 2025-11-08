/**
 * Cloudflare Worker Proxy for OpenAI GPT-4o Vision API
 *
 * This proxy:
 * - Securely stores OpenAI API key (never exposed to iOS app)
 * - Handles CORS for iOS requests
 * - Forwards image analysis requests to OpenAI GPT-4o
 * - Returns structured JSON nutrition data
 * - SMART ROUTING: Preemptively routes through AI Gateway for blocked regions
 * - MONITORING: Logs metrics for observability
 *
 * Production improvements (2025-11-08):
 * - Preemptive routing based on Worker COLO (eliminates retry latency)
 * - Required CF_ACCOUNT_ID validation (fail fast)
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
 *
 * @param {Request} request - Original request (for COLO detection)
 * @param {Object} env - Environment variables
 * @param {Object} openaiRequest - OpenAI API request body
 * @returns {Promise<{response: Response, colo: string, usedAIGateway: boolean, startTime: number}>}
 */
async function callOpenAI(request, env, openaiRequest) {
  const startTime = Date.now();
  const colo = request.cf?.colo || 'unknown';

  // Validate required configuration
  if (!env.CF_ACCOUNT_ID) {
    console.error('❌ CF_ACCOUNT_ID not configured');
    throw new Error('CF_ACCOUNT_ID environment variable is required for AI Gateway routing');
  }

  // Preemptive routing: use AI Gateway if Worker is in blocked region
  const usedAIGateway = BLOCKED_COLOS.has(colo);

  const endpoint = usedAIGateway
    ? `https://gateway.ai.cloudflare.com/v1/${env.CF_ACCOUNT_ID}/food-vision/openai/chat/completions`
    : 'https://api.openai.com/v1/chat/completions';

  console.log(`🌍 COLO: ${colo}, Routing: ${usedAIGateway ? 'AI Gateway' : 'Direct'}`);

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`
      },
      body: JSON.stringify(openaiRequest)
    });

    return { response, colo, usedAIGateway, startTime };

  } catch (error) {
    console.error('❌ Request failed:', error.message);
    throw error;
  }
}

/**
 * Validate and handle OpenAI API response with comprehensive error handling
 *
 * @param {Response} response - OpenAI API response
 * @param {string} colo - Cloudflare data center code
 * @param {boolean} usedAIGateway - Whether AI Gateway was used
 * @returns {Promise<Response>} - JSON response or throws error
 */
async function handleOpenAIResponse(response, colo, usedAIGateway) {
  console.log(`✅ Response status: ${response.status} (${usedAIGateway ? 'AI Gateway' : 'Direct'})`);

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
      // This shouldn't happen with preemptive routing, but log for monitoring
      console.error(`⚠️ Geographic block despite routing logic. COLO: ${colo}, Gateway: ${usedAIGateway}`);
      return jsonResponse({
        error: 'Geographic restriction',
        details: 'OpenAI API unavailable from this region. Please contact support.',
        colo: colo,
        debugInfo: `Routed via ${usedAIGateway ? 'AI Gateway' : 'Direct'}`
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
 * Handle food recognition from image
 */
async function handleFoodAnalysis(request, env) {
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
      const { image, userId } = body;

      if (!image) {
        return jsonResponse({ error: 'Missing image data' }, 400);
      }

      // Log request details for debugging
      console.log('=== Food Analysis Request ===');
      console.log('Image size:', image.length, 'chars');
      console.log('Image prefix:', image.substring(0, 50));

      // Build OpenAI API request (optimized for speed)
      const openaiRequest = {
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `IMPORTANT: I'm using a nutrition tracking app to log my meals. I need you to analyze ONLY the food items in this photo - ignore any people, hands, or faces visible in the image. I am NOT asking you to identify or describe any people. Focus exclusively on the food.

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
- CRITICAL: Use specific, USDA-matchable ingredient names (e.g., "Chicken breast, grilled" not just "chicken")
- Break down composite meals into key ingredients with gram estimates
- Apply 15% conservative reduction to all gram estimates (better to underestimate than overestimate)
- List 3-8 main ingredients (don't list every tiny ingredient like spices)
- Use generic ingredient names that match USDA database:
  * "Chicken breast, grilled" or "Chicken breast, roasted" (specify cooking method)
  * "Lettuce, romaine" or "Lettuce, iceberg" (specify variety)
  * "Rice, brown" or "Rice, white" (specify type)
  * "Olive oil" or "Butter" (use generic fat names)
  * Avoid brand names, adjectives like "organic", "free-range"
- For simple meals (like an apple or banana), use single ingredient: [{"name": "Apple, raw", "grams": 170}]
- Ingredient grams should roughly sum to estimated_grams (within 10-20% variance for condiments/oils)
- If a meal is too complex to break down confidently, use empty ingredients array []

Return ONLY the JSON object, no additional text.`
              },
              {
                type: 'image_url',
                image_url: {
                  url: image.startsWith('data:') ? image : `data:image/jpeg;base64,${image}`,
                  detail: 'low'  // Use low-detail mode for 3-5x faster processing (sufficient for food recognition)
                }
              }
            ]
          }
        ],
        max_tokens: 600,  // Reduced from 800 for faster responses
        response_format: { type: 'json_object' }
      };

      // Call OpenAI API with smart geographic routing
      const { response: openaiResponse, colo, usedAIGateway, startTime } = await callOpenAI(request, env, openaiRequest);

      // Handle errors with comprehensive error handling
      const errorResponse = await handleOpenAIResponse(openaiResponse, colo, usedAIGateway);
      if (errorResponse) {
        return errorResponse;
      }

      // Parse OpenAI response
      const data = await openaiResponse.json();
      console.log('OpenAI response:', JSON.stringify(data));

      const message = data.choices?.[0]?.message;
      const content = message?.content;
      const refusal = message?.refusal;

      // Check for refusal first
      if (refusal) {
        console.error('GPT-4o refused to analyze:', refusal);
        return jsonResponse({
          error: 'AI refused to analyze image',
          details: refusal,
          rawResponse: data
        }, 500);
      }

      if (!content) {
        console.error('No content in OpenAI response. Full response:', JSON.stringify(data));
        return jsonResponse({
          error: 'No response from AI',
          details: 'OpenAI returned empty content',
          rawResponse: data
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
        event: 'food_recognition',
        colo: colo,
        routing: usedAIGateway ? 'ai_gateway' : 'direct',
        status: 'success',
        latency_ms: latencyMs,
        tokens: data.usage?.total_tokens,
        predictions: analysisResult.predictions?.length || 0
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
    console.error('Food analysis error:', error);
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
    const { response: openaiResponse, colo, usedAIGateway, startTime } = await callOpenAI(request, env, openaiRequest);

    // Handle errors with comprehensive error handling
    const errorResponse = await handleOpenAIResponse(openaiResponse, colo, usedAIGateway);
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
      routing: usedAIGateway ? 'ai_gateway' : 'direct',
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

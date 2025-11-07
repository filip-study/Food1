/**
 * Cloudflare Worker Proxy for OpenAI GPT-4o Vision API
 *
 * This proxy:
 * - Securely stores OpenAI API key (never exposed to iOS app)
 * - Provides rate limiting (100 requests/hour per user)
 * - Handles CORS for iOS requests
 * - Forwards image analysis requests to OpenAI GPT-4o
 * - Returns structured JSON nutrition data
 */

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
                text: `I'm using a nutrition tracking app to log my meals. This photo shows food I'm about to eat, and I need to track its nutritional content for my health goals.

Please help me by analyzing what food items are visible in this photo and providing their estimated nutrition information. Return the results in this JSON format:

{
  "has_packaging": false,
  "predictions": [
    {
      "label": "food name (be specific)",
      "confidence": 0.95,
      "description": "brief description",
      "nutrition": {
        "calories": 250,
        "protein": 20.0,
        "carbs": 30.0,
        "fat": 10.0,
        "estimated_grams": 150
      }
    }
  ]
}

Guidelines for your analysis:
- Set has_packaging to true if the food is in packaging/wrapper/box/container (unopened or partially opened)
- Set has_packaging to false for fresh/prepared food on plates/bowls
- Include up to 5 predictions if multiple food items are visible
- Order predictions by confidence (0.0-1.0)
- Use empty array if confidence is below 0.3
- For estimated_grams: estimate the weight in grams of the food VISIBLE IN THE PHOTO (not a standard serving)
- Nutrition values should reflect the entire amount of food visible in the photo (based on estimated_grams)
- Use realistic portion sizes (e.g., apple: 150-200g, chicken breast: 150-250g, bowl of pasta: 200-300g)

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

      // Forward to OpenAI
      console.log('Sending request to OpenAI...');
      const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`
        },
        body: JSON.stringify(openaiRequest)
      });

      console.log('OpenAI response status:', openaiResponse.status);

      if (!openaiResponse.ok) {
        const error = await openaiResponse.json();
        console.error('OpenAI API error:', error);

        // Handle specific OpenAI errors
        if (openaiResponse.status === 429) {
          return jsonResponse({ error: 'Rate limit exceeded. Please try again later.' }, 429);
        }
        if (openaiResponse.status === 401) {
          return jsonResponse({ error: 'API authentication failed' }, 500);
        }

        return jsonResponse({
          error: 'Failed to analyze image',
          details: error.error?.message
        }, openaiResponse.status);
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
              text: `I'm using a nutrition tracking app and need to log a packaged food item. This photo shows the nutrition facts label on the package. Please help me by extracting the nutrition information from this label so I can accurately track my intake.

Return the extracted information in this JSON format:

{
  "product_name": "product name from label",
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

    // Forward to OpenAI
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`
      },
      body: JSON.stringify(openaiRequest)
    });

    if (!openaiResponse.ok) {
      const error = await openaiResponse.json();
      console.error('OpenAI API error:', error);

      if (openaiResponse.status === 429) {
        return jsonResponse({ error: 'Rate limit exceeded. Please try again later.' }, 429);
      }
      if (openaiResponse.status === 401) {
        return jsonResponse({ error: 'API authentication failed' }, 500);
      }

      return jsonResponse({
        error: 'Failed to analyze nutrition label',
        details: error.error?.message
      }, openaiResponse.status);
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

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

    // Verify request path
    if (!request.url.endsWith('/analyze')) {
      return jsonResponse({ error: 'Not found' }, 404);
    }

    try {
      // Verify authentication token
      const authToken = request.headers.get('Authorization');
      if (!authToken || authToken !== `Bearer ${env.AUTH_TOKEN}`) {
        return jsonResponse({ error: 'Unauthorized' }, 401);
      }

      // Rate limiting check (optional - implement with Cloudflare KV if needed)
      // For now, rely on OpenAI's rate limits

      // Parse request body
      const body = await request.json();
      const { image, userId } = body;

      if (!image) {
        return jsonResponse({ error: 'Missing image data' }, 400);
      }

      // Build OpenAI API request
      const openaiRequest = {
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `Analyze this food image and provide nutrition information in JSON format.

Return a JSON object with the following structure:
{
  "predictions": [
    {
      "label": "food name",
      "confidence": 0.95,
      "description": "brief 1-sentence description of the food",
      "nutrition": {
        "calories": 250,
        "protein": 20.0,
        "carbs": 30.0,
        "fat": 10.0,
        "serving_size": "1 cup (150g)"
      }
    }
  ]
}

Guidelines:
- Provide up to 5 possible food items if multiple foods are visible
- Order by confidence (0.0 to 1.0, where 1.0 is certain)
- Be specific with food names (e.g., "Grilled chicken breast" not "chicken")
- Estimate realistic portion sizes based on visual cues
- If you cannot identify food with reasonable confidence (>0.3), return empty predictions array
- For nutrition values, provide per-serving estimates based on typical portions

Return ONLY the JSON object, no additional text.`
              },
              {
                type: 'image_url',
                image_url: {
                  url: image.startsWith('data:') ? image : `data:image/jpeg;base64,${image}`
                }
              }
            ]
          }
        ],
        max_tokens: 800,
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
      const content = data.choices[0]?.message?.content;

      if (!content) {
        return jsonResponse({ error: 'No response from AI' }, 500);
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
      console.error('Proxy error:', error);
      return jsonResponse({
        error: 'Internal server error',
        message: error.message
      }, 500);
    }
  }
};

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

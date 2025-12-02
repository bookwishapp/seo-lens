// Supabase Edge Function to scan domains (bypasses CORS)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

interface ScanRequest {
  domainId: string
  domainName: string
}

interface RedirectHop {
  url: string
  status_code: number
}

serve(async (req) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { domainId, domainName }: ScanRequest = await req.json()

    if (!domainId || !domainName) {
      return new Response(
        JSON.stringify({ error: 'domainId and domainName are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Ensure domain has protocol
    let url = domainName
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = `https://${url}`
    }

    // Track redirects
    const redirectChain: RedirectHop[] = []
    let currentUrl = url
    let finalStatusCode: number | null = null
    let maxRedirects = 10
    let redirectCount = 0

    try {
      // Follow redirects manually
      while (redirectCount < maxRedirects) {
        const response = await fetch(currentUrl, {
          method: 'HEAD', // Use HEAD to avoid downloading content
          redirect: 'manual', // Handle redirects manually
          headers: {
            'User-Agent': 'SEOLens/1.0 (Domain Scanner)',
          },
        })

        finalStatusCode = response.status

        // Add to redirect chain
        redirectChain.push({
          url: currentUrl,
          status_code: response.status,
        })

        // Check if this is a redirect
        if (response.status >= 300 && response.status < 400) {
          const location = response.headers.get('location')
          if (!location) break

          // Handle relative redirects
          const urlObj = new URL(currentUrl)
          currentUrl = new URL(location, urlObj).toString()
          redirectCount++
        } else {
          // Not a redirect, we're done
          break
        }
      }

      // Store results in database (upsert based on domain_id)
      const { error } = await supabaseClient
        .from('domain_status')
        .upsert({
          domain_id: domainId,
          final_url: currentUrl,
          final_status_code: finalStatusCode,
          redirect_chain: redirectChain,
          last_checked_at: new Date().toISOString(),
        }, {
          onConflict: 'domain_id'
        })

      if (error) throw error

      return new Response(
        JSON.stringify({
          success: true,
          domainId,
          finalUrl: currentUrl,
          finalStatusCode,
          redirectCount: redirectChain.length - 1,
        }),
        {
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    } catch (scanError) {
      // If scan fails, update with null values
      await supabaseClient
        .from('domain_status')
        .upsert({
          domain_id: domainId,
          final_url: null,
          final_status_code: null,
          redirect_chain: null,
          last_checked_at: new Date().toISOString(),
        }, {
          onConflict: 'domain_id'
        })

      return new Response(
        JSON.stringify({
          success: false,
          error: `Scan failed: ${scanError.message}`,
          domainId,
        }),
        {
          status: 200, // Return 200 even on scan failure
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})

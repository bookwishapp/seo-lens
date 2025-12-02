// Supabase Edge Function to scan domain pages and generate SEO suggestions

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import { DOMParser } from 'https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts'

interface ScanRequest {
  domainId: string
}

interface SuggestionInsert {
  user_id: string
  domain_id: string
  page_id: string
  suggestion_type: string
  title: string
  description: string
  severity: string
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { domainId }: ScanRequest = await req.json()

    if (!domainId) {
      return new Response(
        JSON.stringify({ error: 'domainId is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // 1) Load domain + status to get final_url and user_id
    const { data: domainRow, error: domainError } = await supabaseClient
      .from('domains')
      .select('id, user_id, domain_name')
      .eq('id', domainId)
      .maybeSingle()

    if (domainError || !domainRow) {
      return new Response(
        JSON.stringify({ error: 'Domain not found', details: domainError?.message }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get the domain status for final_url
    const { data: statusRow } = await supabaseClient
      .from('domain_status')
      .select('final_url, final_status_code')
      .eq('domain_id', domainId)
      .maybeSingle()

    // Determine URL to scan
    let urlToScan = statusRow?.final_url
    if (!urlToScan) {
      // Fall back to domain name with https
      urlToScan = domainRow.domain_name
      if (!urlToScan.startsWith('http://') && !urlToScan.startsWith('https://')) {
        urlToScan = `https://${urlToScan}`
      }
    }

    const userId = domainRow.user_id

    // 2) Fetch homepage HTML
    let homeHtml: string
    let homeStatus = 0
    try {
      const response = await fetch(urlToScan, {
        method: 'GET',
        headers: {
          'User-Agent': 'SEOLens/1.0 (Page Scanner)',
          'Accept': 'text/html,application/xhtml+xml',
        },
        redirect: 'follow',
      })
      homeStatus = response.status
      homeHtml = await response.text()
    } catch (fetchError) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Failed to fetch homepage: ${fetchError.message}`,
          domainId
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3) Parse HTML with DOMParser
    const doc = new DOMParser().parseFromString(homeHtml, 'text/html')

    const title = doc?.querySelector('title')?.textContent?.trim() ?? null
    const metaDesc = doc?.querySelector('meta[name="description"]')?.getAttribute('content')?.trim() ?? null
    const canonical = doc?.querySelector('link[rel="canonical"]')?.getAttribute('href')?.trim() ?? null
    const robots = doc?.querySelector('meta[name="robots"]')?.getAttribute('content')?.trim() ?? null
    const h1 = doc?.querySelector('h1')?.textContent?.trim() ?? null

    // 4) Upsert homepage into site_pages
    const { data: pageRow, error: upsertError } = await supabaseClient
      .from('site_pages')
      .upsert({
        user_id: userId,
        domain_id: domainId,
        url: urlToScan,
        http_status: homeStatus,
        title,
        meta_description: metaDesc,
        canonical_url: canonical,
        robots_directive: robots,
        h1,
        last_scanned_at: new Date().toISOString(),
      }, {
        onConflict: 'domain_id,url'
      })
      .select()
      .maybeSingle()

    if (upsertError) {
      console.error('Upsert error:', upsertError)
      return new Response(
        JSON.stringify({
          success: false,
          error: `Failed to save page data: ${upsertError.message}`,
          domainId
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!pageRow) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to retrieve page after upsert',
          domainId
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5) Generate suggestions based on SEO analysis
    const suggestionsToInsert: SuggestionInsert[] = []
    const suggestionTypes: string[] = []

    // Check for missing or short title
    if (!title || title.length < 10) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'missing_or_short_title',
        title: 'Add a better page title',
        description: title
          ? `The homepage title "${title}" is very short (${title.length} chars). Consider writing a clear, descriptive title between 30-60 characters.`
          : 'The homepage is missing a title tag. Add a descriptive title to improve SEO.',
        severity: 'high',
      })
      suggestionTypes.push('missing_or_short_title')
    }

    // Check for missing meta description
    if (!metaDesc) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'missing_meta_description',
        title: 'Add a meta description',
        description: 'This page has no meta description. Add one (150-160 characters) to improve click-through rate from search results.',
        severity: 'medium',
      })
      suggestionTypes.push('missing_meta_description')
    } else if (metaDesc.length < 50) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'short_meta_description',
        title: 'Meta description is too short',
        description: `Your meta description is only ${metaDesc.length} characters. Aim for 150-160 characters for optimal display in search results.`,
        severity: 'low',
      })
      suggestionTypes.push('short_meta_description')
    }

    // Check for canonical URL issues
    if (canonical) {
      try {
        const canonicalUrl = new URL(canonical, urlToScan)
        const pageUrl = new URL(urlToScan)

        if (canonicalUrl.host !== pageUrl.host) {
          suggestionsToInsert.push({
            user_id: userId,
            domain_id: domainId,
            page_id: pageRow.id,
            suggestion_type: 'canonical_points_elsewhere',
            title: 'Canonical URL points to a different domain',
            description: `The canonical URL points to ${canonicalUrl.host}, which may cause search engines to ignore this page in favor of the canonical target.`,
            severity: 'high',
          })
          suggestionTypes.push('canonical_points_elsewhere')
        }
      } catch {
        // Invalid canonical URL
        suggestionsToInsert.push({
          user_id: userId,
          domain_id: domainId,
          page_id: pageRow.id,
          suggestion_type: 'invalid_canonical',
          title: 'Invalid canonical URL',
          description: `The canonical URL "${canonical}" appears to be malformed. Fix this to ensure proper indexing.`,
          severity: 'medium',
        })
        suggestionTypes.push('invalid_canonical')
      }
    }

    // Check for missing H1
    if (!h1) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'missing_h1',
        title: 'Add an H1 heading',
        description: 'This page has no H1 heading. Add a single, descriptive H1 tag to improve SEO structure.',
        severity: 'medium',
      })
      suggestionTypes.push('missing_h1')
    }

    // Check for noindex directive
    if (robots && robots.toLowerCase().includes('noindex')) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'noindex_set',
        title: 'Page is set to noindex',
        description: 'This page has a noindex robots directive, meaning it will not appear in search results. Remove this if you want the page indexed.',
        severity: 'high',
      })
      suggestionTypes.push('noindex_set')
    }

    // Check for HTTP error status
    if (homeStatus >= 400) {
      suggestionsToInsert.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageRow.id,
        suggestion_type: 'homepage_error_status',
        title: 'Homepage returns an error status',
        description: `The homepage responded with HTTP status ${homeStatus}. Fix this error to ensure users and search engines can access your site.`,
        severity: 'high',
      })
      suggestionTypes.push('homepage_error_status')
    }

    // 6) Clear old suggestions for these types on this page, then insert new ones
    if (suggestionTypes.length > 0) {
      // Delete old suggestions of these types for this page
      await supabaseClient
        .from('suggestions')
        .delete()
        .eq('page_id', pageRow.id)
        .in('suggestion_type', suggestionTypes)
    }

    // Also clear suggestion types we checked but didn't find issues for
    // This ensures old suggestions are removed when issues are fixed
    const allCheckedTypes = [
      'missing_or_short_title',
      'missing_meta_description',
      'short_meta_description',
      'canonical_points_elsewhere',
      'invalid_canonical',
      'missing_h1',
      'noindex_set',
      'homepage_error_status'
    ]
    const typesWithNoIssues = allCheckedTypes.filter(t => !suggestionTypes.includes(t))

    if (typesWithNoIssues.length > 0) {
      await supabaseClient
        .from('suggestions')
        .delete()
        .eq('page_id', pageRow.id)
        .in('suggestion_type', typesWithNoIssues)
    }

    // Insert new suggestions
    if (suggestionsToInsert.length > 0) {
      const { error: insertError } = await supabaseClient
        .from('suggestions')
        .insert(suggestionsToInsert)

      if (insertError) {
        console.error('Error inserting suggestions:', insertError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        domainId,
        pageId: pageRow.id,
        url: urlToScan,
        httpStatus: homeStatus,
        title,
        metaDescription: metaDesc,
        canonical,
        robots,
        h1,
        suggestionsCreated: suggestionsToInsert.length,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

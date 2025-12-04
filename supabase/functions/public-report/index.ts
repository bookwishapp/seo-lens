// supabase/functions/public-report/index.ts
// Public report endpoint - returns read-only report data for a domain via token

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DomainRow {
  id: string
  domain_name: string
  display_name: string | null
  last_scan_at: string | null
  health_score: number | null
  total_pages_scanned: number | null
  pages_missing_title: number | null
  pages_missing_meta: number | null
  pages_missing_h1: number | null
  pages_2xx: number | null
  pages_4xx: number | null
  pages_5xx: number | null
  last_uptime_checked_at: string | null
  uptime_24h_percent: number | null
  uptime_7d_percent: number | null
  last_response_time_ms: number | null
  public_report_enabled: boolean
  public_report_token: string | null
  user_id: string
}

interface ProfileRow {
  id: string
  referral_code: string | null
}

interface SitePageRow {
  id: string
  url: string
  title: string | null
  meta_description: string | null
  h1: string | null
  http_status: number | null
  last_scanned_at: string | null
}

interface SuggestionRow {
  id: string
  scope: string | null
  suggestion_type: string
  title: string
  description: string | null
  severity: string | null
  page_id: string | null
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get token from query param (GET) or body (POST)
    let token: string | null = null

    if (req.method === 'GET') {
      const url = new URL(req.url)
      token = url.searchParams.get('token')
    } else if (req.method === 'POST') {
      const body = await req.json()
      token = body.token
    }

    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Token is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !serviceRoleKey) {
      console.error('Supabase environment variables not configured')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Look up domain by token
    const { data: domain, error: domainError } = await supabase
      .from('domains')
      .select('*')
      .eq('public_report_token', token)
      .maybeSingle()

    if (domainError) {
      console.error('Error fetching domain:', domainError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch report' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!domain) {
      return new Response(
        JSON.stringify({ error: 'Report not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const domainRow = domain as DomainRow

    // Check if public report is enabled
    if (!domainRow.public_report_enabled) {
      return new Response(
        JSON.stringify({ error: 'Report not available' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fetch owner's profile for referral code
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, referral_code')
      .eq('id', domainRow.user_id)
      .maybeSingle()

    if (profileError) {
      console.error('Error fetching profile:', profileError)
    }

    const profileRow = profile as ProfileRow | null

    // Fetch site pages (limit to 50)
    const { data: pages, error: pagesError } = await supabase
      .from('site_pages')
      .select('id, url, title, meta_description, h1, http_status, last_scanned_at')
      .eq('domain_id', domainRow.id)
      .order('last_scanned_at', { ascending: false })
      .limit(50)

    if (pagesError) {
      console.error('Error fetching pages:', pagesError)
    }

    const pageRows = (pages ?? []) as SitePageRow[]

    // Fetch suggestions
    const { data: suggestions, error: suggestionsError } = await supabase
      .from('suggestions')
      .select('id, scope, suggestion_type, title, description, severity, page_id')
      .eq('domain_id', domainRow.id)
      .order('severity', { ascending: true })
      .limit(100)

    if (suggestionsError) {
      console.error('Error fetching suggestions:', suggestionsError)
    }

    const suggestionRows = (suggestions ?? []) as SuggestionRow[]

    // Create page lookup for suggestions
    const pageMap = new Map<string, SitePageRow>()
    for (const page of pageRows) {
      pageMap.set(page.id, page)
    }

    // Build response
    const response = {
      domain: {
        id: domainRow.id,
        domainName: domainRow.domain_name,
        displayName: domainRow.display_name,
        lastScannedAt: domainRow.last_scan_at,
        healthScore: domainRow.health_score,
        totalPagesScanned: domainRow.total_pages_scanned,
        pagesMissingTitle: domainRow.pages_missing_title,
        pagesMissingMeta: domainRow.pages_missing_meta,
        pagesMissingH1: domainRow.pages_missing_h1,
        pages2xx: domainRow.pages_2xx,
        pages4xx: domainRow.pages_4xx,
        pages5xx: domainRow.pages_5xx,
        uptime24hPercent: domainRow.uptime_24h_percent,
        uptime7dPercent: domainRow.uptime_7d_percent,
        lastUptimeCheckedAt: domainRow.last_uptime_checked_at,
        lastResponseTimeMs: domainRow.last_response_time_ms,
      },
      owner: {
        id: profileRow?.id ?? domainRow.user_id,
        referralCode: profileRow?.referral_code ?? null,
      },
      pages: pageRows.map(page => {
        // Extract path from URL
        let path = '/'
        try {
          const url = new URL(page.url)
          path = url.pathname || '/'
        } catch {
          // Keep default path
        }

        // Count issues for this page
        const pageIssues = suggestionRows.filter(s => s.page_id === page.id)

        return {
          id: page.id,
          url: page.url,
          path,
          title: page.title,
          statusCode: page.http_status,
          issueCount: pageIssues.length,
        }
      }),
      suggestions: suggestionRows.map(s => {
        const page = s.page_id ? pageMap.get(s.page_id) : null
        let pagePath = null
        if (page) {
          try {
            const url = new URL(page.url)
            pagePath = url.pathname || '/'
          } catch {
            pagePath = '/'
          }
        }

        return {
          id: s.id,
          scope: s.scope ?? 'page',
          type: s.suggestion_type,
          title: s.title,
          message: s.description,
          severity: s.severity,
          pageId: s.page_id,
          pagePath,
        }
      }),
    }

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Public report error:', error)
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// supabase/functions/uptime-worker/index.ts
// Supabase Edge Function for uptime monitoring
//
// This function checks the uptime of domains with uptime_enabled = true.
// It should be called via cron schedule (e.g., every 5 minutes).
//
// Cron setup in Supabase Dashboard:
// 1. Go to Database > Extensions > Enable pg_cron if not already enabled
// 2. Run SQL to create cron job:
//    SELECT cron.schedule(
//      'uptime-worker-job',
//      '*/5 * * * *',  -- Every 5 minutes
//      $$
//      SELECT net.http_post(
//        url := 'https://<project-ref>.supabase.co/functions/v1/uptime-worker',
//        headers := '{"Authorization": "Bearer <service-role-key>"}'::jsonb
//      );
//      $$
//    );
//
// Or use an external cron service (e.g., cron-job.org) to POST to this endpoint.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Timeout for HTTP requests (10 seconds)
const FETCH_TIMEOUT_MS = 10000

interface DomainRow {
  id: string
  domain_name: string
  uptime_enabled: boolean
  uptime_check_interval_minutes: number
  last_uptime_checked_at: string | null
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Allow GET for health checks
  if (req.method === 'GET') {
    return new Response(JSON.stringify({ status: 'ok', service: 'uptime-worker' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  // Main worker logic for POST
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Supabase environment variables not configured')
      return new Response('Server configuration error', { status: 500, headers: corsHeaders })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const now = new Date()

    // Load domains with uptime monitoring enabled
    const { data: domains, error: domainsError } = await supabase
      .from('domains')
      .select('id, domain_name, uptime_enabled, uptime_check_interval_minutes, last_uptime_checked_at')
      .eq('uptime_enabled', true)

    if (domainsError) {
      console.error('Error loading domains for uptime:', domainsError)
      return new Response(JSON.stringify({ error: 'Failed to load domains' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log(`Found ${domains?.length ?? 0} domains with uptime monitoring enabled`)

    let checkedCount = 0
    let skippedCount = 0

    for (const domain of (domains ?? []) as DomainRow[]) {
      // Check if it's time to check this domain
      const lastChecked = domain.last_uptime_checked_at
        ? new Date(domain.last_uptime_checked_at)
        : null
      const intervalMs = (domain.uptime_check_interval_minutes ?? 10) * 60 * 1000

      if (lastChecked && now.getTime() - lastChecked.getTime() < intervalMs) {
        // Not time yet for this domain
        skippedCount++
        continue
      }

      // Perform the uptime check
      const result = await checkDomainUptime(domain.domain_name)
      checkedCount++

      // Insert uptime_checks row
      const { error: insertError } = await supabase.from('uptime_checks').insert({
        domain_id: domain.id,
        status: result.status,
        http_status: result.httpStatus,
        response_time_ms: result.responseTimeMs,
        error_message: result.errorMessage,
      })

      if (insertError) {
        console.error(`Error inserting uptime check for ${domain.domain_name}:`, insertError)
        continue
      }

      // Calculate uptime percentages
      const { uptime24h, uptime7d } = await calculateUptimePercentages(
        supabase,
        domain.id,
        now
      )

      // Update domain summary fields
      const { error: updateError } = await supabase
        .from('domains')
        .update({
          last_uptime_status: result.status,
          last_uptime_checked_at: now.toISOString(),
          last_response_time_ms: result.responseTimeMs,
          uptime_24h_percent: uptime24h,
          uptime_7d_percent: uptime7d,
        })
        .eq('id', domain.id)

      if (updateError) {
        console.error(`Error updating domain uptime summary for ${domain.domain_name}:`, updateError)
      } else {
        console.log(
          `Checked ${domain.domain_name}: ${result.status} (${result.responseTimeMs ?? 'N/A'}ms)`
        )
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        checked: checkedCount,
        skipped: skippedCount,
        total: domains?.length ?? 0,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Uptime worker error:', error)
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

interface UptimeCheckResult {
  status: 'up' | 'down'
  httpStatus: number | null
  responseTimeMs: number | null
  errorMessage: string | null
}

async function checkDomainUptime(domainName: string): Promise<UptimeCheckResult> {
  const url = `https://${domainName}`
  let status: 'up' | 'down' = 'down'
  let httpStatus: number | null = null
  let responseTimeMs: number | null = null
  let errorMessage: string | null = null

  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS)

    const start = performance.now()
    const resp = await fetch(url, {
      method: 'GET',
      signal: controller.signal,
      redirect: 'follow',
      headers: {
        'User-Agent': 'SEOLens-UptimeMonitor/1.0',
      },
    })
    const end = performance.now()

    clearTimeout(timeoutId)

    httpStatus = resp.status
    responseTimeMs = Math.round(end - start)
    // Consider 2xx and 3xx as "up"
    status = resp.status >= 200 && resp.status < 400 ? 'up' : 'down'
  } catch (e) {
    if (e instanceof Error) {
      if (e.name === 'AbortError') {
        errorMessage = 'Request timeout'
      } else {
        errorMessage = e.message
      }
    } else {
      errorMessage = String(e)
    }
    status = 'down'
  }

  return { status, httpStatus, responseTimeMs, errorMessage }
}

async function calculateUptimePercentages(
  supabase: ReturnType<typeof createClient>,
  domainId: string,
  now: Date
): Promise<{ uptime24h: number; uptime7d: number }> {
  // Get checks from last 7 days
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)

  const { data: checks, error } = await supabase
    .from('uptime_checks')
    .select('status, checked_at')
    .eq('domain_id', domainId)
    .gte('checked_at', sevenDaysAgo.toISOString())
    .order('checked_at', { ascending: false })

  if (error || !checks || checks.length === 0) {
    // No data, assume 100%
    return { uptime24h: 100, uptime7d: 100 }
  }

  const nowMs = now.getTime()
  const oneDayAgo = nowMs - 24 * 60 * 60 * 1000

  const checks24h = checks.filter(
    (c) => new Date(c.checked_at).getTime() >= oneDayAgo
  )

  const calcPercent = (arr: Array<{ status: string }>): number => {
    if (arr.length === 0) return 100
    const upCount = arr.filter((c) => c.status === 'up').length
    return Math.round((upCount / arr.length) * 10000) / 100 // 2 decimal places
  }

  return {
    uptime24h: calcPercent(checks24h),
    uptime7d: calcPercent(checks),
  }
}

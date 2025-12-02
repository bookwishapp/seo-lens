// Supabase Edge Function to crawl domain pages and generate SEO suggestions

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import { DOMParser, Element } from 'https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts'

interface ScanRequest {
  domainId: string
  maxPages?: number
}

interface PageData {
  url: string
  httpStatus: number
  title: string | null
  metaDescription: string | null
  canonical: string | null
  robots: string | null
  h1: string | null
  internalLinks: string[]
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

// Parse a page and extract SEO data + internal links
async function parsePage(url: string, baseOrigin: string): Promise<PageData | null> {
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'User-Agent': 'SEOLens/1.0 (Page Scanner)',
        'Accept': 'text/html,application/xhtml+xml',
      },
      redirect: 'follow',
    })

    const html = await response.text()
    const doc = new DOMParser().parseFromString(html, 'text/html')

    if (!doc) return null

    const title = doc.querySelector('title')?.textContent?.trim() ?? null
    const metaDescription = doc.querySelector('meta[name="description"]')?.getAttribute('content')?.trim() ?? null
    const canonical = doc.querySelector('link[rel="canonical"]')?.getAttribute('href')?.trim() ?? null
    const robots = doc.querySelector('meta[name="robots"]')?.getAttribute('content')?.trim() ?? null
    const h1 = doc.querySelector('h1')?.textContent?.trim() ?? null

    // Extract internal links
    const internalLinks: string[] = []
    const anchors = doc.querySelectorAll('a[href]')

    for (let i = 0; i < anchors.length; i++) {
      const anchor = anchors[i] as Element
      const href = anchor.getAttribute('href')
      if (!href) continue

      try {
        const linkUrl = new URL(href, url)

        // Only same-origin links
        if (linkUrl.origin !== baseOrigin) continue

        // Skip anchors, javascript, mailto, tel
        if (linkUrl.href.includes('#') ||
            href.startsWith('javascript:') ||
            href.startsWith('mailto:') ||
            href.startsWith('tel:')) continue

        // Skip common non-page extensions
        const path = linkUrl.pathname.toLowerCase()
        if (path.match(/\.(jpg|jpeg|png|gif|svg|webp|pdf|zip|css|js|ico|woff|woff2|ttf|eot)$/)) continue

        // Normalize URL (remove trailing slash, fragment)
        linkUrl.hash = ''
        let normalizedUrl = linkUrl.href
        if (normalizedUrl.endsWith('/') && normalizedUrl !== baseOrigin + '/') {
          normalizedUrl = normalizedUrl.slice(0, -1)
        }

        if (!internalLinks.includes(normalizedUrl)) {
          internalLinks.push(normalizedUrl)
        }
      } catch {
        // Invalid URL, skip
      }
    }

    return {
      url,
      httpStatus: response.status,
      title,
      metaDescription,
      canonical,
      robots,
      h1,
      internalLinks,
    }
  } catch (error) {
    console.error(`Failed to parse ${url}:`, error)
    return null
  }
}

// Generate suggestions for a page
function generateSuggestions(
  pageData: PageData,
  pageId: string,
  userId: string,
  domainId: string,
  baseOrigin: string
): SuggestionInsert[] {
  const suggestions: SuggestionInsert[] = []

  // Check for missing or short title
  if (!pageData.title || pageData.title.length < 10) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'missing_or_short_title',
      title: 'Add a better page title',
      description: pageData.title
        ? `The title "${pageData.title}" is very short (${pageData.title.length} chars). Aim for 30-60 characters.`
        : 'This page is missing a title tag. Add a descriptive title to improve SEO.',
      severity: 'high',
    })
  } else if (pageData.title.length > 60) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'title_too_long',
      title: 'Title tag is too long',
      description: `The title is ${pageData.title.length} characters. Search engines typically display 50-60 characters.`,
      severity: 'low',
    })
  }

  // Check for missing meta description
  if (!pageData.metaDescription) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'missing_meta_description',
      title: 'Add a meta description',
      description: 'This page has no meta description. Add one (150-160 characters) to improve click-through rate.',
      severity: 'medium',
    })
  } else if (pageData.metaDescription.length < 50) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'short_meta_description',
      title: 'Meta description is too short',
      description: `Your meta description is only ${pageData.metaDescription.length} characters. Aim for 150-160 characters.`,
      severity: 'low',
    })
  } else if (pageData.metaDescription.length > 160) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'long_meta_description',
      title: 'Meta description is too long',
      description: `Your meta description is ${pageData.metaDescription.length} characters. It may be truncated in search results.`,
      severity: 'low',
    })
  }

  // Check for canonical URL issues
  if (pageData.canonical) {
    try {
      const canonicalUrl = new URL(pageData.canonical, pageData.url)
      const pageUrl = new URL(pageData.url)

      if (canonicalUrl.origin !== pageUrl.origin) {
        suggestions.push({
          user_id: userId,
          domain_id: domainId,
          page_id: pageId,
          suggestion_type: 'canonical_points_elsewhere',
          title: 'Canonical URL points to different domain',
          description: `The canonical URL points to ${canonicalUrl.host}. Search engines may ignore this page.`,
          severity: 'high',
        })
      }
    } catch {
      suggestions.push({
        user_id: userId,
        domain_id: domainId,
        page_id: pageId,
        suggestion_type: 'invalid_canonical',
        title: 'Invalid canonical URL',
        description: `The canonical URL "${pageData.canonical}" is malformed.`,
        severity: 'medium',
      })
    }
  }

  // Check for missing H1
  if (!pageData.h1) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'missing_h1',
      title: 'Add an H1 heading',
      description: 'This page has no H1 heading. Add one to improve SEO structure.',
      severity: 'medium',
    })
  }

  // Check for noindex directive
  if (pageData.robots && pageData.robots.toLowerCase().includes('noindex')) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'noindex_set',
      title: 'Page is set to noindex',
      description: 'This page will not appear in search results. Remove noindex if you want it indexed.',
      severity: 'high',
    })
  }

  // Check for HTTP error status
  if (pageData.httpStatus >= 400) {
    suggestions.push({
      user_id: userId,
      domain_id: domainId,
      page_id: pageId,
      suggestion_type: 'page_error_status',
      title: `Page returns ${pageData.httpStatus} error`,
      description: `This page responded with HTTP ${pageData.httpStatus}. Fix the error to ensure accessibility.`,
      severity: 'high',
    })
  }

  return suggestions
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { domainId, maxPages = 50 }: ScanRequest = await req.json()

    if (!domainId) {
      return new Response(
        JSON.stringify({ error: 'domainId is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Load domain
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

    // Get domain status for final_url
    const { data: statusRow } = await supabaseClient
      .from('domain_status')
      .select('final_url')
      .eq('domain_id', domainId)
      .maybeSingle()

    let startUrl = statusRow?.final_url
    if (!startUrl) {
      startUrl = domainRow.domain_name
      if (!startUrl.startsWith('http://') && !startUrl.startsWith('https://')) {
        startUrl = `https://${startUrl}`
      }
    }

    const baseOrigin = new URL(startUrl).origin
    const userId = domainRow.user_id

    // Crawl pages
    const scannedUrls = new Set<string>()
    const urlQueue: string[] = [startUrl]
    const allPageData: { pageData: PageData; pageId: string }[] = []
    const allSuggestions: SuggestionInsert[] = []
    let pagesScanned = 0

    console.log(`Starting crawl of ${baseOrigin}, max ${maxPages} pages`)

    while (urlQueue.length > 0 && pagesScanned < maxPages) {
      const url = urlQueue.shift()!

      // Normalize URL for deduplication
      let normalizedUrl = url
      if (normalizedUrl.endsWith('/') && normalizedUrl !== baseOrigin + '/') {
        normalizedUrl = normalizedUrl.slice(0, -1)
      }

      if (scannedUrls.has(normalizedUrl)) continue
      scannedUrls.add(normalizedUrl)

      console.log(`Scanning page ${pagesScanned + 1}/${maxPages}: ${normalizedUrl}`)

      const pageData = await parsePage(normalizedUrl, baseOrigin)
      if (!pageData) continue

      pagesScanned++

      // Upsert page into database
      const { data: pageRow, error: upsertError } = await supabaseClient
        .from('site_pages')
        .upsert({
          user_id: userId,
          domain_id: domainId,
          url: normalizedUrl,
          http_status: pageData.httpStatus,
          title: pageData.title,
          meta_description: pageData.metaDescription,
          canonical_url: pageData.canonical,
          robots_directive: pageData.robots,
          h1: pageData.h1,
          last_scanned_at: new Date().toISOString(),
        }, {
          onConflict: 'domain_id,url'
        })
        .select()
        .maybeSingle()

      if (upsertError || !pageRow) {
        console.error(`Failed to upsert page ${normalizedUrl}:`, upsertError)
        continue
      }

      allPageData.push({ pageData, pageId: pageRow.id })

      // Generate suggestions for this page
      const pageSuggestions = generateSuggestions(pageData, pageRow.id, userId, domainId, baseOrigin)
      allSuggestions.push(...pageSuggestions)

      // Add new internal links to queue
      for (const link of pageData.internalLinks) {
        let normalizedLink = link
        if (normalizedLink.endsWith('/') && normalizedLink !== baseOrigin + '/') {
          normalizedLink = normalizedLink.slice(0, -1)
        }
        if (!scannedUrls.has(normalizedLink) && !urlQueue.includes(normalizedLink)) {
          urlQueue.push(normalizedLink)
        }
      }
    }

    // Clear old suggestions for scanned pages and insert new ones
    const scannedPageIds = allPageData.map(p => p.pageId)

    if (scannedPageIds.length > 0) {
      // Delete old suggestions for these pages
      await supabaseClient
        .from('suggestions')
        .delete()
        .in('page_id', scannedPageIds)

      // Insert new suggestions
      if (allSuggestions.length > 0) {
        const { error: insertError } = await supabaseClient
          .from('suggestions')
          .insert(allSuggestions)

        if (insertError) {
          console.error('Error inserting suggestions:', insertError)
        }
      }
    }

    console.log(`Crawl complete: ${pagesScanned} pages, ${allSuggestions.length} suggestions`)

    return new Response(
      JSON.stringify({
        success: true,
        domainId,
        pagesScanned,
        suggestionsCreated: allSuggestions.length,
        urlsFound: scannedUrls.size + urlQueue.length,
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

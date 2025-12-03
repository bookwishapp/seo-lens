// Supabase Edge Function to fetch WHOIS/RDAP data for a domain
// Uses the RDAP protocol to get registrar and expiration information

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

interface WhoisRequest {
  domain_id: string
}

interface WhoisResponse {
  domain_id: string
  domain_name: string
  expiry_date: string | null
  registrar_name: string | null
  source: string
  status: 'ok' | 'partial' | 'not_found' | 'error'
  message?: string
}

interface RdapEvent {
  eventAction: string
  eventDate: string
}

interface RdapEntity {
  roles?: string[]
  vcardArray?: unknown[]
  handle?: string
  publicIds?: Array<{ type: string; identifier: string }>
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
    const { domain_id }: WhoisRequest = await req.json()

    if (!domain_id) {
      return new Response(
        JSON.stringify({ error: 'domain_id is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Look up the domain
    const { data: domain, error: domainError } = await supabaseClient
      .from('domains')
      .select('id, domain_name')
      .eq('id', domain_id)
      .single()

    if (domainError || !domain) {
      return new Response(
        JSON.stringify({
          domain_id,
          domain_name: null,
          expiry_date: null,
          registrar_name: null,
          source: 'rdap',
          status: 'error',
          message: 'Domain not found'
        } as WhoisResponse),
        { status: 404, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    // Extract the root domain (remove www. and protocol if present)
    let domainName = domain.domain_name.toLowerCase()
    domainName = domainName.replace(/^(https?:\/\/)?(www\.)?/, '')
    domainName = domainName.split('/')[0] // Remove any path

    // Fetch RDAP data
    let expiryDate: string | null = null
    let registrarName: string | null = null
    let status: 'ok' | 'partial' | 'not_found' | 'error' = 'not_found'

    try {
      // Use rdap-bootstrap.arin.net which reliably routes to the appropriate RDAP server
      const rdapUrl = `https://rdap-bootstrap.arin.net/bootstrap/domain/${domainName}`

      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 15000) // 15 second timeout

      const rdapResponse = await fetch(rdapUrl, {
        method: 'GET',
        headers: {
          'Accept': 'application/rdap+json, application/json',
          'User-Agent': 'SEOLens/1.0 (WHOIS Lookup)',
        },
        signal: controller.signal,
      })

      clearTimeout(timeoutId)

      if (!rdapResponse.ok) {
        throw new Error(`RDAP request failed with status ${rdapResponse.status}: ${rdapResponse.statusText}`)
      }

      const rdapData = await rdapResponse.json()

      // Extract expiration date from events
      if (rdapData.events && Array.isArray(rdapData.events)) {
        for (const event of rdapData.events as RdapEvent[]) {
          if (event.eventAction === 'expiration' || event.eventAction === 'registration expiration') {
            try {
              const date = new Date(event.eventDate)
              if (!isNaN(date.getTime())) {
                expiryDate = date.toISOString().split('T')[0] // YYYY-MM-DD format
              }
            } catch {
              // Continue if date parsing fails
            }
          }
        }
      }

      // Extract registrar name from entities
      if (rdapData.entities && Array.isArray(rdapData.entities)) {
        for (const entity of rdapData.entities as RdapEntity[]) {
          if (entity.roles?.includes('registrar')) {
            // Try to get name from vcardArray
            if (entity.vcardArray && Array.isArray(entity.vcardArray) && entity.vcardArray.length > 1) {
              const vcard = entity.vcardArray[1]
              if (Array.isArray(vcard)) {
                for (const field of vcard) {
                  if (Array.isArray(field) && field[0] === 'fn' && field[3]) {
                    registrarName = String(field[3])
                    break
                  }
                }
              }
            }

            // Fallback to handle if no name found
            if (!registrarName && entity.handle) {
              registrarName = entity.handle
            }

            // Try publicIds for IANA ID
            if (!registrarName && entity.publicIds) {
              for (const pubId of entity.publicIds) {
                if (pubId.type === 'IANA Registrar ID') {
                  registrarName = `Registrar #${pubId.identifier}`
                }
              }
            }

            break
          }
        }
      }

      // Determine status
      if (expiryDate && registrarName) {
        status = 'ok'
      } else if (expiryDate || registrarName) {
        status = 'partial'
      } else {
        status = 'not_found'
      }

    } catch (rdapError) {
      console.error('RDAP fetch error:', rdapError)
      status = 'error'

      // Return error response but don't update database
      return new Response(
        JSON.stringify({
          domain_id,
          domain_name: domainName,
          expiry_date: null,
          registrar_name: null,
          source: 'rdap',
          status: 'error',
          message: rdapError instanceof Error ? rdapError.message : 'RDAP lookup failed'
        } as WhoisResponse),
        {
          status: 200, // Return 200 so client can handle gracefully
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }

    // Update domain with found data (only update non-null values)
    const updateData: Record<string, unknown> = {}
    if (expiryDate) {
      updateData.expiry_date = expiryDate
    }
    if (registrarName) {
      updateData.registrar_name = registrarName
    }

    if (Object.keys(updateData).length > 0) {
      const { error: updateError } = await supabaseClient
        .from('domains')
        .update(updateData)
        .eq('id', domain_id)

      if (updateError) {
        console.error('Database update error:', updateError)
        return new Response(
          JSON.stringify({
            domain_id,
            domain_name: domainName,
            expiry_date: expiryDate,
            registrar_name: registrarName,
            source: 'rdap',
            status: 'error',
            message: 'Failed to save WHOIS data'
          } as WhoisResponse),
          { status: 500, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
        )
      }
    }

    // Return success response
    return new Response(
      JSON.stringify({
        domain_id,
        domain_name: domainName,
        expiry_date: expiryDate,
        registrar_name: registrarName,
        source: 'rdap',
        status
      } as WhoisResponse),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      }
    )

  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error',
        status: 'error'
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      }
    )
  }
})

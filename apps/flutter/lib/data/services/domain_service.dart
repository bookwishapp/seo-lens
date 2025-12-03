import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/domain.dart';
import '../models/domain_status.dart';
import '../models/site_page.dart';

class DomainService {
  final SupabaseClient _client = supabase;

  /// Get all domains for the current user
  Future<List<Domain>> getDomains() async {
    final response = await _client
        .from('domains')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => Domain.fromJson(json)).toList();
  }

  /// Get a single domain by ID
  Future<Domain?> getDomain(String domainId) async {
    final response = await _client
        .from('domains')
        .select()
        .eq('id', domainId)
        .maybeSingle();

    if (response == null) return null;
    return Domain.fromJson(response);
  }

  /// Add a new domain
  Future<Domain> addDomain({
    required String userId,
    required String domainName,
    String? label,
    String? projectTag,
    String? registrarName,
    DateTime? expiryDate,
  }) async {
    final response = await _client
        .from('domains')
        .insert({
          'user_id': userId,
          'domain_name': domainName,
          if (label != null) 'label': label,
          if (projectTag != null) 'project_tag': projectTag,
          if (registrarName != null) 'registrar_name': registrarName,
          if (expiryDate != null)
            'expiry_date': expiryDate.toIso8601String().split('T')[0],
        })
        .select()
        .single();

    return Domain.fromJson(response);
  }

  /// Add multiple domains at once
  Future<List<Domain>> addDomains({
    required String userId,
    required List<String> domainNames,
    String? projectTag,
  }) async {
    final inserts = domainNames.map((name) => {
          'user_id': userId,
          'domain_name': name.trim().toLowerCase(),
          if (projectTag != null) 'project_tag': projectTag,
        }).toList();

    final response = await _client.from('domains').insert(inserts).select();

    return (response as List).map((json) => Domain.fromJson(json)).toList();
  }

  /// Update a domain
  Future<Domain> updateDomain({
    required String domainId,
    String? label,
    String? projectTag,
    String? registrarName,
    DateTime? expiryDate,
    String? notes,
    String? preferredUrl,
    String? preferredRedirectProvider,
  }) async {
    final updateData = <String, dynamic>{};
    if (label != null) updateData['label'] = label;
    if (projectTag != null) updateData['project_tag'] = projectTag;
    if (registrarName != null) updateData['registrar_name'] = registrarName;
    if (expiryDate != null) {
      updateData['expiry_date'] = expiryDate.toIso8601String().split('T')[0];
    }
    if (notes != null) updateData['notes'] = notes;
    if (preferredUrl != null) updateData['preferred_url'] = preferredUrl;
    if (preferredRedirectProvider != null) {
      updateData['preferred_redirect_provider'] = preferredRedirectProvider;
    }

    final response = await _client
        .from('domains')
        .update(updateData)
        .eq('id', domainId)
        .select()
        .single();

    return Domain.fromJson(response);
  }

  /// Update redirect preferences for a domain
  Future<Domain> updateRedirectPreferences({
    required String domainId,
    required String? preferredUrl,
    required String? preferredRedirectProvider,
  }) async {
    final response = await _client
        .from('domains')
        .update({
          'preferred_url': preferredUrl,
          'preferred_redirect_provider': preferredRedirectProvider,
        })
        .eq('id', domainId)
        .select()
        .single();

    return Domain.fromJson(response);
  }

  /// Update domain info (registrar and expiry) manually
  Future<Domain> updateDomainInfo({
    required String domainId,
    String? registrarName,
    DateTime? expiryDate,
  }) async {
    final updateData = <String, dynamic>{};
    if (registrarName != null) updateData['registrar_name'] = registrarName;
    if (expiryDate != null) {
      updateData['expiry_date'] = expiryDate.toIso8601String().split('T')[0];
    }

    final response = await _client
        .from('domains')
        .update(updateData)
        .eq('id', domainId)
        .select()
        .single();

    return Domain.fromJson(response);
  }

  /// Fetch WHOIS data for a domain via Edge Function
  Future<WhoisResult> fetchWhoisData(String domainId) async {
    try {
      final response = await _client.functions.invoke(
        'fetch-domain-whois',
        body: {'domain_id': domainId},
      );

      if (response.status != 200) {
        return WhoisResult(
          success: false,
          message: 'WHOIS lookup failed',
        );
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String?;

      // All status codes except 'error' are considered success
      // because they represent valid responses (ok, partial, not_found)
      final isSuccess = status != 'error';

      return WhoisResult(
        success: isSuccess,
        expiryDate: data['expiry_date'] != null
            ? DateTime.parse(data['expiry_date'] as String)
            : null,
        registrarName: data['registrar_name'] as String?,
        status: status,
        message: data['message'] as String? ?? 'WHOIS lookup complete',
      );
    } catch (e) {
      return WhoisResult(
        success: false,
        message: 'Failed to fetch WHOIS data: $e',
      );
    }
  }

  /// Delete a domain
  Future<void> deleteDomain(String domainId) async {
    await _client.from('domains').delete().eq('id', domainId);
  }

  /// Get domain status
  Future<DomainStatus?> getDomainStatus(String domainId) async {
    final response = await _client
        .from('domain_status')
        .select()
        .eq('domain_id', domainId)
        .maybeSingle();

    if (response == null) return null;
    return DomainStatus.fromJson(response);
  }

  /// Update or insert domain status
  Future<DomainStatus> upsertDomainStatus({
    required String domainId,
    String? resolvedIp,
    String? finalUrl,
    int? finalStatusCode,
    List<RedirectHop>? redirectChain,
  }) async {
    final data = {
      'domain_id': domainId,
      if (resolvedIp != null) 'resolved_ip': resolvedIp,
      if (finalUrl != null) 'final_url': finalUrl,
      if (finalStatusCode != null) 'final_status_code': finalStatusCode,
      if (redirectChain != null)
        'redirect_chain': redirectChain.map((hop) => hop.toJson()).toList(),
      'last_checked_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('domain_status')
        .upsert(data)
        .select()
        .single();

    return DomainStatus.fromJson(response);
  }

  /// Get site pages for a domain
  Future<List<SitePage>> getSitePages(String domainId) async {
    final response = await _client
        .from('site_pages')
        .select()
        .eq('domain_id', domainId)
        .order('first_seen_at', ascending: false);

    return (response as List).map((json) => SitePage.fromJson(json)).toList();
  }

  /// Add or update a site page
  Future<SitePage> upsertSitePage({
    required String domainId,
    required String url,
    int? httpStatus,
    String? title,
    String? metaDescription,
    String? canonicalUrl,
    String? robotsDirective,
    String? h1,
    String? contentHash,
  }) async {
    final data = {
      'domain_id': domainId,
      'url': url,
      if (httpStatus != null) 'http_status': httpStatus,
      if (title != null) 'title': title,
      if (metaDescription != null) 'meta_description': metaDescription,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (robotsDirective != null) 'robots_directive': robotsDirective,
      if (h1 != null) 'h1': h1,
      if (contentHash != null) 'content_hash': contentHash,
      'last_scanned_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('site_pages')
        .upsert(data)
        .select()
        .single();

    return SitePage.fromJson(response);
  }

  /// Get domain stats summary
  Future<Map<String, int>> getDomainStats(String userId) async {
    // Get all domains
    final domains = await getDomains();

    // Get all statuses
    final statusResponse =
        await _client.from('domain_status').select('final_status_code');

    int liveCount = 0;
    int redirectCount = 0;
    int brokenCount = 0;

    for (var status in statusResponse as List) {
      final code = status['final_status_code'] as int?;
      if (code == null) continue;

      if (code >= 200 && code < 300) {
        liveCount++;
      } else if (code >= 300 && code < 400) {
        redirectCount++;
      } else if (code >= 400) {
        brokenCount++;
      }
    }

    return {
      'total': domains.length,
      'live': liveCount,
      'redirect': redirectCount,
      'broken': brokenCount,
      'unknown': domains.length - (liveCount + redirectCount + brokenCount),
    };
  }
}

/// Result of a WHOIS lookup
class WhoisResult {
  final bool success;
  final DateTime? expiryDate;
  final String? registrarName;
  final String? status;
  final String? message;

  WhoisResult({
    required this.success,
    this.expiryDate,
    this.registrarName,
    this.status,
    this.message,
  });
}

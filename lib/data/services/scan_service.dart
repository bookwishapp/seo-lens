import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/domain_status.dart';
import '../models/site_page.dart';

/// Service for scanning domains via Supabase Edge Functions
///
/// Uses server-side Edge Functions to avoid CORS restrictions.
class ScanService {
  final SupabaseClient _client = supabase;

  /// Scan a single domain's status (redirects, final URL, status code)
  ///
  /// Calls a Supabase Edge Function to scan the domain server-side,
  /// avoiding CORS restrictions that would block client-side scanning.
  Future<DomainStatus> scanDomain({
    required String domainId,
    required String domainName,
  }) async {
    try {
      // Call the Edge Function
      final response = await _client.functions.invoke(
        'scan-domain',
        body: {
          'domainId': domainId,
          'domainName': domainName,
        },
      );

      if (response.data == null) {
        throw Exception('No response from scan function');
      }

      // Get the updated status from database
      final statusResponse = await _client
          .from('domain_status')
          .select()
          .eq('domain_id', domainId)
          .single();

      return DomainStatus.fromJson(statusResponse);
    } catch (e) {
      print('Scan failed for $domainName: $e');
      rethrow;
    }
  }

  /// Scan domain pages for SEO data and generate suggestions
  ///
  /// Fetches the homepage, parses SEO elements (title, meta, h1, etc.),
  /// saves to site_pages, and creates suggestions based on SEO rules.
  Future<SitePage?> scanDomainPages({
    required String domainId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'scan-domain-pages',
        body: {
          'domainId': domainId,
        },
      );

      if (response.data == null) {
        throw Exception('No response from scan pages function');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      // Fetch the updated page from database
      final pageId = data['pageId'] as String?;
      if (pageId != null) {
        final pageResponse = await _client
            .from('site_pages')
            .select()
            .eq('id', pageId)
            .maybeSingle();

        if (pageResponse != null) {
          return SitePage.fromJson(pageResponse);
        }
      }

      return null;
    } catch (e) {
      print('Page scan failed for domain $domainId: $e');
      rethrow;
    }
  }

  /// Full domain scan - status + pages + suggestions
  ///
  /// Runs both the domain status scan and page scan sequentially.
  Future<({DomainStatus status, SitePage? page})> fullScan({
    required String domainId,
    required String domainName,
  }) async {
    // First scan domain status (redirects, final URL)
    final status = await scanDomain(
      domainId: domainId,
      domainName: domainName,
    );

    // Then scan pages for SEO data
    SitePage? page;
    try {
      page = await scanDomainPages(domainId: domainId);
    } catch (e) {
      // Log but don't fail - domain status is still valuable
      print('Page scan failed, continuing: $e');
    }

    return (status: status, page: page);
  }

  /// Scan multiple domains
  Future<List<DomainStatus>> scanDomains(
      List<({String id, String name})> domains) async {
    final results = <DomainStatus>[];

    for (var domain in domains) {
      try {
        final status = await scanDomain(
          domainId: domain.id,
          domainName: domain.name,
        );
        results.add(status);
      } catch (e) {
        // Continue scanning other domains even if one fails
        print('Failed to scan ${domain.name}: $e');
      }
    }

    return results;
  }
}

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
  /// Crawls pages starting from homepage, parses SEO elements,
  /// saves to site_pages, and creates suggestions based on SEO rules.
  ///
  /// [maxPages] controls how many pages to crawl (default 50)
  Future<({int pagesScanned, int suggestionsCreated})?> scanDomainPages({
    required String domainId,
    int maxPages = 50,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'scan-domain-pages',
        body: {
          'domainId': domainId,
          'maxPages': maxPages,
        },
      );

      if (response.data == null) {
        throw Exception('No response from scan pages function');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      return (
        pagesScanned: data['pagesScanned'] as int? ?? 0,
        suggestionsCreated: data['suggestionsCreated'] as int? ?? 0,
      );
    } catch (e) {
      print('Page scan failed for domain $domainId: $e');
      rethrow;
    }
  }

  /// Full domain scan - status + pages + suggestions
  ///
  /// Runs both the domain status scan and page crawl sequentially.
  ///
  /// [maxPages] controls how many pages to crawl (default 50)
  Future<({DomainStatus status, int pagesScanned, int suggestionsCreated})> fullScan({
    required String domainId,
    required String domainName,
    int maxPages = 50,
  }) async {
    // First scan domain status (redirects, final URL)
    final status = await scanDomain(
      domainId: domainId,
      domainName: domainName,
    );

    // Then crawl pages for SEO data
    int pagesScanned = 0;
    int suggestionsCreated = 0;
    try {
      final result = await scanDomainPages(domainId: domainId, maxPages: maxPages);
      if (result != null) {
        pagesScanned = result.pagesScanned;
        suggestionsCreated = result.suggestionsCreated;
      }
    } catch (e) {
      // Log but don't fail - domain status is still valuable
      print('Page scan failed, continuing: $e');
    }

    return (status: status, pagesScanned: pagesScanned, suggestionsCreated: suggestionsCreated);
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

import 'package:http/http.dart' as http;
import '../models/domain_status.dart';
import 'domain_service.dart';

/// Service for scanning domains
///
/// TODO: This is a simplified v1 implementation that runs directly from the Flutter app.
/// For production, move scanning to a background worker (Railway, etc.) that:
/// - Handles DNS lookups properly
/// - Follows redirect chains completely
/// - Crawls pages and extracts meta tags
/// - Processes robots.txt
/// - Runs on a schedule
///
/// For now, this provides basic HTTP checks to populate the database with initial data.
class ScanService {
  final DomainService _domainService = DomainService();

  /// Scan a single domain
  ///
  /// Makes an HTTP request to the domain and captures:
  /// - Final URL after redirects
  /// - HTTP status code
  /// - Basic redirect chain info
  Future<DomainStatus> scanDomain({
    required String domainId,
    required String domainName,
  }) async {
    try {
      // Ensure domain has protocol
      String url = domainName;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Track redirects manually
      final redirectChain = <RedirectHop>[];
      http.Response? response;
      String currentUrl = url;
      int maxRedirects = 10;
      int redirectCount = 0;

      // Follow redirects manually to build chain
      final client = http.Client();
      try {
        while (redirectCount < maxRedirects) {
          final request = http.Request('GET', Uri.parse(currentUrl));
          final streamedResponse = await client.send(request);
          response = await http.Response.fromStream(streamedResponse);

          // Add to redirect chain
          redirectChain.add(RedirectHop(
            url: currentUrl,
            statusCode: response.statusCode,
          ));

          // Check if this is a redirect
          if (response.statusCode >= 300 && response.statusCode < 400) {
            final location = response.headers['location'];
            if (location == null || location.isEmpty) {
              break;
            }

            // Handle relative redirects
            final uri = Uri.parse(currentUrl);
            currentUrl = uri.resolve(location).toString();
            redirectCount++;
          } else {
            // Not a redirect, we're done
            break;
          }
        }
      } finally {
        client.close();
      }

      if (response == null) {
        throw Exception('No response received');
      }

      // Update domain status in database
      final domainStatus = await _domainService.upsertDomainStatus(
        domainId: domainId,
        finalUrl: currentUrl,
        finalStatusCode: response.statusCode,
        redirectChain: redirectChain,
      );

      // TODO: Extract and store page meta information (title, description, etc.)
      // This would require parsing HTML and extracting meta tags
      // For now, we just store the basic status info

      return domainStatus;
    } catch (e) {
      // If scan fails, still update the status to indicate we tried
      final domainStatus = await _domainService.upsertDomainStatus(
        domainId: domainId,
        finalUrl: null,
        finalStatusCode: null,
        redirectChain: null,
      );

      rethrow;
    }
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

  /// Extract page metadata (for future use)
  ///
  /// TODO: Implement HTML parsing to extract:
  /// - <title>
  /// - <meta name="description">
  /// - <meta name="robots">
  /// - <link rel="canonical">
  /// - <h1>
  ///
  /// This would use a package like html (https://pub.dev/packages/html) to parse the response body.
  Future<Map<String, String?>> extractPageMeta(String html) async {
    // Placeholder for future implementation
    return {
      'title': null,
      'description': null,
      'robots': null,
      'canonical': null,
      'h1': null,
    };
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/domain_status.dart';

/// Service for scanning domains via Supabase Edge Function
///
/// Uses a server-side Edge Function to avoid CORS restrictions.
class ScanService {
  final SupabaseClient _client = supabase;

  /// Scan a single domain via Edge Function
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

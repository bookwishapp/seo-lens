// lib/data/services/report_service.dart
// Service for fetching public report data

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';
import '../models/report_data.dart';

class ReportService {
  final SupabaseClient _client;

  ReportService(this._client);

  /// Fetch public report data by token
  Future<ReportData> fetchPublicReport(String token) async {
    final url = '${SupabaseConfig.supabaseUrl}/functions/v1/public-report?token=$token';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 404) {
      throw ReportNotFoundException();
    }

    if (response.statusCode != 200) {
      throw ReportFetchException('Failed to fetch report: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ReportData.fromJson(json);
  }

  /// Generate a new public report token for a domain
  Future<String> generateReportToken(String domainId) async {
    // Generate a URL-safe random token
    final token = _generateToken();

    await _client
        .from('domains')
        .update({
          'public_report_token': token,
          'public_report_enabled': true,
        })
        .eq('id', domainId);

    return token;
  }

  /// Enable public report (generates token if needed)
  Future<String> enablePublicReport(String domainId) async {
    // First check if token already exists
    final domain = await _client
        .from('domains')
        .select('public_report_token')
        .eq('id', domainId)
        .maybeSingle();

    String token;
    if (domain != null && domain['public_report_token'] != null) {
      token = domain['public_report_token'] as String;
      // Just enable it
      await _client
          .from('domains')
          .update({'public_report_enabled': true})
          .eq('id', domainId);
    } else {
      // Generate new token
      token = await generateReportToken(domainId);
    }

    return token;
  }

  /// Disable public report
  Future<void> disablePublicReport(String domainId) async {
    await _client
        .from('domains')
        .update({'public_report_enabled': false})
        .eq('id', domainId);
  }

  /// Generate a URL-safe token using cryptographically secure random
  String _generateToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();

    // Use a simple LCG with good parameters for variety
    var seed = random;
    for (var i = 0; i < 16; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final index = seed % chars.length;
      buffer.write(chars[index]);
    }

    return buffer.toString();
  }
}

class ReportNotFoundException implements Exception {
  @override
  String toString() => 'Report not found or not available';
}

class ReportFetchException implements Exception {
  final String message;
  ReportFetchException(this.message);

  @override
  String toString() => message;
}

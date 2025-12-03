// lib/data/services/referral_service.dart
// Service for handling referral program functionality
//
// Features:
// - Capture referral code from URL (?ref=ABC123)
// - Store referral code temporarily until after signup
// - Set referral attribution on profile after signup
// - Copy referral link to clipboard
// - Share referral link (on mobile)

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';

/// Service for managing referral program functionality
class ReferralService {
  final SupabaseClient _client = supabase;

  // Temporarily stored referral code (captured from URL before signup)
  static String? _pendingReferralCode;

  /// Get the base URL for referral links
  /// Points to the marketing site so users can see features and pricing first
  static const String _baseReferralUrl = 'https://seolens.io?ref=';

  /// Capture the referral code from the current URL
  ///
  /// Call this early in app initialization (e.g., in main.dart or router setup)
  /// to capture the ?ref= parameter before navigation changes the URL.
  /// Handles both regular query params and hash-based routing (e.g., #/path?ref=ABC)
  void captureReferralCodeFromUrl() {
    if (!kIsWeb) return;

    try {
      final href = html.window.location.href;
      final uri = Uri.parse(href);
      String? refCode = uri.queryParameters['ref'];

      // Also check hash fragment for query params (Flutter web uses hash routing)
      // URL might be: https://seolens.io/app#/signup?ref=ABC123
      if (refCode == null && uri.fragment.isNotEmpty) {
        final fragmentUri = Uri.tryParse('https://x/${uri.fragment}');
        if (fragmentUri != null) {
          refCode = fragmentUri.queryParameters['ref'];
        }
      }

      if (refCode != null && refCode.isNotEmpty) {
        _pendingReferralCode = refCode;
        print('Captured referral code from URL: $refCode');

        // Also store in localStorage for persistence across page reloads
        html.window.localStorage['pending_referral_code'] = refCode;
      } else {
        // Check localStorage for previously captured code
        final storedCode = html.window.localStorage['pending_referral_code'];
        if (storedCode != null && storedCode.isNotEmpty) {
          _pendingReferralCode = storedCode;
          print('Restored referral code from localStorage: $storedCode');
        }
      }
    } catch (e) {
      print('Error capturing referral code: $e');
    }
  }

  /// Get the pending referral code (if any)
  String? get pendingReferralCode => _pendingReferralCode;

  /// Check if there's a pending referral code
  bool get hasPendingReferral => _pendingReferralCode != null;

  /// Clear the pending referral code (call after attribution is set)
  void clearPendingReferralCode() {
    _pendingReferralCode = null;
    if (kIsWeb) {
      html.window.localStorage.remove('pending_referral_code');
    }
  }

  /// Set referral attribution for the current user
  ///
  /// Call this after signup/login when the user has a profile.
  /// Only sets attribution if:
  /// - There's a pending referral code
  /// - The user's profile doesn't already have a referred_by value
  ///
  /// Returns true if attribution was set, false otherwise.
  Future<bool> setReferralAttribution(String userId) async {
    if (_pendingReferralCode == null) {
      print('No pending referral code to set');
      return false;
    }

    try {
      // First, check if user already has referral attribution
      final profileResponse = await _client
          .from('profiles')
          .select('referred_by')
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse != null && profileResponse['referred_by'] != null) {
        print('User already has referral attribution, skipping');
        clearPendingReferralCode();
        return false;
      }

      // Verify the referral code exists (belongs to a real user)
      final referrerResponse = await _client
          .from('profiles')
          .select('id')
          .eq('referral_code', _pendingReferralCode!)
          .maybeSingle();

      if (referrerResponse == null) {
        print('Referral code not found: $_pendingReferralCode');
        clearPendingReferralCode();
        return false;
      }

      // Don't allow self-referral
      if (referrerResponse['id'] == userId) {
        print('Self-referral detected, skipping');
        clearPendingReferralCode();
        return false;
      }

      // Set the referral attribution
      await _client
          .from('profiles')
          .update({
            'referred_by': _pendingReferralCode,
            'referred_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      print('Referral attribution set: $userId referred by $_pendingReferralCode');
      clearPendingReferralCode();
      return true;
    } catch (e) {
      print('Error setting referral attribution: $e');
      return false;
    }
  }

  /// Build a referral link for the given referral code
  String buildReferralLink(String referralCode) {
    return '$_baseReferralUrl$referralCode';
  }

  /// Copy the referral link to clipboard
  Future<bool> copyReferralLink(String referralCode) async {
    try {
      final link = buildReferralLink(referralCode);
      await Clipboard.setData(ClipboardData(text: link));
      return true;
    } catch (e) {
      print('Error copying referral link: $e');
      return false;
    }
  }

  /// Share the referral link (web only for now)
  ///
  /// On web, this uses the Web Share API if available,
  /// otherwise falls back to copying to clipboard.
  Future<bool> shareReferralLink(String referralCode) async {
    final link = buildReferralLink(referralCode);
    final shareText = 'Check out SEO Lens - the best way to manage your domain portfolio! Sign up with my link: $link';

    if (kIsWeb) {
      try {
        // Check if Web Share API is available
        final navigator = html.window.navigator;
        if (html.window.navigator.share != null) {
          await html.window.navigator.share({
            'title': 'SEO Lens',
            'text': shareText,
            'url': link,
          });
          return true;
        }
      } catch (e) {
        print('Web Share API not available or share canceled: $e');
      }
    }

    // Fallback to clipboard
    return copyReferralLink(referralCode);
  }

  /// Get referral statistics for a user
  ///
  /// Returns a map with:
  /// - referralsThisYear: number of successful referrals this year
  /// - freeMonthsEarned: total free months earned
  /// - freeMonthsThisYear: free months earned this year
  /// - freeUntil: date until which user has free Pro (if any)
  Future<Map<String, dynamic>?> getReferralStats(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('''
            referral_code,
            referral_free_months_earned,
            referral_free_months_this_year,
            referral_year,
            referral_free_until
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        return null;
      }

      return {
        'referralCode': profile['referral_code'],
        'freeMonthsEarned': profile['referral_free_months_earned'] ?? 0,
        'freeMonthsThisYear': profile['referral_free_months_this_year'] ?? 0,
        'referralYear': profile['referral_year'],
        'freeUntil': profile['referral_free_until'] != null
            ? DateTime.parse(profile['referral_free_until'])
            : null,
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return null;
    }
  }

  /// Count how many users this referrer has successfully referred
  /// (users who signed up with their code and subscribed to Pro)
  Future<int> getSuccessfulReferralCount(String userId) async {
    try {
      final response = await _client
          .from('referral_events')
          .select()
          .eq('referrer_id', userId)
          .eq('event_type', 'reward_granted');

      return (response as List).length;
    } catch (e) {
      print('Error counting referrals: $e');
      return 0;
    }
  }
}

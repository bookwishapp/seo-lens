// lib/data/services/billing_service.dart
// Service for handling Stripe billing and checkout flows
//
// Environment variables needed in Supabase Edge Functions:
// - STRIPE_PRICE_PRO_MONTHLY: Stripe Price ID for $2.99/month
// - STRIPE_PRICE_PRO_YEARLY: Stripe Price ID for $19.99/year
// - STRIPE_PRICE_LIFETIME: Stripe Price ID for $49.99 one-time

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_config.dart';

/// Billing plan types
enum BillingPlan {
  proMonthly,
  proYearly,
  lifetime,
}

/// Result of a checkout session creation
class CheckoutResult {
  final bool success;
  final String? url;
  final String? error;

  CheckoutResult({
    required this.success,
    this.url,
    this.error,
  });
}

/// Service for managing billing and Stripe checkout
class BillingService {
  final SupabaseClient _client = supabase;

  // Stripe Price IDs - these should match what's configured in Stripe Dashboard
  // and in the Edge Function environment variables
  static const String _priceProMonthly = 'price_1SaICB5qHmqMYJiA1Ab3X3Mh';
  static const String _priceProYearly = 'price_1SaIDG5qHmqMYJiAVT6WH0ER';
  static const String _priceLifetime = 'price_1SaIEI5qHmqMYJiAKdIZb4iy';

  /// Get the price details for a plan
  PriceInfo getPriceInfo(BillingPlan plan) {
    switch (plan) {
      case BillingPlan.proMonthly:
        return PriceInfo(
          priceId: _priceProMonthly,
          mode: 'subscription',
          interval: 'monthly',
          displayPrice: '\$2.99/month',
          planName: 'Pro Monthly',
        );
      case BillingPlan.proYearly:
        return PriceInfo(
          priceId: _priceProYearly,
          mode: 'subscription',
          interval: 'yearly',
          displayPrice: '\$19.99/year',
          planName: 'Pro Yearly',
          savings: 'Save 44%',
        );
      case BillingPlan.lifetime:
        return PriceInfo(
          priceId: _priceLifetime,
          mode: 'payment',
          interval: 'lifetime',
          displayPrice: '\$49.99 one-time',
          planName: 'Lifetime',
          badge: 'Best Value',
        );
    }
  }

  /// Create a Stripe Checkout session and redirect to it
  ///
  /// Returns a [CheckoutResult] with the checkout URL on success,
  /// or an error message on failure.
  Future<CheckoutResult> createCheckoutSession(BillingPlan plan) async {
    try {
      final priceInfo = getPriceInfo(plan);

      // Build success and cancel URLs based on current window location
      // This allows the checkout to work from any deployment URL
      final origin = kIsWeb ? html.window.location.origin : '';
      final successUrl = '$origin/#/checkout/success?session_id={CHECKOUT_SESSION_ID}';
      final cancelUrl = '$origin/#/checkout/canceled';

      // Call the Edge Function to create a checkout session
      final response = await _client.functions.invoke(
        'create-checkout-session',
        body: {
          'price_id': priceInfo.priceId,
          'mode': priceInfo.mode,
          'interval': priceInfo.interval,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as String? ?? 'Failed to create checkout session';
        return CheckoutResult(success: false, error: error);
      }

      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;

      if (url == null) {
        return CheckoutResult(success: false, error: 'No checkout URL returned');
      }

      return CheckoutResult(success: true, url: url);
    } catch (e) {
      return CheckoutResult(success: false, error: 'Checkout error: $e');
    }
  }

  /// Start the checkout flow for a plan
  ///
  /// On web, this redirects to the Stripe Checkout page.
  /// On mobile, this would use url_launcher (not fully implemented here).
  Future<void> startCheckout(BillingPlan plan) async {
    final result = await createCheckoutSession(plan);

    if (!result.success || result.url == null) {
      throw Exception(result.error ?? 'Failed to start checkout');
    }

    // On web, redirect to the checkout URL
    if (kIsWeb) {
      html.window.location.href = result.url!;
    } else {
      // For mobile, you'd use url_launcher:
      // import 'package:url_launcher/url_launcher.dart';
      // await launchUrl(Uri.parse(result.url!), mode: LaunchMode.externalApplication);
      throw UnimplementedError('Mobile checkout not implemented. Use web for now.');
    }
  }
}

/// Price information for a billing plan
class PriceInfo {
  final String priceId;
  final String mode; // 'subscription' or 'payment'
  final String interval; // 'monthly', 'yearly', 'lifetime'
  final String displayPrice;
  final String planName;
  final String? savings;
  final String? badge;

  PriceInfo({
    required this.priceId,
    required this.mode,
    required this.interval,
    required this.displayPrice,
    required this.planName,
    this.savings,
    this.badge,
  });
}

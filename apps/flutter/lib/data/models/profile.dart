// lib/data/models/profile.dart
// User profile model with billing/plan information

class Profile {
  final String id;
  final DateTime createdAt;
  final String? displayName;
  final String? primaryDomainId;

  // Billing fields
  final String planTier; // 'free', 'pro', 'lifetime'
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? stripeLifetimePaymentId;
  final String? planRenewsInterval; // 'monthly', 'yearly', 'lifetime', null
  final String? planStatus; // 'active', 'canceled', 'past_due', 'incomplete', null
  final DateTime? planCurrentPeriodEnd;
  final DateTime planUpdatedAt;

  Profile({
    required this.id,
    required this.createdAt,
    this.displayName,
    this.primaryDomainId,
    this.planTier = 'free',
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripeLifetimePaymentId,
    this.planRenewsInterval,
    this.planStatus,
    this.planCurrentPeriodEnd,
    DateTime? planUpdatedAt,
  }) : planUpdatedAt = planUpdatedAt ?? DateTime.now();

  /// Check if user is on a paid plan (Pro or Lifetime)
  bool get isPaidPlan => planTier == 'pro' || planTier == 'lifetime';

  /// Check if user is on the free plan
  bool get isFreePlan => planTier == 'free';

  /// Check if user has lifetime access
  bool get isLifetime => planTier == 'lifetime';

  /// Check if user has an active subscription
  bool get hasActiveSubscription =>
      planTier == 'pro' && (planStatus == 'active' || planStatus == 'trialing');

  /// Get a display-friendly plan name
  String get planDisplayName {
    switch (planTier) {
      case 'pro':
        return 'Pro';
      case 'lifetime':
        return 'Lifetime';
      case 'free':
      default:
        return 'Free';
    }
  }

  /// Get a display-friendly billing interval
  String? get billingIntervalDisplayName {
    switch (planRenewsInterval) {
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'lifetime':
        return 'One-time';
      default:
        return null;
    }
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      displayName: json['display_name'] as String?,
      primaryDomainId: json['primary_domain_id'] as String?,
      planTier: json['plan_tier'] as String? ?? 'free',
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      stripeLifetimePaymentId: json['stripe_lifetime_payment_id'] as String?,
      planRenewsInterval: json['plan_renews_interval'] as String?,
      planStatus: json['plan_status'] as String?,
      planCurrentPeriodEnd: json['plan_current_period_end'] != null
          ? DateTime.parse(json['plan_current_period_end'] as String)
          : null,
      planUpdatedAt: json['plan_updated_at'] != null
          ? DateTime.parse(json['plan_updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'display_name': displayName,
      'primary_domain_id': primaryDomainId,
      'plan_tier': planTier,
      'stripe_customer_id': stripeCustomerId,
      'stripe_subscription_id': stripeSubscriptionId,
      'stripe_lifetime_payment_id': stripeLifetimePaymentId,
      'plan_renews_interval': planRenewsInterval,
      'plan_status': planStatus,
      'plan_current_period_end': planCurrentPeriodEnd?.toIso8601String(),
      'plan_updated_at': planUpdatedAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    DateTime? createdAt,
    String? displayName,
    String? primaryDomainId,
    String? planTier,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripeLifetimePaymentId,
    String? planRenewsInterval,
    String? planStatus,
    DateTime? planCurrentPeriodEnd,
    DateTime? planUpdatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      primaryDomainId: primaryDomainId ?? this.primaryDomainId,
      planTier: planTier ?? this.planTier,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeLifetimePaymentId:
          stripeLifetimePaymentId ?? this.stripeLifetimePaymentId,
      planRenewsInterval: planRenewsInterval ?? this.planRenewsInterval,
      planStatus: planStatus ?? this.planStatus,
      planCurrentPeriodEnd: planCurrentPeriodEnd ?? this.planCurrentPeriodEnd,
      planUpdatedAt: planUpdatedAt ?? this.planUpdatedAt,
    );
  }
}

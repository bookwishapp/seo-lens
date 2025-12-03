// lib/data/plan_limits.dart
// Helper functions and constants for plan-based feature limits
//
// Plan tiers:
// - free: 1 domain, 20 pages/scan, manual only, no WHOIS
// - pro: 10 domains, 50 pages/scan, weekly scans, WHOIS enabled
// - lifetime: Same as Pro, one-time purchase

/// Get the maximum number of domains allowed for a plan tier
int maxDomainsForPlan(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return 10;
    case 'free':
    default:
      return 1;
  }
}

/// Get the maximum number of pages per domain per scan for a plan tier
int maxPagesPerDomainForPlan(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return 50;
    case 'free':
    default:
      return 20;
  }
}

/// Check if a plan allows automatic weekly scans
bool canUseWeeklyScan(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return true;
    case 'free':
    default:
      return false;
  }
}

/// Check if a plan allows WHOIS/RDAP lookups
bool canUseWhois(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return true;
    case 'free':
    default:
      return false;
  }
}

/// Check if a plan allows the redirect plan feature
bool canUseRedirectPlan(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return true;
    case 'free':
    default:
      return false;
  }
}

/// Check if user can add another domain given current count
bool canAddDomain(String planTier, int currentDomainCount) {
  final maxDomains = maxDomainsForPlan(planTier);
  return currentDomainCount < maxDomains;
}

/// Get the available scan frequencies for a plan
List<ScanFrequency> availableScanFrequencies(String planTier) {
  switch (planTier) {
    case 'pro':
    case 'lifetime':
      return [
        ScanFrequency.manual,
        ScanFrequency.weekly,
      ];
    case 'free':
    default:
      return [ScanFrequency.manual];
  }
}

/// Scan frequency options
enum ScanFrequency {
  manual('manual', 'Manual only', 'Scan only when you trigger it'),
  weekly('weekly', 'Weekly', 'Scan all domains once per week');

  final String value;
  final String label;
  final String description;

  const ScanFrequency(this.value, this.label, this.description);
}

/// Plan feature comparison for upgrade prompts
class PlanFeatures {
  final String planName;
  final int maxDomains;
  final int maxPagesPerScan;
  final bool weeklyScan;
  final bool whoisEnabled;
  final bool redirectPlan;
  final String price;

  const PlanFeatures({
    required this.planName,
    required this.maxDomains,
    required this.maxPagesPerScan,
    required this.weeklyScan,
    required this.whoisEnabled,
    required this.redirectPlan,
    required this.price,
  });

  static const free = PlanFeatures(
    planName: 'Free',
    maxDomains: 1,
    maxPagesPerScan: 20,
    weeklyScan: false,
    whoisEnabled: false,
    redirectPlan: false,
    price: 'Free',
  );

  static const pro = PlanFeatures(
    planName: 'Pro',
    maxDomains: 10,
    maxPagesPerScan: 50,
    weeklyScan: true,
    whoisEnabled: true,
    redirectPlan: true,
    price: '\$2.99/month',
  );

  static const lifetime = PlanFeatures(
    planName: 'Lifetime',
    maxDomains: 10,
    maxPagesPerScan: 50,
    weeklyScan: true,
    whoisEnabled: true,
    redirectPlan: true,
    price: '\$49.99 one-time',
  );

  static PlanFeatures forTier(String tier) {
    switch (tier) {
      case 'pro':
        return pro;
      case 'lifetime':
        return lifetime;
      case 'free':
      default:
        return free;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers.dart';
import '../ui/screens/auth_screen.dart';
import '../ui/screens/checkout_canceled_screen.dart';
import '../ui/screens/checkout_success_screen.dart';
import '../ui/screens/domain_detail_screen.dart';
import '../ui/screens/domains_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/referral_screen.dart';
import '../ui/screens/report/public_report_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/screens/suggestions_screen.dart';
import '../ui/screens/upgrade_screen.dart';
import '../ui/widgets/app_shell.dart';

/// Router configuration for the app
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final pendingUpgradePlan = ref.watch(pendingUpgradePlanProvider);
  final referralService = ref.watch(referralServiceProvider);

  // Capture referral code from URL on initial load
  referralService.captureReferralCodeFromUrl();

  return GoRouter(
    initialLocation: '/auth',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (state) => state.session != null,
        orElse: () => false,
      );

      // Use uri.path for the actual requested path
      final path = state.uri.path;
      // Debug: log the path being checked
      print('Router redirect check - path: $path, matchedLocation: ${state.matchedLocation}');

      final isAuthRoute = path == '/auth';
      final isSignupRoute = path == '/signup';
      final isUpgradeRoute = path == '/upgrade';
      // Public report route - no auth required
      final isPublicReportRoute = path.startsWith('/report/');

      // Check for upgrade param: provider first (persists), then URL
      final upgradeParam = pendingUpgradePlan ?? state.uri.queryParameters['upgrade'];
      final planParam = state.uri.queryParameters['plan'];

      // Capture referral code from URL parameter (for signup links)
      final refParam = state.uri.queryParameters['ref'];
      if (refParam != null && refParam.isNotEmpty) {
        // Re-capture in case it wasn't caught initially
        referralService.captureReferralCodeFromUrl();
      }

      // Not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute && !isSignupRoute && !isPublicReportRoute) {
        // Preserve upgrade/plan parameter when redirecting to auth
        if (isUpgradeRoute && planParam != null) {
          return '/auth?upgrade=$planParam';
        }
        if (upgradeParam != null) {
          return '/auth?upgrade=$upgradeParam';
        }
        // Preserve ref parameter if present
        if (refParam != null) {
          return '/auth?ref=$refParam';
        }
        return '/auth';
      }

      // Handle /signup redirect to /auth with ref param preserved
      if (isSignupRoute) {
        if (refParam != null) {
          return '/auth?ref=$refParam';
        }
        return '/auth';
      }

      // Authenticated and on auth screen
      if (isAuthenticated && isAuthRoute) {
        // If there's an upgrade parameter, redirect to upgrade flow
        if (upgradeParam != null) {
          return '/upgrade?plan=$upgradeParam';
        }
        // Redirect to onboarding - it will check if user has domains
        // and redirect to /home if they do
        return '/onboarding';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth route (outside shell)
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // Signup route (redirects to auth with ref param)
      GoRoute(
        path: '/signup',
        name: 'signup',
        redirect: (context, state) {
          final refParam = state.uri.queryParameters['ref'];
          if (refParam != null) {
            return '/auth?ref=$refParam';
          }
          return '/auth';
        },
        builder: (context, state) => const AuthScreen(),
      ),

      // Onboarding route (outside shell)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Public report route (outside shell, no auth required)
      // Path is relative to base-href (/app/), so use /report/:token
      GoRoute(
        path: '/report/:token',
        name: 'public-report',
        builder: (context, state) {
          final token = state.pathParameters['token']!;
          return PublicReportScreen(token: token);
        },
      ),

      // App shell with nested routes
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Home
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
            ),
          ),

          // Domains list
          GoRoute(
            path: '/domains',
            name: 'domains',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DomainsScreen(),
            ),
            routes: [
              // Domain detail
              GoRoute(
                path: ':id',
                name: 'domain-detail',
                builder: (context, state) {
                  final domainId = state.pathParameters['id']!;
                  return DomainDetailScreen(domainId: domainId);
                },
              ),
            ],
          ),

          // Suggestions
          GoRoute(
            path: '/suggestions',
            name: 'suggestions',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SuggestionsScreen(),
            ),
          ),

          // Settings
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
            ),
          ),

          // Referral program
          GoRoute(
            path: '/referral',
            name: 'referral',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ReferralScreen(),
            ),
          ),

          // Upgrade (handles checkout from external links)
          GoRoute(
            path: '/upgrade',
            name: 'upgrade',
            builder: (context, state) {
              final plan = state.uri.queryParameters['plan'];
              return UpgradeScreen(plan: plan);
            },
          ),

          // Checkout success (return from Stripe)
          GoRoute(
            path: '/checkout/success',
            name: 'checkout-success',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CheckoutSuccessScreen(),
            ),
          ),

          // Checkout canceled (return from Stripe)
          GoRoute(
            path: '/checkout/canceled',
            name: 'checkout-canceled',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CheckoutCanceledScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

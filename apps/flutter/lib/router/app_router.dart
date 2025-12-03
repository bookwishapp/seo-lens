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
import '../ui/screens/settings_screen.dart';
import '../ui/screens/suggestions_screen.dart';
import '../ui/screens/upgrade_screen.dart';
import '../ui/widgets/app_shell.dart';

/// Router configuration for the app
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/auth',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (state) => state.session != null,
        orElse: () => false,
      );

      final isAuthRoute = state.matchedLocation == '/auth';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final upgradeParam = state.uri.queryParameters['upgrade'];

      // Not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute) {
        // Preserve upgrade parameter when redirecting to auth
        if (upgradeParam != null) {
          return '/auth?upgrade=$upgradeParam';
        }
        return '/auth';
      }

      // Authenticated and on auth screen
      if (isAuthenticated && isAuthRoute) {
        // If there's an upgrade parameter, redirect to upgrade flow
        if (upgradeParam != null) {
          return '/upgrade?plan=$upgradeParam';
        }
        return '/home';
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

      // Onboarding route (outside shell)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
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

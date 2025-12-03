import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand color from landing page
const Color _primaryBlue = Color(0xFF5F9DF7);

/// App shell that provides navigation and layout
///
/// Switches between mobile (bottom nav) and desktop (navigation rail) layouts
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return _DesktopLayout(child: child);
        } else {
          return _MobileLayout(child: child);
        }
      },
    );
  }
}

/// Mobile layout with bottom navigation bar
class _MobileLayout extends StatelessWidget {
  final Widget child;

  const _MobileLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _getSelectedIndex(currentRoute);

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            context.go('/');
          },
          child: Text(
            'SEO Lens',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        indicatorColor: _primaryBlue.withAlpha(50),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: _primaryBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.language_outlined),
            selectedIcon: Icon(Icons.language, color: _primaryBlue),
            label: 'Domains',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb, color: _primaryBlue),
            label: 'Suggestions',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: _primaryBlue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/domains')) return 1;
    if (location.startsWith('/suggestions')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/domains');
        break;
      case 2:
        context.go('/suggestions');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}

/// Desktop layout with navigation rail
class _DesktopLayout extends StatelessWidget {
  final Widget child;

  const _DesktopLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _getSelectedIndex(currentRoute);

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            context.go('/');
          },
          child: Text(
            'SEO Lens',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            indicatorColor: _primaryBlue.withAlpha(50),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SvgPicture.asset(
                'assets/seo_lens_logo.svg',
                width: 48,
                height: 48,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: _primaryBlue),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.language_outlined),
                selectedIcon: Icon(Icons.language, color: _primaryBlue),
                label: Text('Domains'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.lightbulb_outline),
                selectedIcon: Icon(Icons.lightbulb, color: _primaryBlue),
                label: Text('Suggestions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: _primaryBlue),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/domains')) return 1;
    if (location.startsWith('/suggestions')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/domains');
        break;
      case 2:
        context.go('/suggestions');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';

/// Onboarding flow for new users
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _domainsController = TextEditingController();

  int _currentPage = 0;
  bool _isScanning = false;
  List<String> _addedDomains = [];

  @override
  void dispose() {
    _pageController.dispose();
    _domainsController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addDomains() async {
    final text = _domainsController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isScanning = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Split by various separators
      final domainNames = text
          .split(RegExp(r'[\s,\n]+'))
          .where((name) => name.isNotEmpty)
          .map((name) => name.trim().toLowerCase())
          .toSet()
          .toList();

      // Add domains to database
      final domainService = ref.read(domainServiceProvider);
      await domainService.addDomains(
        userId: user.id,
        domainNames: domainNames,
      );

      // Trigger a simple scan for each domain
      final scanService = ref.read(scanServiceProvider);
      final domains = await domainService.getDomains();

      // Scan in background (don't await all)
      for (var domain in domains) {
        scanService
            .scanDomain(
              domainId: domain.id,
              domainName: domain.domainName,
            )
            .catchError((e) => print('Scan failed for ${domain.domainName}: $e'));
      }

      setState(() {
        _addedDomains = domainNames;
        _isScanning = false;
      });

      _nextPage();
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding domains: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to SEO Lens'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          _WelcomePage(onNext: _nextPage),
          _AddDomainsPage(
            controller: _domainsController,
            isLoading: _isScanning,
            onAdd: _addDomains,
          ),
          _ScanResultsPage(
            domains: _addedDomains,
            onFinish: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.park,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to your Domain Garden',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'SEO Lens helps you manage all your domains in one place. '
                'See their status, monitor SEO health, and get suggestions for improvements.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDomainsPage extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onAdd;

  const _AddDomainsPage({
    required this.controller,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Add Your Domains',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'Paste your domains below (one per line, or separated by commas/spaces):',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'example.com\nmy-site.io\nanother-domain.net',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isLoading ? null : onAdd,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Scan My Domains'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanResultsPage extends ConsumerWidget {
  final List<String> domains;
  final VoidCallback onFinish;

  const _ScanResultsPage({
    required this.domains,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Domains Added!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve added ${domains.length} domain${domains.length == 1 ? '' : 's'} '
                'and started scanning them. This may take a few moments.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  child: ListView.builder(
                    itemCount: domains.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(domains[index]),
                        trailing: const Icon(Icons.check, color: Colors.green),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.dashboard),
                label: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayNameController = TextEditingController();
  String _scanFrequency = 'manual';

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),

              // Account section
              Text(
                'Account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: userAsync != null
                            ? Text(userAsync.email ?? 'Not available')
                            : const Text('Loading...'),
                      ),
                      const Divider(),
                      profileAsync.when(
                        data: (profile) {
                          if (profile != null &&
                              _displayNameController.text.isEmpty) {
                            _displayNameController.text =
                                profile.displayName ?? '';
                          }
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: TextField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            trailing: FilledButton(
                              onPressed: () async {
                                final user = ref.read(currentUserProvider);
                                if (user == null) return;

                                await ref
                                    .read(authServiceProvider)
                                    .updateProfile(
                                      userId: user.id,
                                      displayName: _displayNameController.text,
                                    );
                                ref.invalidate(currentProfileProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Profile updated')),
                                  );
                                }
                              },
                              child: const Text('Save'),
                            ),
                          );
                        },
                        loading: () => const ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Loading...'),
                        ),
                        error: (error, stack) => ListTile(
                          leading: const Icon(Icons.error),
                          title: Text('Error: $error'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Scan preferences
              Text(
                'Scan Preferences',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Frequency',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'How often should we automatically scan your domains?',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      RadioListTile<String>(
                        title: const Text('Manual only'),
                        subtitle: const Text('Scan only when you trigger it'),
                        value: 'manual',
                        groupValue: _scanFrequency,
                        onChanged: (value) =>
                            setState(() => _scanFrequency = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Weekly'),
                        subtitle: const Text('Scan all domains once per week'),
                        value: 'weekly',
                        groupValue: _scanFrequency,
                        onChanged: (value) =>
                            setState(() => _scanFrequency = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Monthly'),
                        subtitle:
                            const Text('Scan all domains once per month'),
                        value: 'monthly',
                        groupValue: _scanFrequency,
                        onChanged: (value) =>
                            setState(() => _scanFrequency = value!),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Danger zone
              Text(
                'Danger Zone',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Sign Out'),
                        subtitle: const Text(
                            'Sign out of your account on this device'),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await ref.read(authServiceProvider).signOut();
                            if (context.mounted) {
                              context.go('/auth');
                            }
                          },
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

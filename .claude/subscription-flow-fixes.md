# Task: Fix Subscription Flow Bugs in SEO Lens Flutter App

You are fixing specific bugs in the subscription/checkout flow. **Do not refactor, reorganize, rename, or "improve" any code beyond the exact changes specified below.** Do not add comments, documentation, or type annotations to unchanged code. Do not change formatting or style of existing code.

---

## Fix 1: auth_screen.dart - Move parameter reading out of initState

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/ui/screens/auth_screen.dart`

**Problem**: `GoRouterState.of(context)` in `initState` may not have the router state ready yet.

**Change**: Move the upgrade parameter reading from `initState` to `didChangeDependencies`.

**Current code (lines 24-34)**:
```dart
@override
void initState() {
  super.initState();
  // Store upgrade parameter in provider so it persists across navigation
  final upgradeParam = GoRouterState.of(context).uri.queryParameters['upgrade'];
  if (upgradeParam != null) {
    Future.microtask(() {
      ref.read(pendingUpgradePlanProvider.notifier).state = upgradeParam;
    });
  }
}
```

**Replace with**:
```dart
bool _hasReadUpgradeParam = false;

@override
void initState() {
  super.initState();
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_hasReadUpgradeParam) {
    _hasReadUpgradeParam = true;
    final upgradeParam = GoRouterState.of(context).uri.queryParameters['upgrade'];
    if (upgradeParam != null) {
      Future.microtask(() {
        ref.read(pendingUpgradePlanProvider.notifier).state = upgradeParam;
      });
    }
  }
}
```

**Note**: Add `bool _hasReadUpgradeParam = false;` as a field in `_AuthScreenState` class (after line 22, near `bool _isLogin = true;`).

---

## Fix 2: upgrade_screen.dart - Don't clear upgrade intent prematurely

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/ui/screens/upgrade_screen.dart`

**Problem**: `pendingUpgradePlanProvider` is cleared in `initState` before checkout even starts. If checkout fails, user loses their intent.

**Change**: Remove the clearing of `pendingUpgradePlanProvider` from `initState`. It will be cleared when user successfully reaches checkout success.

**Current code (lines 22-29)**:
```dart
@override
void initState() {
  super.initState();
  // Clear pending upgrade plan since we're now on the upgrade screen
  Future.microtask(() {
    ref.read(pendingUpgradePlanProvider.notifier).state = null;
  });
  _handleCheckout();
}
```

**Replace with**:
```dart
@override
void initState() {
  super.initState();
  _handleCheckout();
}
```

---

## Fix 3: checkout_success_screen.dart - Force onboarding for new users

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/ui/screens/checkout_success_screen.dart`

**Problem**: New users (no domains) can click navigation buttons before auto-redirect to onboarding. They can bypass onboarding entirely.

**Changes**:

**3a. Clear the pending upgrade plan and add state tracking. Replace lines 14-36 with:**

```dart
class _CheckoutSuccessScreenState extends ConsumerState<CheckoutSuccessScreen> {
  bool _isNewUser = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      // Clear pending upgrade plan now that checkout succeeded
      ref.read(pendingUpgradePlanProvider.notifier).state = null;
      ref.invalidate(currentProfileProvider);
      _checkOnboardingStatus();
    });
  }

  Future<void> _checkOnboardingStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final domains = await ref.read(domainsProvider.future);

    if (mounted) {
      if (domains.isEmpty) {
        setState(() {
          _isNewUser = true;
          _isChecking = false;
        });
        // Auto-redirect new users to onboarding after showing success briefly
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/onboarding');
        }
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }
```

**3b. Update the build method to hide buttons for new users. Replace the buttons section (lines 70-80) with:**

```dart
              const SizedBox(height: 32),
              if (_isChecking)
                const CircularProgressIndicator()
              else if (_isNewUser)
                const Text(
                  'Redirecting to setup...',
                  style: TextStyle(color: Colors.grey),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('View Plan Details'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home),
                  label: const Text('Go to Dashboard'),
                ),
              ],
```

**3c. Add the import for pendingUpgradePlanProvider if not already present** (it should already be imported via providers.dart).

---

## Fix 4: app_router.dart - Add onboarding gate for authenticated users

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/router/app_router.dart`

**Problem**: If an authenticated user somehow reaches `/home` with no domains, they're stuck. Need to redirect to onboarding.

**Change**: This requires async domain check which complicates the redirect. Instead, we'll handle this in the HomeScreen itself.

**Skip this file - see Fix 5 instead.**

---

## Fix 5: home_screen.dart - Redirect to onboarding if no domains

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/ui/screens/home_screen.dart`

**Problem**: User can reach home with no domains and be stuck.

**Change**: Convert to ConsumerStatefulWidget and check domains on init.

**Replace the entire class definition (lines 7-9) and add domain check:**

**Current (line 7-11)**:
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

**Replace with**:
```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedDomains = false;

  @override
  void initState() {
    super.initState();
    _checkDomains();
  }

  Future<void> _checkDomains() async {
    if (_hasCheckedDomains) return;
    _hasCheckedDomains = true;

    try {
      final domains = await ref.read(domainsProvider.future);
      if (mounted && domains.isEmpty) {
        context.go('/onboarding');
      }
    } catch (e) {
      // Ignore errors, let user stay on home
    }
  }

  @override
  Widget build(BuildContext context) {
```

**Also change line 219** from `}` to `}}` (close both the build method and the State class).

**Note**: The `ref.watch` calls inside build need to stay as `ref.watch` - do not change them.

---

## Fix 6: checkout_canceled_screen.dart - Preserve upgrade intent

**File**: `/Users/terryheath/Documents/seo_lens/apps/flutter/lib/ui/screens/checkout_canceled_screen.dart`

**Read this file first**, then make these changes:

**Change**: When user cancels checkout, redirect them back to settings with their upgrade intent preserved (don't clear `pendingUpgradePlanProvider`).

If the file has a "Try Again" button, make sure it goes to `/upgrade?plan=X` using the preserved plan. If not, add a simple "Try Again" option.

**Expected behavior**: User cancels Stripe → returns to app → can easily retry checkout.

---

## Verification

After making changes, run:
```bash
cd /Users/terryheath/Documents/seo_lens/apps/flutter && flutter analyze
```

Fix any errors introduced. Do not fix pre-existing warnings unrelated to your changes.

---

## What NOT to do

- Do not rename any variables, functions, or classes
- Do not add new files
- Do not refactor existing working code
- Do not add comments to unchanged code
- Do not change import order or formatting
- Do not add new dependencies
- Do not modify any files not listed above
- Do not add debug print statements (unless explicitly needed for a fix)
- Do not change the visual appearance or styling of any screens
- Do not modify the router's route definitions (paths, names)

---

## Commit Message

After all changes compile successfully:

```
fix: Resolve subscription flow bugs preventing checkout completion

- Move upgrade param reading to didChangeDependencies in auth screen
- Don't clear upgrade intent until checkout succeeds
- Force new users to onboarding after checkout (no bypass)
- Redirect to onboarding if user reaches home with no domains
- Preserve upgrade intent when checkout is canceled
```

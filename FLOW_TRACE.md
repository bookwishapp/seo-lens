# New User Upgrade Flow - Detailed Trace

## Expected Flow

### Step 1: User clicks "Get Pro access" → "Monthly ($2.99/mo)"
- Location: Homepage `/` (Next.js marketing site)
- Action: Click link with `href="/api/checkout?plan=pro-monthly"`

### Step 2: Next.js API Route
- Location: `/api/checkout?plan=pro-monthly`
- File: `apps/web/app/api/checkout/route.ts:25`
- Action: `NextResponse.redirect(${appUrl}#/upgrade?plan=pro-monthly)`
- Result: Browser redirects to `/app#/upgrade?plan=pro-monthly`

### Step 3: Flutter App Loads
- Location: `/app#/upgrade?plan=pro-monthly`
- Router initial location: `/auth` (line 21 in app_router.dart)
- Router processes: `/upgrade?plan=pro-monthly`
- Auth state: NOT authenticated

### Step 4: Router Redirect (Unauthenticated on /upgrade)
- Location: `/upgrade?plan=pro-monthly`
- File: `app_router.dart:37-46`
- Check: `!isAuthenticated && !isAuthRoute` → TRUE
- Check: `isUpgradeRoute && planParam != null` → TRUE (line 40-41)
- Extract: `planParam = 'pro-monthly'`
- **Action: `return '/auth?upgrade=pro-monthly'`**
- Result: Router redirects to `/auth?upgrade=pro-monthly`

### Step 5: User Signs Up
- Location: `/auth?upgrade=pro-monthly`
- File: `auth_screen.dart:42-76`
- User fills form and clicks "Sign Up"
- AuthService creates account
- **Session established**

### Step 6: Router Redirect (Authenticated on /auth)
**CRITICAL TIMING ISSUE:**
- authStateProvider emits new state (authenticated)
- routerProvider rebuilds
- Router's redirect function runs
- Location: Still `/auth?upgrade=pro-monthly`
- File: `app_router.dart:49-57`
- Check: `isAuthenticated && isAuthRoute` → TRUE
- **Extract: `upgradeParam = state.uri.queryParameters['upgrade']`**
  - **Q: Does state.uri still have the upgrade parameter?**
  - **Q: Or has the URL changed during signup?**
- Check: `if (upgradeParam != null)` → TRUE or FALSE?
  - If TRUE: `return '/upgrade?plan=$upgradeParam'` ✓ (CORRECT)
  - If FALSE: `return '/onboarding'` ✗ (BUG - sends to onboarding)

### Step 7a: If Upgrade Param Preserved (EXPECTED)
- Location: `/upgrade?plan=pro-monthly`
- File: `upgrade_screen.dart:22-71`
- UpgradeScreen.initState() calls _handleCheckout()
- Waits 300ms
- Calls `billingService.startCheckout(BillingPlan.proMonthly)`
- Redirects to Stripe Checkout

### Step 7b: If Upgrade Param Lost (BUG)
- Location: `/onboarding`
- File: `onboarding_screen.dart:24-43`
- Onboarding.initState() calls _checkExistingDomains()
- Waits, checks domains
- domains.isEmpty → TRUE (new user)
- Stays on onboarding (doesn't redirect to /home)
- **USER NEVER SEES STRIPE CHECKOUT**

### Step 8: After Stripe (if flow worked correctly)
- Location: `/checkout/success?session_id=xxx`
- File: `checkout_success_screen.dart:16-36`
- CheckoutSuccess.initState() calls _checkOnboardingStatus()
- Invalidates currentProfileProvider
- Waits 500ms
- Checks domains.isEmpty
- If empty → `context.go('/onboarding')` (NEW USER - CORRECT)

## Potential Issues

### Issue 1: URL Parameter Loss
**Problem:** During signup, the URL might change from `/auth?upgrade=pro-monthly` to `/auth`
**Cause:** Go router might update the URL after form submission
**Effect:** upgradeParam becomes null, router sends user to onboarding

### Issue 2: Router State Timing
**Problem:** Router's redirect function checks `state.uri.queryParameters` but this might be stale
**Cause:** Router rebuilds on auth state change, but URL state might not be updated
**Effect:** upgradeParam is null even though it should exist

### Issue 3: Multiple Router Rebuilds
**Problem:** Router rebuilds multiple times during signup
**Cause:** authStateProvider streams changes, routerProvider watches it
**Effect:** Race condition - later rebuild has different URL state

## Recommended Fix

Store the upgrade parameter in a StateProvider that persists across navigation:

```dart
final pendingUpgradeProvider = StateProvider<String?>((ref) => null);
```

When user lands on /auth with upgrade param, store it:
- auth_screen.dart: Store upgrade param in initState
- Router: Check StateProvider first, then URL param
- Clear StateProvider after successful redirect to /upgrade

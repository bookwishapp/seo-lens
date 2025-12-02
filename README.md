# SEO Lens

A personal domain management and SEO monitoring tool for domain hoarders and creators who manage multiple websites.

## Overview

SEO Lens helps you:
- Track all your domains in one place
- Monitor domain status (live, redirected, broken)
- View basic SEO health for key pages
- Get suggestions for improvements
- Reduce cognitive load managing multiple domains

Think of it as your personal "Domain Garden" manager.

## Tech Stack

- **Frontend**: Flutter (iOS, Android, Web)
- **Backend**: Supabase (Auth + Postgres)
- **State Management**: Riverpod
- **Routing**: go_router
- **Deployment**:
  - Web: Vercel (or any static host)
  - Mobile: Standard Flutter builds

## Setup Instructions

### 1. Prerequisites

- Flutter SDK (3.10.1 or higher)
- A Supabase account (free tier works)
- Git

### 2. Clone the Repository

```bash
git clone <your-repo-url>
cd seo_lens
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Set Up Supabase

#### Create a Supabase Project

1. Go to [https://app.supabase.com](https://app.supabase.com)
2. Create a new project
3. Note your project URL and anon/public key

#### Run the Database Schema

1. In your Supabase project, go to the SQL Editor
2. Copy the contents of `supabase/schema.sql`
3. Paste and run the SQL to create all tables, RLS policies, and triggers

#### Configure Supabase Credentials

Edit `lib/supabase_config.dart` and replace the placeholder values:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

You can find these in your Supabase project settings under:
**Settings** > **API** > **Project URL** and **anon/public key**

### 5. Run the App

#### Web
```bash
flutter run -d chrome
```

#### iOS
```bash
flutter run -d ios
```

#### Android
```bash
flutter run -d android
```

### 6. Deploy to Vercel (Web)

1. Build the web version:
   ```bash
   flutter build web
   ```

2. The output will be in `build/web/`

3. Push your repository to GitHub

4. In Vercel:
   - Import your GitHub repository
   - Set the build command: `flutter build web`
   - Set the output directory: `build/web`
   - Deploy

## Project Structure

```
lib/
├── data/
│   ├── models/          # Data models (Domain, Profile, Suggestion, etc.)
│   ├── services/        # API services (Auth, Domain, Scan, Suggestion)
│   └── providers.dart   # Riverpod state providers
├── router/
│   └── app_router.dart  # go_router configuration
├── ui/
│   ├── screens/         # All app screens
│   └── widgets/         # Reusable widgets (AppShell, etc.)
├── main.dart            # App entry point
└── supabase_config.dart # Supabase initialization
```

## Features

### Current (v1)

- ✅ Email/password authentication via Supabase
- ✅ Onboarding flow for new users
- ✅ Add and manage domains
- ✅ Dashboard with domain statistics
- ✅ Domain list with search and filtering
- ✅ Domain detail view with status and redirect tracking
- ✅ Simple HTTP-based domain scanning
- ✅ Suggestions system (placeholder suggestions)
- ✅ User settings and profile management
- ✅ Responsive design (mobile + desktop)

### Future Enhancements

- [ ] Background worker for scanning (Railway, etc.)
- [ ] DNS lookups and resolution tracking
- [ ] Full HTML parsing for meta tag extraction
- [ ] robots.txt processing
- [ ] Scheduled scans (weekly, monthly)
- [ ] AI-powered SEO suggestions
- [ ] Team/organization support
- [ ] Billing integration
- [ ] Email notifications

## Database Schema

The app uses these main tables:

- `profiles` - User profiles
- `domains` - Domain records
- `domain_status` - Latest status snapshots
- `site_pages` - Individual page data
- `suggestions` - Action items and recommendations
- `jobs` - Background job queue (for future use)

All tables have Row Level Security (RLS) enabled, ensuring users can only access their own data.

## Development Notes

### Scanning

The current v1 implementation uses simple HTTP requests from the Flutter app to check domain status and follow redirects. This is marked with TODO comments for future enhancement.

**Future**: Move scanning to a background worker that:
- Performs proper DNS lookups
- Follows complete redirect chains
- Crawls pages and extracts meta tags
- Processes robots.txt
- Runs on a schedule

Look for `TODO` comments in `lib/data/services/scan_service.dart`.

### State Management

The app uses Riverpod for state management. Key providers are in `lib/data/providers.dart`.

### Routing

go_router handles all navigation. The router configuration is in `lib/router/app_router.dart` with:
- Auth flow redirection
- Shell routes for the main app navigation
- URL-based routing for web support

## Contributing

This is a personal project, but suggestions and contributions are welcome!

## License

MIT License - feel free to use this as a starting point for your own projects.

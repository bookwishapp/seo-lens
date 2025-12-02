# Deployment Guide

## Environment Variables

This app requires the following environment variables:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon/public key

## Local Development

1. Copy `.env.example` to `.env.local`:
   ```bash
   cp .env.example .env.local
   ```

2. Fill in your Supabase credentials in `.env.local`

3. Run with environment variables:
   ```bash
   flutter run -d chrome --dart-define=SUPABASE_URL=$(grep SUPABASE_URL .env.local | cut -d '=' -f2) --dart-define=SUPABASE_ANON_KEY=$(grep SUPABASE_ANON_KEY .env.local | cut -d '=' -f2)
   ```

   Or use this shortcut:
   ```bash
   source .env.local && flutter run -d chrome --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
   ```

## Vercel Deployment

1. Import your GitHub repository to Vercel

2. Add environment variables in Vercel dashboard:
   - Go to Project Settings → Environment Variables
   - Add `SUPABASE_URL` with your Supabase URL
   - Add `SUPABASE_ANON_KEY` with your anon key

3. Deploy!

The `vercel.json` configuration will automatically pass these variables to the Flutter build process.

## Security Notes

- Never commit `.env.local` to git (it's in `.gitignore`)
- The `.env.example` file should only contain placeholder values
- Environment variables are baked into the JavaScript bundle at build time for web deployments

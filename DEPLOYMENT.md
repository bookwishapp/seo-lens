# Deployment Guide

## Environment Variables

This app requires the following environment variables:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon/public key

## Local Development

1. Ensure `.env.local` exists with your Supabase credentials (it should already be there)

2. Run the app using the helper script:
   ```bash
   ./run_local.sh
   ```

   Or manually with:
   ```bash
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=your_supabase_url \
     --dart-define=SUPABASE_ANON_KEY=your_anon_key
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

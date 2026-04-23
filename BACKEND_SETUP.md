# MyMoney Ledger backend choice

I picked **Supabase** for this app.

Why this one:
- live hosted Postgres database
- auth for real users
- realtime updates
- row-level security for per-user privacy
- simple Flutter integration
- easy anonymous sign-in first, proper account upgrade later

## What is already prepared in this project
- Flutter dependencies for `supabase_flutter` and `flutter_dotenv`
- runtime backend loader: `lib/backend/supabase_backend.dart`
- cloud sync service: `lib/services/cloud_ledger_service.dart`
- env template: `.env.example`
- SQL migration: `supabase/migrations/20260423_init_mymoney.sql`
- app state now supports cloud snapshot sync when Supabase is configured

## Live backend status
The live Supabase project is now created and wired:
- project name: `mymoney-ledger`
- project ref: `iermrkgffntavkdrwvbw`
- region: `ap-south-1`
- dashboard: `https://supabase.com/dashboard/project/iermrkgffntavkdrwvbw`
- anonymous auth: enabled

## What was done
1. Created the live Supabase project
2. Applied the SQL migration in `supabase/migrations/20260423_init_mymoney.sql`
3. Enabled anonymous sign-ins in Supabase Auth
4. Wrote the project URL + publishable key into `.env`
5. App is ready to use cloud-backed user data

## Remaining product work
- add proper user login/upgrade flow (email/Google/etc.)
- move from whole-ledger snapshot sync to structured table sync if needed
- deploy the website to a public domain and set the final auth/site URL

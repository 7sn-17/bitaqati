# Configuration

## Supabase

| Item | Value |
|---|---|
| Project | `bitaqati` |
| Ref | `mftghnvtdryxzochquee` |
| URL | `https://mftghnvtdryxzochquee.supabase.co` |
| Region | `eu-central-1` |
| Plan | Free ($0/month) |

The **publishable** key is safe to ship in a client. It is available in the
Supabase dashboard under **Project Settings → API**. Never place a
`service_role` key in the Flutter app.

### Local run with Supabase

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://mftghnvtdryxzochquee.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

The app currently works fully offline and does not require these values.

### GitHub Actions

Add repository variables (Settings → Secrets and variables → Actions →
Variables):

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Then pass them to the build:

```yaml
- run: flutter build apk --release \
    --dart-define=SUPABASE_URL=${{ vars.SUPABASE_URL }} \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=${{ vars.SUPABASE_PUBLISHABLE_KEY }}
```

## Database migrations

The SQL is committed in `supabase/migrations/`:

1. `20261025000100_initial_schema.sql`
2. `20261025000200_hardening.sql`

Apply via the Supabase MCP `apply_migration` tool, or with the Supabase CLI:

```bash
supabase link --project-ref mftghnvtdryxzochquee
supabase db push
```

The hardening migration clears all security advisor warnings. The only
remaining advisor notice is unused indexes, which is expected while the tables
are empty.

## Android signing

Phase 0 uses the debug keystore for release builds so APKs are installable from
GitHub Actions. Before publishing to Google Play, add a release keystore to
GitHub Secrets and update `android/app/build.gradle.kts`.

## APK

Download the latest `bitaqati-phase0-apk` artifact from the **Actions** tab, or
run:

```bash
gh run download --repo 7sn-17/bitaqati \
  -n bitaqati-phase0-apk -D ./dist
```

Install on a connected Android device:

```bash
adb install -r ./dist/bitaqati-phase0.apk
```

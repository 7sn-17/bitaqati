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

`GOOGLE_WEB_CLIENT_ID` is optional locally because the public Web client id
is the default in `lib/core/config/app_config.dart`.

### GitHub Actions

Add these repository **secrets** (Settings → Secrets and variables → Actions →
Secrets):

| Secret | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable (anon) key |
| `GOOGLE_WEB_CLIENT_ID` | Optional override; should be the **Web** client id |
| `KEYSTORE_PASSWORD` | `bitaqati.p12` store password |
| `KEY_ALIAS` | Key alias inside `bitaqati.p12` |
| `KEY_PASSWORD` | Key password |
| `KEYSTORE_BASE64` | Base64 of the registered release keystore (authoritative; the committed `bitaqati.p12` is a fallback) |

Optional repository **variable**:

- `ANDROID_CERT_SHA1` — expected APK signer SHA-1. When set, CI fails if the
  built APK is signed by a different certificate.

The workflows pass the Supabase and Google values with `--dart-define`. CI
decodes the authoritative `KEYSTORE_BASE64` secret into
`android/app/bitaqati.p12` (falling back to the committed `bitaqati.p12`) and
writes `android/key.properties` from the password secrets. On a non-PR build
it refuses to publish when release signing is not configured, rather than
shipping a debug-signed APK that cannot authenticate.

The build pipeline in order: `flutter pub get` → `dart run build_runner
build --delete-conflicting-outputs` (Drift code generation, since `*.g.dart`
is git-ignored) → `dart run flutter_launcher_icons` → signing setup →
`flutter analyze` → `flutter build apk`.

## Google Sign-In (Android)

Native Google Sign-In only works when all of these agree:

1. **Application id** — `com.bitaqati.app` (`namespace` and `applicationId` in
   `android/app/build.gradle.kts`). It must match the package of the Android
   OAuth client in Google Cloud.
2. **Signing certificate SHA-1** — the certificate inside `bitaqati.p12`, the
   keystore used by CI. It must be registered on the same Android OAuth
   client.
3. **Server client id** — the **Web** client id
   `610940162017-ohe2ei9dkkj96cai8gqu0i2jmgbspd8b.apps.googleusercontent.com`.
   The app passes it to `GoogleSignIn.instance.initialize(serverClientId: ...)`.
   Never use the Android client id here: it cannot issue an ID token for
   Supabase.

### Google Cloud Console

- **Web application** OAuth client → its client id is the Web client id above;
  its secret is pasted into Supabase.
- **Android** OAuth client → package `com.bitaqati.app` and the release
  certificate SHA-1. Add the debug certificate SHA-1 as well if you test with
  `flutter run`.

### Supabase dashboard

- **Authentication → Providers → Google** must be enabled.
- **Client ID**: list the Web client id first, followed by the Android client
  id(s), comma-separated. Supabase requires the Web client id to be first.
- **Client Secret**: the Web client secret.
- **Authorized Client IDs**: every native client id used to obtain ID tokens.
- **Site URL** may remain `com.bitaqati.app://login-callback`; the native flow
  does not use a browser redirect.
- Leave **Skip nonce check** off for Android.

The current remote values can be inspected with the Supabase Management API
(`GET /v1/projects/mftghnvtdryxzochquee/config/auth`). The Google provider is
enabled, the Web id is first in `external_google_client_id`, and the Android id
follows it. That response also contains the Google client secret; never paste
the raw response into logs or issues.

### Obtaining and checking SHA-1

```bash
# From the release keystore (prompts for its password)
keytool -list -v -keystore bitaqati.p12 -storetype PKCS12 | grep -i SHA1

# From a built APK (prints the actual signer)
"$ANDROID_HOME/build-tools/<version>/apksigner" verify --print-certs \
  app-release.apk | grep "SHA-1"

# Debug keystore used by flutter run
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android | grep -i SHA1
```

The CI **Verify APK signer** step prints the built APK's SHA-1. Compare it
with the value registered in Google Cloud, or set `ANDROID_CERT_SHA1` to make
CI enforce it.

### Symptom → cause

| Symptom | Likely cause |
|---|---|
| Account picker closes immediately / `canceled` | Package or SHA-1 mismatch; Google rejects the Android client before returning a token |
| Access blocked / canceled only for one account | OAuth consent screen is in Testing and that account is not a test user |
| `clientConfigurationError` / `ApiException: 10` | The APK is not signed with the registered certificate, or the package is wrong |
| `idToken` is null | `serverClientId` is not the Web client id |
| Supabase `AuthException` about provider/token | Google client id list or client secret in Supabase is wrong |

`AuthService` logs a `[GoogleAuth]` line for the effective `serverClientId`,
whether the ID token exists, and the token's non-secret `aud`/`azp` claims.
Tokens themselves are never logged. Read them with `adb logcat` or
`flutter logs`.

## Android signing

`android/app/build.gradle.kts` reads `android/key.properties` (git-ignored) and
signs release builds with `bitaqati.p12`. CI creates both from the keystore and
the `KEYSTORE_*` secrets.

Local release build:

```bash
cp bitaqati.p12 android/app/bitaqati.p12
cat > android/key.properties <<'EOF'
storePassword=...
keyPassword=...
keyAlias=...
storeFile=bitaqati.p12
EOF
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

Never commit `android/key.properties`.

The repository also contains `bitaqati.p12` (and a base64 copy) as a CI
fallback. Treat the keystore as a secret: rotate it and register the new
SHA-1 in Google Cloud before a public release.

`flutter run` uses the local debug keystore, which has a different SHA-1. Add
that SHA-1 to the Android OAuth client too, or install a release-signed APK
when testing Google Sign-In.

### Package rename

The application id changed from `app.bitaqati.cards` to `com.bitaqati.app` to
match the registered OAuth client (and the Supabase redirect scheme). Android
treats it as a different app: uninstall the old build before installing the
new one; its local data is not migrated.

## Database migrations

The SQL is committed in `supabase/migrations/` and applied in filename order:

| File | Scope |
|---|---|
| `20261025000100_initial_schema.sql` | Profiles, subjects, decks, cards, card states, review logs, ratings, reports |
| `20261025000200_hardening.sql` | RLS policies, indexes, trigger functions |
| `20261025000300_phase1_nested_content.sql` | Legacy nesting columns and `parent_id` cascade |
| `20261027000100_library_usage_and_ratings.sql` | `install_count` and `deck_ratings` aggregation |
| `20261027000100_phase_c_depth_limit.sql` | Legacy depth constraint |
| `20261027000300_card_media_storage.sql` | Storage bucket and policies for card media |
| `20261027000400_deck_share_codes.sql` | `share_code`, `new_share_code()`, uniqueness trigger, `resolve_share_code()` |
| `20261027000500_profile_and_attribution.sql` | `decks.original_deck_id`, `decks.original_author_name`, `profiles.display_name_custom`, `profiles_insert_own`, flat `public_decks` |

Apply with the Supabase CLI:

```bash
supabase link --project-ref mftghnvtdryxzochquee
supabase db push
```

Or run a single statement through the Management API:

```bash
curl -X POST \
  "https://api.supabase.com/v1/projects/mftghnvtdryxzochquee/database/query" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary @query.json   # {"query": "select 1"}
```

A multi-statement request returns only the **last** result set, so read
earlier results with separate calls.

### What the client must never write

The cloud `decks` table still carries `parent_id`, `root_id`, `path` and
`depth` from the nested era. They are legacy and unused: the client never
sends them, and `public_decks` does not expose them. Writing to them from a
new build would re-introduce a hierarchy the app no longer understands.

## Share codes

No configuration is required — codes are generated on the device and
de-duplicated by the database. Two things are worth knowing:

- The alphabet is `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (31 characters, no vowels,
  no `0`/`O`/`1`/`I`/`L`) and the format is enforced by the
  `decks_share_code_format` CHECK constraint.
- `resolve_share_code(p_code text)` is `security definer` and returns only
  `(id, title, card_count)` for `public` or `unlisted` decks. Keep it that way:
  widening the return type would leak private metadata to anyone who guesses a
  code.

## Third-party packages added for these features

| Package | Used by |
|---|---|
| `url_launcher` | Developer info screen: mail, WhatsApp, Telegram, Instagram. Update dialog: opening the APK download. |
| `package_info_plus` | Update service: reading the installed version from the APK |
| `http` | Update service: `GET /repos/7sn-17/bitaqati/releases/latest` |

No keys or platform configuration are needed for any of them on Android. On
iOS `url_launcher` requires the `LSApplicationQueriesSchemes` entries for
`mailto`, `https` and `tg`.

## APK

Every push to `main` that touches `lib/`, `assets/`, `android/` or
`pubspec.yaml` builds, signs and publishes a GitHub Release. The release tag is
read from `pubspec.yaml`, so `version: 1.0.0+1` produces the tag `v1.0.0`.

The arm64 build is attached under a fixed name, which is the URL the in-app
updater uses and the one to hand to users:

```
https://github.com/7sn-17/bitaqati/releases/latest/download/bitaqati.apk
```

The same release also carries the per-ABI files
`bitaqati-v<version>-arm64-v8a.apk`, `-armeabi-v7a.apk` and `-x86_64.apk`,
plus a `bitaqati-apks` workflow artifact for 30 days:

```bash
gh release download --repo 7sn-17/bitaqati --pattern 'bitaqati.apk' -D ./dist
```

Install on a connected Android device:

```bash
adb install -r ./dist/bitaqati.apk
```

Bumping the version publishes a new release, and because `make_latest: true`
is set, `/releases/latest` moves with it. Nothing else in the pipeline has to
change.

The one thing a maintainer must do for each version is add a section to
`CHANGELOG.md` headed `## <version>`. The release step cuts that section out
and uses it as the release body, which is exactly what the in-app update dialog
shows under "ما الجديد" — so write it for a user, one bullet per line, and never
list APK file names. If the section is missing the release still publishes, but
the dialog falls back to a single generic line.

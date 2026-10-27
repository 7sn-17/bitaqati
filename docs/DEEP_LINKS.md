# Deep links and deck sharing

## Link format

```
https://bitaqati.app/deck/<deck-id>
```

The id is the deck UUID, identical locally and in Supabase, so a link can be
opened before and after the recipient installs the deck.

The legacy `bitaqati://deck/<deck-id>` scheme is still accepted by
`AppConfig.deckIdFromShareLink`, so links shared by older builds keep working.
New links are always HTTPS.

## What has to exist outside this repository

1. **Android App Links** — `https://bitaqati.app/.well-known/assetlinks.json`
   must list `com.bitaqati.app` with the SHA-256 of the release certificate.
   Get it with:

   ```bash
   keytool -list -v -keystore android/app/bitaqati.p12 \
     -alias <alias> -storepass <password> | grep SHA256
   ```

   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.bitaqati.app",
       "sha256_cert_fingerprints": ["<SHA256>"]
     }
   }]
   ```

2. **Web preview** — the `deck-share` edge function renders the Open Graph page
   and redirects to the store:

   ```bash
   supabase functions deploy deck-share --no-verify-jwt
   ```

   Set `PLAY_STORE_URL` if the package name ever changes.

   > **Gateway caveat.** Supabase serves every function response as
   > `text/plain` with `content-security-policy: default-src 'none'; sandbox`
   > to stop projects using `*.supabase.co` for phishing, so the HTML body is
   > correct but browsers will not render it. Put a tiny proxy in front —
   > a Cloudflare Worker or Pages route on `bitaqati.app/deck/*` that forwards
   > to `https://<ref>.supabase.co/functions/v1/deck-share/deck/<id>` and
   > rewrites the content type — or host a static page that links to the app
   > and the store. Crawlers only need the Open Graph tags, which are present
   > either way.

3. **iOS Universal Links** (when an iOS build exists) — `apple-app-site-association`
   at the same host, plus the Associated Domains capability.

## Behaviour in the app

```text
link tapped
  ├─ app installed  → app_links stream → router.push('/deck/<id>')
  └─ not installed  → web preview → Play Store
```

If the link arrives before onboarding or sign-in finishes, the id is stored
under `AppConfig.pendingDeckKey` and replayed afterwards.

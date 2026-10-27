# Deep links and sharing

A deck can be shared two ways. The share code is the primary one because it
works without a domain, without an installed app, and over a phone call.

## Share code

Every deck has a six-character code from the moment it is created:

```text
A7K2M9
```

The alphabet is `23456789ABCDEFGHJKMNPQRSTUVWXYZ` — no vowels, so a code
cannot accidentally spell a word, and no `0`, `O`, `1`, `I` or `L`, so it
cannot be misread out loud. That leaves 31 characters, or about 887 million
combinations at six digits.

### Receiving a code

The library header has a `#` button. It asks for six characters, then tries
two lookups in order:

```text
code entered
  ├─ local deck with that code   → open it directly, no network
  └─ resolve_share_code RPC      → fetch the deck and open a preview
```

The local check runs first so a code you generated on this device opens even
in airplane mode.

`resolve_share_code` returns `(id, title, card_count)` and only for decks whose
privacy is `public` or `unlisted`. A private deck's code resolves to nothing,
so a leaked code cannot expose an unpublished deck.

### Copying a code

The deck screen's overflow menu has **نسخ رمز المشاركة** and the privacy card
shows the code with its own copy button. The code is stored locally, so it is
available before the deck is ever published — the server only confirms it
during the first publish, and may replace it if another account already
claimed the same string.

## Link format

```text
https://bitaqati.app/deck/<deck-id>
```

The id is the deck UUID, identical locally and in Supabase, so a link keeps
working before and after the recipient installs the deck.

The legacy `bitaqati://deck/<deck-id>` scheme is still accepted by
`AppConfig.deckIdFromShareLink`, so links shared by older builds keep working.
New links are always HTTPS.

## What has to exist outside this repository

1. **Android App Links** — copy `docs/assetlinks.json` to
   `https://bitaqati.app/.well-known/assetlinks.json` and serve it as
   `application/json`. It carries the release fingerprint:

   ```text
   SHA-256  19:E4:6F:09:DE:25:39:0E:E2:96:A0:91:9A:8B:2B:DA:BF:6F:CA:94:82:FC:B0:94:F5:2D:BA:81:BE:D2:C3:FA
   SHA-1    3E:49:76:21:2F:89:7E:C9:A0:0C:3F:1E:80:43:58:C7:32:EB:F0:C0
   ```

   Both come from the certificate inside the release keystore. To re-derive
   them without the keystore password, read the certificate out of a signed
   APK:

   ```bash
   keytool -printcert -jarfile app-arm64-v8a-release.apk
   ```

   If the keystore is ever replaced, update this file **and** the SHA-1 in
   Google Cloud Console, then re-verify with:

   ```bash
   adb shell pm verify-app-links --re-verify com.bitaqati.app
   ```

2. **Web preview** — the `deck-share` edge function renders the Open Graph
   page and redirects to the store:

   ```bash
   supabase functions deploy deck-share --no-verify-jwt
   ```

   Set `PLAY_STORE_URL` if the package name ever changes.

   > **Gateway caveat.** Supabase serves every function response as
   > `text/plain` with `content-security-policy: default-src 'none'; sandbox`
   > to stop projects using `*.supabase.co` for phishing, so the HTML body is
   > correct but browsers will not render it. Put a tiny proxy in front — a
   > Cloudflare Worker or Pages route on `bitaqati.app/deck/*` that forwards
   > to `https://<ref>.supabase.co/functions/v1/deck-share/deck/<id>` and
   > rewrites the content type — or host a static page that links to the app
   > and the store. Crawlers only need the Open Graph tags, which are present
   > either way.

3. **iOS Universal Links** (when an iOS build exists) —
   `apple-app-site-association` at the same host, plus the Associated Domains
   capability.

## Behaviour in the app

```text
link tapped
  ├─ app installed  → app_links stream → router.push('/deck/<id>')
  └─ not installed  → web preview → Play Store
```

If the link arrives before onboarding or sign-in finishes, the id is stored
under `AppConfig.pendingDeckKey` and replayed afterwards.

## Installing versus remixing

Opening a deck from a code or a link shows a preview. Installing it
deep-copies the content: new ids, positions from zero, and no scheduling
state.

The copy remembers where it came from:

| Field | Written when |
|---|---|
| `source_deck_id` | The deck the copy was installed from |
| `original_deck_id` | The first deck in the chain, inherited on re-remix |
| `original_author_name` | The original author's display name at install time |

If you then publish your edited copy, it appears in the library with a
**مقتبسة من …** badge. The credit is a stored value, not a join, so it survives
the original being unpublished or deleted.

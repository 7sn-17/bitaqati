# Architecture

## Product principles

1. **Offline-first.** Studying must work on a plane, in a basement, or on a weak connection.
2. **One source of truth for content.** The five subject names and colours are identical in the app and in Supabase.
3. **Speed over chrome.** Navigation is instant; review actions are one tap.
4. **AI assists, never blocks.** A review session never waits for a model.
5. **Private by default.** Decks are private until the owner explicitly publishes them.

## Stack

| Layer | Choice | Why |
|---|---|---|
| UI | Flutter + Material 3, Cupertino motion | One codebase, native-feeling Android, future iOS |
| State | Riverpod | Testable, no BuildContext dependency |
| Routing | go_router + StatefulShellRoute | Persistent tab state per branch |
| Local DB | Drift + SQLite (Phase 1) | Typed SQL, migrations, offline queries |
| SRS | FSRS (Phase 1) | Better retention per review than SM-2 |
| Cloud | Supabase Postgres + Auth + Storage + Edge Functions | Managed Postgres, RLS, cheap start |
| AI | Supabase Edge Function → provider API | Keys stay server-side |
| CI/CD | GitHub Actions | Reproducible APK builds, no local Android SDK required |

## Navigation

```
/onboarding
└── /home                  (tab 1)
├── /decks                 (tab 2)
│   └── /deck/:id
│       └── /review/:id
├── /library               (tab 3)
├── /progress              (tab 4)
├── /settings
└── /search
```

The shell uses `StatefulShellRoute.indexedStack`; tabs keep their scroll and
form state. The centre create button opens a modal sheet, it is not a fifth
branch. Detail, review, settings, and search are pushed on the root navigator so
the tab bar disappears during focused tasks.

## Offline-first data flow

```
UI → Riverpod controller → repository
                              ├── Drift (local, authoritative for study)
                              └── Supabase (sync + public library)
```

- A card review writes to Drift first and returns immediately.
- A sync queue records changed entities (`decks`, `cards`, `card_states`,
  `review_logs`) with an operation id.
- The sync worker pushes in order when connectivity returns, then pulls remote
  changes newer than the last cursor.
- Conflicts are resolved per entity with `updated_at` plus a device id; review
  logs are append-only and never conflict.
- Public library decks are pulled into local storage as immutable snapshots with
  `source_deck_id` and `source_version`. A subscriber can pull updates or detach.

## Local schema (Phase 1)

```
subjects(id, name_ar, name_en, color, icon, sort_order)
decks(id, subject_id, title, description, privacy, settings_json, updated_at, deleted_at)
cards(id, deck_id, type, front, back, notes, tags, media_json, position, updated_at, deleted_at)
card_states(card_id, due, stability, difficulty, elapsed_days, scheduled_days,
            learning_steps, reps, lapses, state, last_review)
review_logs(id, card_id, rating, reviewed_at, elapsed_ms, prev_state_json, next_state_json)
sync_queue(id, entity, entity_id, operation, payload_json, created_at, attempts)
```

## FSRS review engine

The scheduler is seeded in Phase 1 behind a pure Dart interface:

```dart
abstract interface class Scheduler {
  CardState review({
    required CardState current,
    required Rating rating,
    required DateTime now,
  });
}
```

Rules:

- Ratings: `1 again`, `2 hard`, `3 good`, `4 easy`.
- Desired retention default: 90%.
- New cards are introduced up to a daily limit (default 10).
- Review logs are immutable; state is derived and can be rebuilt.
- A leech is a card with 8+ lapses; it is surfaced for rewriting.
- Timezone is applied at the session level, not stored per card.

## Cloud schema

The initial migration creates:

- `profiles`, `user_settings` (auto-created on signup)
- `subjects` with the exact five subjects
- `decks`, `cards`, `card_states`, `review_logs`
- `ai_jobs`
- `deck_ratings`, `deck_reports`, `deck_subscriptions`
- `public_decks` view with author, rating, and card count

All user tables have RLS. Public read is limited to `decks.privacy = 'public'`
(or `unlisted` by direct link). Cards inherit the visibility of their deck.

## AI pipeline

1. Client uploads a source (PDF/image/text) to a private Storage bucket.
2. Client inserts an `ai_jobs` row (status `queued`).
3. An Edge Function claims the job, extracts text, calls the provider with a
   strict JSON schema, validates the cards, and writes a draft deck.
4. Client subscribes to the job row; the user reviews generated cards before
   saving.
5. Provider keys live only in Edge Function secrets.

The AI never writes directly to a user's study deck without confirmation.

## Security checklist

- [x] RLS on every user table.
- [x] No service role key in the client.
- [x] Publishable key alone is shipped (safe by design).
- [x] Public library requires explicit `privacy = 'public'`.
- [ ] Storage bucket policies (Phase 2).
- [ ] Rate limiting on AI jobs and auth (Phase 2).
- [x] Release signing with `bitaqati.p12`; passwords live in GitHub Secrets.
- [ ] Remove the committed keystore from the repository and rotate it (with a
  new Google Cloud SHA-1) before a public release.

## Deployment

- Android package: `com.bitaqati.app`.
- Supabase project ref: `mftghnvtdryxzochquee` (region `eu-central-1`).
- APK artifacts are produced by GitHub Actions and signed with `bitaqati.p12`;
  see `docs/CONFIGURATION.md` for the Google/Supabase client setup.

## Roadmap

| Phase | Scope |
|---|---|
| 0 | Foundation, navigation, design system, cloud schema, APK pipeline |
| 1 | Drift, FSRS, deck/card editor, import, stats, notifications |
| 2 | Auth, sync, public library, deck copy/update, storage |
| 3 | AI import pipeline, review queue, moderation |
| 4 | iOS, web, localization, subscription, analytics |

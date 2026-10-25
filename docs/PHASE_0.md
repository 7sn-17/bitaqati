# Phase 0 — Completion Record

## Delivered

- GitHub repository: <https://github.com/7sn-17/bitaqati> (private, `main`).
- Supabase project: `bitaqati` / `mftghnvtdryxzochquee` / `eu-central-1` / Free.
- Flutter Android package: `com.bitaqati.app` (renamed from `app.bitaqati.cards`
  in the Phase 1 infrastructure checkpoint).
- First installable APK: <https://github.com/7sn-17/bitaqati/releases/tag/v0.1.1-phase0>.
- CI: `Build Android APK` on every push to `main`; `Release APK` on `v*` tags.

## App surface in this phase

| Screen | Status |
|---|---|
| Onboarding (3 pages) | Complete |
| Home | Complete with daily review hero, subject filters, deck list |
| Decks | Complete with search and filters |
| Deck detail | Complete with cards, stats placeholder, settings placeholder |
| Review | Complete demo flow, reveal, ratings, session summary |
| Library | Complete public-library shell, subject tiles, add-copy action |
| Progress | Complete with retention, heatmap, forecast, subject bars |
| Settings | Complete with light/dark mode, notification toggle, sections |
| Search | Complete across decks and cards |
| Create sheet | Complete UI; actions intentionally show "next phase" |

## Database

Applied migrations:

1. `20261025000100_initial_schema.sql`
2. `20261025000200_hardening.sql`

Tables: `profiles`, `user_settings`, `subjects`, `decks`, `cards`,
`card_states`, `review_logs`, `ai_jobs`, `deck_ratings`, `deck_reports`,
`deck_subscriptions`. View: `public_decks`.

The five subjects are seeded with the exact approved Arabic names. All security
advisors are clean; only unused-index notices remain because the tables are
empty.

## Verification

- `flutter analyze` passes on Flutter `3.47.8`.
- `flutter build apk --release` passes in GitHub Actions.
- Security advisor: 0 findings.
- Performance advisor: unused indexes only (expected at zero traffic).

## What is deliberately not in Phase 0

- Drift/SQLite local database and FSRS scheduler.
- Deck/card editor and import pipeline.
- Supabase Auth, sync, and storage.
- AI generation.
- Real starter card content beyond demo cards.
- Release keystore (APK currently uses the debug key, installable but not
  Play-ready).

## Next phase (Phase 1)

1. Add Drift schema and migrations.
2. Port the FSRS scheduler with unit tests.
3. Wire review sessions to local storage and real due counts.
4. Build deck/card editor and text import.
5. Add notification scheduling.
6. Replace demo data with the professional starter decks.

Phase 2 then adds Auth, sync, public library persistence, and storage. Phase 3
adds the AI job pipeline.

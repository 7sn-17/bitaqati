# Phase 0 — foundation record

This file records the state of the project at the end of Phase 0. It is kept
for history; the app has moved well past it. For how the app works today, read
`docs/ARCHITECTURE.md`.

## Delivered

- GitHub repository: <https://github.com/7sn-17/bitaqati> (private, `main`).
- Supabase project: `bitaqati` / `mftghnvtdryxzochquee` / `eu-central-1` / Free.
- Flutter Android package: `com.bitaqati.app`.
- First installable APK: <https://github.com/7sn-17/bitaqati/releases/tag/v0.1.0-phase0>.
- CI: `Build Android APK` on every push to `main`; `Release APK` on `v*` tags.

## App surface at the time

| Screen | Status then |
|---|---|
| Onboarding | Three pages, complete |
| Home | Daily review hero, filters, deck list |
| Decks | Search and filters |
| Deck detail | Cards, stats placeholder |
| Review | Demo flow: reveal, ratings, summary |
| Library | Public-library shell |
| Progress | Retention, heatmap, forecast |
| Settings | Theme, notification toggle |
| Search | Decks and cards |
| Create sheet | UI only; actions were placeholders |

## Database then

Migrations applied at the end of Phase 0:

1. `20261025000100_initial_schema.sql`
2. `20261025000200_hardening.sql`

Tables: `profiles`, `user_settings`, `subjects`, `decks`, `cards`,
`card_states`, `review_logs`, `ai_jobs`, `deck_ratings`, `deck_reports`,
`deck_subscriptions`. View: `public_decks`.

The schema at that point still modelled decks as a tree with a hardcoded
subject list. Both are gone now; see below.

## Verification

- `flutter analyze` passed on Flutter `3.47.8`.
- `flutter build apk --release` passed in GitHub Actions.
- Security advisor: 0 findings.

## What was deliberately missing

- Drift/SQLite local database and the FSRS scheduler.
- Deck and card editors, import pipeline.
- Supabase Auth, sync, storage.
- AI generation.
- Real starter content beyond demo cards.

## What has shipped since

### Content model

Decks were flattened. There are no sub-decks, no root deck, no `path` or
`depth`: a deck owns its cards directly, and `decks.share_code` replaced the
whole nesting apparatus. The five hardcoded subjects were replaced by
free-form tags.

### Study engine

Drift (schema version 5) is the authoritative store, FSRS schedules every
card, review logs are immutable, and the daily new/review limits are
adjustable in Settings.

### Accounts and sync

Google sign-in through Supabase Auth, guest mode for browsing without an
account, and a two-way `SyncService` that drains a local queue and then pulls
remote changes with last-write-wins conflict resolution.

### Community

A public library with install counts and star ratings, six-character share
codes, deep links, and permanent attribution for remixes.

### Profile and legal

An editable display name that overrides the Google name everywhere and
survives a reinstall, a privacy policy and terms of service inside the app,
and a developer contact screen.

## Where to read next

| Question | File |
|---|---|
| How is the code organised? | `docs/ARCHITECTURE.md` |
| How do I build and configure it? | `docs/CONFIGURATION.md` |
| How does sharing work? | `docs/DEEP_LINKS.md` |

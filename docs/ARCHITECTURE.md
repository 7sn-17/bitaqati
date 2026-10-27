# Architecture

## Product principles

1. **Offline first.** Studying works on a plane, in a basement, or on a weak
   connection. The local database is the copy the app reads from.
2. **One shape for content.** A deck is a flat list that owns its cards. There
   are no sub-decks, no trees, and no special root deck.
3. **Speed over chrome.** Navigation is instant; a review action is one tap.
4. **Private by default.** A deck is private until its owner publishes it.
5. **Attribution is permanent.** A copied deck always credits the person who
   wrote the original, even after the original is deleted.

## Stack

| Layer | Choice | Why |
|---|---|---|
| UI | Flutter + Material 3, Cupertino motion | One codebase, native-feeling Android |
| State | Riverpod | Testable, no BuildContext dependency |
| Routing | go_router + StatefulShellRoute | Persistent tab state per branch |
| Local DB | Drift + SQLite | Typed SQL, migrations, offline queries |
| SRS | FSRS | Better retention per review than SM-2 |
| Cloud | Supabase Postgres + Auth + Storage | Managed Postgres, RLS, cheap start |
| CI/CD | GitHub Actions | Reproducible APK builds, no local Android SDK required |

## Navigation

```text
/onboarding
/login
/home                      (tab 1)
/decks                     (tab 2)
/library                   (tab 3)
/progress                  (tab 4)

/deck/:id                  root navigator
/review/:id                root navigator
/create-card               root navigator
/edit-card/:id             root navigator
/import-cards/:deckId      root navigator
/draft-card                root navigator, draft passed in memory
/search                    root navigator
/settings                  root navigator
/developer                 root navigator
/privacy                   root navigator
/terms                     root navigator
```

The shell uses `StatefulShellRoute.indexedStack`, so each tab keeps its
scroll position and form state. The centre create button opens a modal
sheet, it is not a fifth branch. Everything else is pushed on the root
navigator so the tab bar disappears during a focused task.

The legal pages are also reachable from the login and onboarding footers.
Those two screens cannot use `context.push`: the router redirects anyone who
is not signed in back to `/login`, which would bounce the user straight back
where they started. `openLegalPage` pushes a `MaterialPageRoute` instead.

## Data flow

```text
UI → Riverpod provider → repository → Drift (authoritative for study)
                                    └→ sync_queue → Supabase (backup + library)
```

Every local write happens first and returns immediately. The repository also
appends a row to `sync_queue` in the same transaction, so a change can never
be stored without a matching intent to push it.

`SyncService` runs on app start and whenever the signed-in user changes:

1. **Push.** Drain `sync_queue` in insertion order, grouped by entity and
   ordered `decks → cards → card_states → review_logs` so a parent always
   exists before its children.
2. **Pull.** Fetch the account's rows and apply last-write-wins on
   `updated_at`, skipping any row that still has a pending queue entry.
3. **Profile.** Adopt a display name chosen on another device.

A queue row that fails five times is dropped rather than blocking the queue
forever; its `last_error` is kept for diagnosis.

## Local schema (Drift v5)

```text
profiles(user_id PK, display_name, updated_at)
decks(id PK, owner_id, share_code, position, title, description, color_hex,
      icon, privacy, cover_url, tags, settings, is_starter, source_deck_id,
      original_deck_id, original_author_name, source_version, forked_at,
      published_at, created_at, updated_at, deleted_at)
cards(id PK, deck_id FK→decks CASCADE, type, front, back, notes, hint, tags,
      media, occlusion, source, ai_generated, favorite, position,
      created_at, updated_at, deleted_at)
card_states(card_id PK FK→cards CASCADE, status, due, stability, difficulty,
            elapsed_days, scheduled_days, learning_steps, reps, lapses,
            last_review, updated_at)
review_logs(id PK, card_id FK→cards CASCADE, rating, reviewed_at, elapsed_ms,
            scheduled_days, stability, difficulty, prev_state, next_state)
sync_queue(id PK, entity, entity_id, operation, payload, created_at,
           attempts, last_error)
sync_meta(key PK, value)
```

Foreign keys are enforced (`PRAGMA foreign_keys = ON` in `beforeOpen`) and
every child relationship is `ON DELETE CASCADE`.

### Migrations

| Version | Change |
|---|---|
| 3 | `cards.favorite` |
| 4 | Flattened `decks`: dropped `parent_id`, `root_id`, `path`, `depth`; added `share_code` |
| 5 | Added `profiles`; added `decks.original_deck_id` and `decks.original_author_name` |

Version 4 rebuilds the table with `TableMigration`, which copies every column
that still exists, so existing decks and their cards survive the flattening.

## Smart import

Pasting a wall of text is how most people already have their material, so the
import flow turns it into cards instead of asking for them one by one.

```text
Front | Back
Front | Back | Hint
Front | Back | Hint | Note
```

- One card per line. A line with no pipe, or with an empty front or back, is
  counted and skipped rather than guessed at.
- A backslash before a pipe (`\|`) keeps the pipe inside the field.
- Extra separators are folded into the note so no text is lost.

The screen has two states: paste, then preview. Nothing is written until the
user presses save. Tapping a draft pushes `/draft-card` with the draft in
`extra` and `collectOnly: true`, which runs the real editor — formatting,
occlusion, tags — and returns the edited `CardDraft` instead of persisting it.
Saving the batch goes through `ContentRepository.addCards`, one transaction and
one queue row per card, so a failure cannot leave half a deck behind.

## Deleting a deck

`ContentRepository.deleteDeck` removes the deck, its cards, their
`card_states`, their `review_logs` and every queued entry that mentions any of
those ids — in one transaction, in that order. It then queues a single `decks`
delete.

The queue purge matters: the queue has no foreign key to the deck, so a
pending `upsert` left behind would push the deck back to the server and it
would reappear on the next pull. Enqueuing the delete last keeps it from being
swept away by that purge.

On the server the same delete cascades: `cards.deck_id`, `card_states.card_id`
and `review_logs.card_id` are all `ON DELETE CASCADE`, so removing the deck row
takes the rest with it. `decks.original_deck_id` and `decks.source_deck_id`
are `ON DELETE SET NULL`, because deleting an original must never delete the
remixes made from it.

## Share codes

Every deck gets a six-character code the moment it is created, before it is
ever published, so it can be handed to a friend offline.

```text
alphabet: 23456789ABCDEFGHJKMNPQRSTUVWXYZ   (31 chars, no vowels, no 0/O/1/I/L)
```

Uniqueness is enforced in two places:

- **Locally**, `_freshShareCode` retries until the code is unused by any live
  deck on the device.
- **In the cloud**, a `BEFORE INSERT OR UPDATE` trigger regenerates the code if
  another account already claimed it, backed by a unique index on
  `upper(share_code)`.

After publishing, the client reads `share_code` back from the server and
stores whatever the server settled on, so the two can never disagree.

`resolve_share_code(p_code)` is a `security definer` RPC that returns only
`(id, title, card_count)` and only for `public` or `unlisted` decks. It never
leaks the owner, the settings, or a private deck.

## Public library and remixes

`public_decks` is a flat view: one row per published deck, joined to
`profiles` for `author_name` and aggregated against `deck_ratings` for the
star average. It carries no nesting columns.

Installing a deck deep-copies it: new deck id, new card ids, positions
renumbered from zero, and scheduling state deliberately left empty so the
copy starts fresh. Three fields record the lineage:

| Column | Meaning |
|---|---|
| `source_deck_id` | The deck this copy was installed from |
| `original_deck_id` | The first deck in the remix chain |
| `original_author_name` | Display name of that original author, captured at install time |

`original_deck_id` and `original_author_name` are inherited, not recomputed:
a remix of a remix still credits the person who wrote the first version. The
name is copied rather than joined so the credit survives the original being
unpublished or deleted. The UI shows a **مقتبسة من …** badge on the library
card and an attribution panel on the deck screen.

## Display name

`profiles.display_name` in Supabase is what the public library shows as the
author. Google owns that value until the user overrides it.

A rename writes to the local `profiles` table first, then pushes
`{id, display_name, display_name_custom: true}`. The flag is what makes the
value authoritative:

- `DisplayNameController` prefers the local name and falls back to the Google
  name, so every screen shows the same thing.
- `ProfileRepository.pullFromCloud` only adopts a remote name when
  `display_name_custom` is true **and** the remote `updated_at` is newer.

The local row is keyed by user id, so a rename survives a sign-out, a
reinstall, and an offline session.

The library never stores the name. `public_decks.author_name` is
`profiles.display_name` joined at query time, so a rename changes the credit on
every deck that account ever published, in the same statement, with no backfill
and nothing that can drift. Three details keep that promise:

- `profiles_normalise_name` trims and collapses whitespace, and refuses to let a
  blank name through, because one empty row would blank the author on every
  published deck at once.
- `SyncService` calls `ProfileRepository.syncToCloud` before pulling, so a
  rename made offline still reaches the library on the next connection. It only
  pushes when the cloud copy is not newer, which keeps two devices from
  fighting.
- `DisplayNameController` invalidates the cached library catalog after a rename,
  so the user sees the new name without restarting the app.

## FSRS review engine

```dart
abstract interface class Scheduler {
  CardState review({
    required CardState current,
    required Rating rating,
    required DateTime now,
  });
}
```

- Ratings: `1 again`, `2 hard`, `3 good`, `4 easy`.
- Desired retention default: 90%.
- New cards are introduced up to a daily limit (default 10, adjustable in
  Settings from 0 to 200 in steps of 5).
- Reviews per session default to 200, adjustable from 20 to 1000.
- Review logs are immutable; state is derived and can be rebuilt.
- A leech is a card with 4+ lapses; it is surfaced for rewriting.

## Cloud schema

Migrations live in `supabase/migrations/` and are applied in filename order:

| File | Scope |
|---|---|
| `20261025000100_initial_schema.sql` | Profiles, subjects, decks, cards, states, logs, ratings, reports |
| `20261025000200_hardening.sql` | RLS, indexes, trigger functions |
| `20261025000300_phase1_nested_content.sql` | Legacy nesting columns, unused by the client |
| `20261027000100_library_usage_and_ratings.sql` | Install counts and star ratings |
| `20261027000100_phase_c_depth_limit.sql` | Legacy depth constraint |
| `20261027000300_card_media_storage.sql` | Storage bucket for card media |
| `20261027000400_deck_share_codes.sql` | `share_code`, generator, uniqueness trigger, `resolve_share_code` |
| `20261027000500_profile_and_attribution.sql` | Attribution columns, profile insert policy, flat `public_decks` |

Every user table has RLS. The client only ever ships the publishable key.

## Security checklist

- [x] RLS on every user table.
- [x] No `service_role` key in the client.
- [x] Public read limited to `privacy = 'public'`.
- [x] Share-code resolution exposed as a narrow `security definer` RPC.
- [x] Profiles can only be written by their owner.
- [x] Release signing with `bitaqati.p12`; passwords live in GitHub Secrets.
- [ ] Rotate the committed keystore and register the new SHA-1 before a public release.

## Deployment

- Android package: `com.bitaqati.app`.
- Supabase project ref: `mftghnvtdryxzochquee` (region `eu-central-1`).
- APKs are built and signed by GitHub Actions; see `docs/CONFIGURATION.md`.

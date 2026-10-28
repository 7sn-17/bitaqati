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

`SyncService` runs on app start, when the signed-in user changes, when the
radio comes back after being offline, when the app returns to the foreground,
and when the user asks for it. There is no timer: an idle app never wakes the
radio to poll a queue that is almost always empty.

1. **Push.** Drain `sync_queue` in insertion order, grouped by entity and
   ordered `decks → cards → card_states → review_logs` so a parent always
   exists before its children.
2. **Pull.** Fetch the account's rows and apply last-write-wins on
   `updated_at`, skipping any row that still has a pending queue entry.
3. **Profile.** Adopt a display name chosen on another device.

A queue row that fails five times is dropped rather than blocking the queue
forever; its `last_error` is kept for diagnosis.

## Local schema (Drift v6)

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
            last_review, fsrs_version, updated_at)
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
| 6 | Added `card_states.fsrs_version` (local-only) |

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

## Images: pick, crop, compress, upload

Every picture in the app goes through `MediaUploadService.pickImage`, and that
one function owns the whole path.

```text
ImagePicker.pickImage
  -> cropImage(File)        // lib/core/media/image_crop.dart
  -> compressImage(File)    // lib/core/media/image_compress.dart
  -> POST /functions/v1/upload-image
  -> PickedMedia(url)
```

Each step has to happen before the next one exists. Cropping decides what the
card shows; compressing decides how many bytes travel; uploading sends exactly
that. Uploading first would leave the full frame at full resolution in storage
forever, and fixing it afterwards would need a second round trip to replace it.

`cropImage` returns null when the learner backs out — a cancel means "do not
attach this", not "attach it uncropped" — and returns the original file when
the platform has no cropper or refuses the file, because losing the picture is
worse than keeping it uncropped.

`compressImage` caps the longest edge at `kImageMaxEdge` (1600px) and
re-encodes as JPEG at `kImageQuality` (85). It reads the encoded width and
height from the image header with `ui.ImageDescriptor`, so a twelve-megapixel
photo is never decoded just to learn two integers. The aspect ratio is never
touched: the picture is scaled as a whole, never cropped and never stretched.

The plugin's own `minWidth` / `minHeight` are a floor on the *shortest* edge,
not a cap on the longest: 4000x3000 at 1600/1600 comes out 2133x1600. Passing
the computed target size instead makes the ratio exact, which is what actually
guarantees 1600.

The occlusion editor uses the same path, so the canvas always draws on the
cropped, compressed picture and the boxes are stored against it.

## ImageKit uploads

Pictures live in ImageKit, not in Supabase Storage. The private key is a server
secret held by the `upload-image` Edge Function: a key shipped inside an APK is
a key anyone can extract and spend.

| Piece | Where |
|---|---|
| `imageKitUrlEndpoint`, `imageKitPublicKey` | `lib/core/config/imagekit_config.dart` (public values only) |
| `IMAGEKIT_PRIVATE_KEY`, `IMAGEKIT_URL_ENDPOINT` | Supabase Edge Function secrets |
| Upload endpoint | `POST /functions/v1/upload-image` |

The function refuses anything without a valid Supabase JWT (401 before a byte
is read), caps the body at 8 MB, files uploads under `/cards/<user id>` so one
account cannot overwrite another's pictures, and returns the ImageKit URL plus
its `fileId`. The client accepts the response only when the URL starts with
the account's endpoint, so a misconfigured function cannot write a foreign URL
into a card.

Deployment:

```bash
supabase secrets set IMAGEKIT_PRIVATE_KEY=... IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/7sn
supabase functions deploy upload-image
```

Deleting a card does not delete its ImageKit file: removal needs the private
key and therefore a second function. Orphaned files are cheap, and a failed
delete must never block a card edit.

Audio still uses the `card-media` bucket. Only pictures moved.

## Image occlusion

An occlusion card stores its picture in `front` (as `![تغطية](url)`) and its
question in `back`, which is what the editor field labelled «السؤال» writes.
The answers are not text on the card: each box in `occlusion.boxes` carries its
own `a` label, drawn against the same normalised geometry the editor used.

The review shows the question above the picture, masks every box, and calls out
the label of the box the learner taps — a bubble above it, flipped below when
the box sits too close to the top edge. A label squeezed inside a twenty-pixel
box would be unreadable, which is why the bubble exists.

Moving and resizing are separate gestures on separate widgets: the body drags
the box, four corner grips resize it, and the grips only appear once the box is
large enough that they do not cover it. The previous version guessed the intent
from how close to a corner the touch started, so a box smaller than twice the
touch radius could only be resized and never moved.

## The full-screen viewer

`showImageViewer` opens any attachment with `photo_view`: pinch to zoom, drag
to pan, tap to close. Cards crop their pictures to keep the card a card, which
is right for a photo and wrong for a diagram with a caption in the corner, so
every attachment that is visible is also one that can be opened.

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

A code is only shown while the deck is not private. Going private keeps the
stored code — republishing should not mint a new one — which is why the client
cannot treat "has a code" as "may be shared": `DeckNode.isShareable` also
requires `privacy != private`, and every surface (the top bar, the actions
sheet, the privacy card) reads that one getter.

## Public library and remixes

`public_decks` is a flat view: one row per published deck, joined to
`profiles` for `author_name` and aggregated against `deck_ratings` for the
star average and the review count. It also carries `install_count`, bumped by
`record_deck_install`. It carries no nesting columns.

`deck_ratings` holds one row per user per deck: `rating` (1-5) and an optional
`review` comment, unique on `(deck_id, user_id)`. Ratings are public to read;
writing requires the signed-in owner, and only for a deck that is currently
public. The statistics tab reads them through `LibraryRepository.fetchReviews`,
which fetches the rows first and then resolves display names and avatars from
`profiles` in a second query, because `deck_ratings` references profiles by user
id and an embedded select would depend on a foreign key the client does not own.
The review row shows the Google picture when there is one and falls back to the
initial only when the account has no avatar.

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

## FSRS-6 review engine

Scheduling is delegated to the [`fsrs`](https://pub.dev/packages/fsrs) package
(2.x, which is FSRS-6) through `lib/core/scheduling/fsrs_engine.dart`. The
package is never imported outside that file, so the algorithm can be swapped or
pinned without touching the repository or the UI.

### What the app stores

`card_states` already had the right columns; FSRS-6 needs exactly three things
to be reproducible:

| Column | Meaning |
|---|---|
| `stability` | Days until recall decays to the target retention |
| `difficulty` | 1 (easy) … 10 (hard) |
| `learning_steps` | The FSRS step index, synced as `learning_steps` |

`due`, `last_review` and `updated_at` are **instants**. Drift stores
`DateTime` columns as Unix epoch seconds, so a value written with
`DateTime.now().toUtc()` reads back as the same instant in whatever timezone
the device is in. The scheduler itself only accepts UTC (`reviewCard` throws
otherwise), so `FsrsEngine` converts on the way in and writes UTC on the way
out. A user who flies from Riyadh to London keeps the same schedule.

### One answer, start to finish

```text
rating (1..4)
  → read card_states row
  → FsrsMemory? (null when the row has no real FSRS numbers)
  → Scheduler.reviewCard(card, rating, reviewDateTime: nowUtc)
  → CardStatesCompanion (status, due, stability, difficulty, step, …)
  → review_logs row with prev_state / next_state snapshots
  → one sync_queue row per write
```

Everything happens in a single Drift transaction, so an answer either updates
the card and its log or does neither.

### Edge cases that are handled explicitly

- **Legacy cards.** Rows written by the old fixed-interval scheduler have
  `stability = 0` and `difficulty = 0`, which FSRS can never produce (stability
  has a floor of 0.001). `ContentRepository._memoryOf` reports those as *no
  memory*, so the card is re-seeded as `Card.newCard()` on its next answer. Its
  review history and lapse count are kept, but the made-up intervals are not
  trusted as memory: treating "5 days because the button said so" as stability
  would poison every later interval.
- **Clock moved backwards.** `last_review` is clamped to `now` before the maths
  runs, so a user who sets the date back cannot feed the scheduler a negative
  elapsed time (which would land in the short-term branch and corrupt
  stability).
- **Long-overdue cards.** The package computes retrievability from the real
  elapsed days, so a card that is three weeks late comes back with a much
  lower stability update than one answered on time. The pre-answer
  retrievability is written into `review_logs.prev_state` for inspection.
- **Answering ahead of schedule.** A mature card whose `due` is still in the
  future is ignored by `recordReview` unless `allowEarly` is set, which only
  the "راجع الكل الآن" path does. That turns a double tap into a no-op instead
  of a corrupted interval.
- **Suspending.** `setCardsSuspended` copies stability, difficulty and the step
  index across unchanged, and on restore derives the phase from the numbers
  (`scheduled_days > 0` means graduated) rather than from `reps`, because a
  card can have one answer and still be on its first learning step.
- **Timezones.** Nothing is stored as a wall-clock string; only instants and
  the scheduler's own numbers.
- **Fuzzing.** On, so a batch of cards learned the same day does not all come
  back on the same day. The interval previews under the rating buttons are
  computed with fuzzing off so they do not flicker between rebuilds.

### What the user sees

The four rating buttons show the interval FSRS would actually produce for that
card (`ContentRepository.previewIntervals`, pure computation, no database
access). They used to show hardcoded "1 minute / 2 days / 5 days / 11 days",
which became a lie the moment real scheduling arrived.

Daily limits are unchanged and still applied in `studyQueue`: new cards first
capped at `dailyNewLimit`, then learning, then reviews capped at
`dailyReviewLimit`.

### Every study mode is a review

The four modes differ in how they ask, not in what they write. All of them go
through the same `recordReview` path as the review screen: a correct answer is
rating 3 (Good), a wrong one is rating 1 (Again), and every call passes
`allowEarly: true` because the learner deliberately chose to practise over the
whole deck rather than waiting for the scheduler.

| Mode | Written when | Rating |
|---|---|---|
| المراجعة | The learner picks a button | 1-4, as chosen |
| الاختبار | Each question is answered | 3 correct, 1 wrong |
| المطابقة | A pair clears, or a wrong pair is tried | 3 matched, 1 mismatched |
| الكتابة | The answer is confirmed or overridden | 3 accepted, 1 rejected |

In the match game the *first* tile of a failed pair is the one that gets
marked: that is the card the learner committed to. In write mode nothing is
written until the question is resolved, so the override button («كنت محقاً»)
replaces the verdict instead of adding a second review to the same card.

Nothing else about a session touches the database: the question list is built
once and «أعد الاختبار» is a pure in-memory rebuild.

### Write mode matching

`lib/domain/answer_match.dart` folds Arabic orthography before it measures
anything — hamza forms, ta marbuta, alef maqsura, tashkeel and tatweel all
collapse to one spelling — then compares with a two-row Levenshtein distance.
The tolerance scales with length: a four-letter answer must match exactly,
because «DNA» and «RNA» differ by one character and by everything, while a long
answer can absorb a couple of slips. A multi-word answer also passes when every
word is present in any order. Anything the matcher still gets wrong is what the
override button is for.

### Sound and touch feedback

`lib/core/audio/sound_service.dart` owns both cues and one player: a second cue
replaces the first instead of layering over it, and a fast run of correct
answers never spawns a player per answer. A missing audio route or a failed
decode is logged and swallowed — feedback must never interrupt a session.

| Outcome | Sound | Touch |
|---|---|---|
| Correct answer, cleared pair | rising three-note chime | heavy impact |
| Wrong answer | low double buzz | heavy impact, then vibrate |

## The progress dashboard

`lib/domain/gamification.dart` holds the pure maths; `progressSummaryProvider` in
`lib/data/content_providers.dart` feeds it from two live streams and nothing else.

| Signal | Source |
|---|---|
| Reviews per day, and how many were recalled | `review_logs` grouped by local date |
| Deck count | `decks` (non-deleted) |
| Upcoming workload | `card_states.due` for the next seven days |

XP is never stored. It is recomputed as `reviews * 10 + recalled * 5 + decks * 50`,
so a deleted deck or an undone review cannot leave a phantom balance behind.
"Recalled" means `rating >= 2`, the same threshold the deck statistics and the
heatmap already use, which keeps one definition of a successful review across the
app.

Levels follow `50 * n * (n - 1)`: 0, 100, 300, 600, 1000 XP and so on. The
inverse is a loop, not a closed form, because the curve is quadratic and the loop
runs a few dozen times at most.

Streaks are computed in Dart from the same day set that draws the calendar, rather
than from a second SQL query. Two sources would eventually disagree, and the
calendar is the thing the learner can count with their own eyes.

Badges read `bestStreak`, not the current streak: a badge that vanishes the
morning after a missed day is a punishment, not a reward. Badge colours are
mid-tone and lifted toward white in dark mode rather than replaced, so each badge
keeps its identity in both themes.

Charts use `fl_chart`. The forecast bars draw a `backDrawRodData` track behind every
day so a zero day still reads as "nothing due" instead of an empty slot.

Before the first review the charts are a wall of zeros, which reads as failure
rather than as a beginning. When `totalReviews` is zero the streak, retention,
forecast and heatmap panels are replaced by one explanation, and a learner who
owns no decks at all gets a button that opens the create sheet instead of advice
they cannot act on.

## Reminders

`lib/core/notifications/reminder_service.dart` wraps
`flutter_local_notifications` and `timezone`. Nothing else in the app touches
the plugin.

### Schedule

| Rule | Value |
|---|---|
| Slots | 08:00, 11:00, 14:00, 17:00, 20:00, 22:00 local |
| Slots used | 2 for under 10 due cards, 4 for 10–29, all 6 for 30+ |
| Nothing due | every pending reminder is cancelled |
| Repeat | `DateTimeComponents.time`, so the set repeats daily |
| Ids | `4100 + slot index` |

The slot count is deliberate: one overdue card does not deserve six nudges,
while a hundred do.

### Permission

The system dialog is only shown *after* an explanation of our own, at the end
of onboarding. A cold request is the fastest route to a permanent denial, and
on Android a permanent denial can only be undone in the system settings.
Declining the explanation flips the in-app switch off, so the app never claims
to be reminding someone it cannot reach. Settings shows the real state, with a
row that opens the system settings when notifications are blocked.

`SCHEDULE_EXACT_ALARM` is requested from Settings, not during onboarding:
it opens a second system screen, and it is optional. When it is missing the
scheduler silently falls back to `inexactAllowWhileIdle`, which still wakes a
dozing phone within the hour.

### Staying correct

- **Timezone.** `tz.initializeTimeZones()` plus
  `FlutterTimezone.getLocalTimezone()` run at startup, so a repeat lands on the
  right wall-clock hour rather than in UTC.
- **Reboot.** `ScheduledNotificationBootReceiver` is declared in the manifest
  with `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, so the set is re-armed
  without the app being opened.
- **Tap.** The payload is the deck id. A tap while running calls
  `ReminderService.onOpenDeck`, which pushes `/review/:id`; a tap that launched
  the app is delivered through `getNotificationAppLaunchDetails` and drained
  after the first frame. If the user has not finished onboarding, the deck id is
  parked in `SharedPreferences` and opened afterwards.
- **Keeping in step.** `ReminderCoordinator` listens to the total due count,
  debounces two seconds, and only reschedules when the *number of slots* or the
  deck changed. A whole review session therefore collapses into one
  reschedule, and the last answer of the day cancels everything.

## Offline, failures and empty states

- **Offline.** `networkStatusProvider` maps `connectivity_plus` to a boolean.
  `OfflineBanner` floats a pill above the tab bar while the device is offline
  and fades out when it returns; it never shifts the layout, so no screen has to
  know it exists. Studying is unaffected, and the sync queue drains on
  reconnect.
- **Loading.** Lists that can be slow use shimmer skeletons shaped like the
  real rows (`lib/core/widgets/skeleton.dart`) instead of a centred spinner,
  so the page keeps its height and does not jump when data arrives.
- **Empty.** `EmptyState` is the single empty view: an icon badge, a sentence
  that explains *why* it is empty, and one action. No screen renders a bare
  "nothing here".
- **Errors.** Supabase calls are wrapped in the repository, which converts
  failures into a typed `LibraryFailure` / `ProfileFailure` carrying Arabic
  copy. The UI maps those to a SnackBar or an inline error; a raw exception
  string is never shown.
- **Async gaps.** Every `setState` that follows an `await` is behind a
  `mounted` check, including the media picker, which runs in another activity
  while the editor can be popped.
- **Disposal.** Every `AnimationController`, `Timer`, `StreamSubscription` and
  `TextEditingController` is released in `dispose` or `ref.onDispose`.
- **Images.** Every `CachedNetworkImage` sets `memCacheWidth` and
  `maxWidthDiskCache` to the size it actually paints.
- **Accessibility.** Icon-only controls carry `Semantics` labels, and the
  offline banner is a live region.

## Releases and the in-app updater

The app ships itself. Nothing here is a store listing: a release is a GitHub
Release, and the app reads that release to decide whether to offer an update.

**Pipeline.** `.github/workflows/build_android.yml` builds three split APKs,
renames the arm64 one to `bitaqati.apk`, and publishes all of them with
`softprops/action-gh-release`. The tag comes from `pubspec.yaml`
(`version: 1.0.0+1` → `v1.0.0`), not from the run number, because the updater
compares that tag with the installed version. `make_latest: true` keeps
`/releases/latest` pointing at the newest build, which is what makes the fixed
download URL work:

```
https://github.com/7sn-17/bitaqati/releases/latest/download/bitaqati.apk
```

The job needs `permissions: contents: write`; without it the release step fails
and the download URL 404s.

**Check.** `UpdateService` reads the installed version with
`PackageInfo.fromPlatform()` — never a constant, so the number in Settings
cannot drift from the APK — then `GET`s
`https://api.github.com/repos/7sn-17/bitaqati/releases/latest`. There is no
cached fast path: the check runs once per cold start and once per tap in
Settings, so a release published an hour ago is offered on the next launch
instead of after a timer expires. The remembered answer is only a stand-in for
a request that failed outright, and a failed check returns `null`, which the UI
treats as "nothing to show", never as "you are up to date" — that is the one
wrong answer that could strand someone on an old build.

**Compare.** `UpdateService.compareVersions` walks numeric segments first and
then the pre-release tag, so `1.0.0` beats `1.0.0-beta.2` and `v1.2.0` equals
`1.2.0`. `+build` suffixes are stripped before comparing.

**Show.** `AppShell` waits two seconds after the first frame, reads
`updateInfoProvider`, and shows `UpdateDialog` when there is something newer.
That happens on every cold start. "لاحقاً" only sets `updateDismissedProvider`
in memory, so it silences the dialog for the rest of the session and the offer
returns the next time the app is opened — persisting it to disk, as it once
did, quietly turned "later" into "never". Settings carries the same information
as an "تحديث متوفر" row that only exists while an update is pending, and the
version row doubles as a manual re-check. "تحديث الآن" hands the URL to the
system browser: Android will not let an app install a package it downloaded
itself without a second permission, and a browser already shows progress and
resumes.

**Notes.** The dialog's "ما الجديد" box shows the release `body`, and that body
is not written in the workflow: the release step cuts the section for the
current version out of `CHANGELOG.md` and passes it as `body_path`. It used to
be a hard-coded paragraph listing every APK by name, so the first thing a user
read about a new version was `bitaqati-v1.1.0-arm64-v8a.apk`. Keep each bullet
to one line — the dialog strips markdown but does not reflow wrapped lines.

## Deck customisation

`kDeckColors` holds 42 tones in two families — 28 deep jewel and earth tones
that carry white text, and 14 pale tints that carry dark ink. `kDeckIcons`
holds 79 icons grouped by subject (science, maths, language, history,
technology, arts, business).

Nothing decides the foreground by hand. `onDeckColor(color)` returns the ink
for something painted *on* a deck colour (a tile, a header, the editor preview),
and `deckInk(color, dark: …)` returns the colour to use *as* a foreground on a
surface, darkening pale tones in the light theme where a pastel on near-white
would be invisible. Both are luminance tests, so a new tone dropped into the
list is legible without touching any widget.

The editor shows both sets in a three-row scrollable window rather than a wrap,
so 42 swatches and 79 icons do not push the save button off the sheet.

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
| `20261027000600_live_author_names.sql` | Author name joined live instead of copied |
| `20261027000700_flatten_decks.sql` | Dropped every nesting column and the tree indexes |
| `20261027000800_public_decks_hardening.sql` | `security_invoker` on the view, column grants, pinned `search_path` |
| `20261027000900_new_user_metadata.sql` | `handle_new_user` reads Google's name and picture |

Every user table has RLS. The client only ever ships the publishable key.

`card_states` already carries every column FSRS-6 needs (`stability`,
`difficulty`, `learning_steps`, `elapsed_days`, `scheduled_days`), so the
scheduler needs no cloud migration: the numbers travel in the existing
`card_states` upsert. `fsrs_version` is local-only and deliberately not synced.

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

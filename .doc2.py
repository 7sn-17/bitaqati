
import io
p='docs/DEEP_LINKS.md'
s=io.open(p,encoding='utf-8').read()

old = """### Copying a code

The deck screen's overflow menu has **نسخ رمز المشاركة** and the privacy card
shows the code with its own copy button. The code is stored locally, so it is
available before the deck is ever published — the server only confirms it
during the first publish, and may replace it if another account already
claimed the same string.

## Link format

`BT__`text
https://bitaqati.app/deck/<deck-id>
`BT`

The id is the deck UUID, identical locally and in Supabase, so a link keeps
working before and after the recipient installs the deck.

The legacy `bitaqati://deck/<deck-id>` scheme is still accepted by
`AppConfig.deckIdFromShareLink`, so links shared by older builds keep working.
New links are always HTTPS.
"""

new = """### Copying a code

The deck screen's top bar has a code button that opens a sheet showing the
six-character code with one **نسخ الرمز** button. The privacy card repeats the
code next to its current visibility. The code is stored locally, so it is
available before the deck is ever published — the server only confirms it
during the first publish, and may replace it if another account already
claimed the same string.

A deck is shared **only** by that code. The app never builds, shows or copies a
share URL: there is no link button anywhere in the interface, and
`SharingResult` carries no link field.

## Inbound links

The app still **accepts** the old URL forms, so links that were shared before
the switch keep working:

`BT__`text
https://bitaqati.app/deck/<deck-id>
bitaqati://deck/<deck-id>
`BT`

Both are parsed by `AppConfig.deckIdFromShareLink`. The id is the deck UUID,
identical locally and in Supabase, so the same link worked before and after
the recipient installed the deck. Nothing in the app produces these URLs any
more; the parser is a compatibility path only.
"""

assert s.count(old)==1, s.count(old)
s=s.replace(old,new)
io.open(p,'w',encoding='utf-8').write(s)
print('deep links doc updated')

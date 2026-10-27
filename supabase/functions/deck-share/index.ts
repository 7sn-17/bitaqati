// Web preview for https://bitaqati.app/deck/<id>
//
// Supabase Edge Function (Deno). It renders a small page with Open Graph tags
// so the link unfurls nicely in WhatsApp/Telegram, offers "open in app" via the
// legacy custom scheme, and falls back to the Play Store listing.
//
// Deploy:
//   supabase functions deploy deck-share --no-verify-jwt
// Then point the host (or its /deck/* route) at this function.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const PLAY_STORE = Deno.env.get('PLAY_STORE_URL') ??
  'https://play.google.com/store/apps/details?id=com.bitaqati.app';

interface DeckRow {
  title?: string;
  description?: string;
  icon?: string;
  card_count?: number;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function loadDeck(id: string): Promise<DeckRow | null> {
  if (!SUPABASE_URL || !SERVICE_KEY || !id) {
    return null;
  }
  const url = new URL('/rest/v1/decks', SUPABASE_URL);
  url.searchParams.set('select', 'title,description,icon');
  url.searchParams.set('id', 'eq.' + id);
  url.searchParams.set('limit', '1');
  try {
    const response = await fetch(url, {
      headers: {
        apikey: SERVICE_KEY,
        Authorization: 'Bearer ' + SERVICE_KEY,
      },
    });
    if (!response.ok) {
      return null;
    }
    const rows = await response.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return null;
    }
    return rows[0] as DeckRow;
  } catch {
    return null;
  }
}

Deno.serve(async (request: Request) => {
  const url = new URL(request.url);
  const segments = url.pathname.split('/').filter((part) => part.length > 0);
  const deckIndex = segments.indexOf('deck');
  const id = deckIndex >= 0
    ? (segments[deckIndex + 1] ?? '')
    : (url.searchParams.get('id') ?? '');

  if (!id) {
    return Response.redirect(PLAY_STORE, 302);
  }

  const deck = await loadDeck(id);
  const title = deck?.title?.trim() || 'مجموعة على بطاقاتي';
  const description = deck?.description?.trim() ||
    'افتح المجموعة في تطبيق بطاقاتي وراجعها بالتكرار المتباعد.';

  const html = `<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)} · بطاقاتي</title>
<meta property="og:type" content="article">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="https://bitaqati.app/deck/${escapeHtml(id)}">
<meta name="twitter:card" content="summary_large_image">
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; min-height: 100vh; display: grid; place-items: center;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    background: #0b120c; color: #f2f7ef; padding: 24px;
  }
  main {
    max-width: 420px; width: 100%; background: #151d16; border-radius: 24px;
    padding: 28px; border: 1px solid #3b4a36; text-align: center;
  }
  .badge {
    display: inline-block; padding: 6px 12px; border-radius: 999px;
    background: rgba(169, 242, 125, 0.16); color: #a9f27d;
    font-size: 12px; font-weight: 600;
  }
  h1 { font-size: 22px; margin: 16px 0 8px; line-height: 1.5; }
  p { color: #b6c2b1; font-size: 14px; line-height: 1.8; margin: 0 0 22px; }
  a.button {
    display: block; text-decoration: none; font-weight: 700; font-size: 15px;
    padding: 14px 18px; border-radius: 999px; background: #a9f27d; color: #163300;
  }
  a.secondary {
    display: block; margin-top: 10px; color: #b6c2b1; font-size: 13px;
    text-decoration: none;
  }
</style>
</head>
<body>
<main>
  <span class="badge">بطاقاتي</span>
  <h1>${escapeHtml(title)}</h1>
  <p>${escapeHtml(description)}</p>
  <a class="button" href="bitaqati://deck/${escapeHtml(id)}">افتح في التطبيق</a>
  <a class="secondary" href="${PLAY_STORE}">أو نزّل التطبيق من Google Play</a>
</main>
<script>
  // Try the app once; if nothing handles the scheme the store link stays.
  setTimeout(function () {
    window.location.href = 'bitaqati://deck/${escapeHtml(id)}';
  }, 250);
</script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
    },
  });
});

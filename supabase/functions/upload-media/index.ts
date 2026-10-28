// Uploads one card attachment - a picture or a voice note - to ImageKit and
// returns its public URL.
//
// The ImageKit private key never leaves this function: the app calls it with
// the signed-in user's Supabase JWT, and only a verified user can push bytes
// into the account. Files are filed under /cards/<user id>, which is what lets
// delete-media refuse to touch anything outside the caller's own folder.
//
// The client sends the raw bytes as the request body and names the file in
// x-file-name. The extension on that name decides the kind, the ImageKit
// folder entry and the size cap - there is no separate MIME header to trust.
//
// Deploy:
//   supabase secrets set IMAGEKIT_PRIVATE_KEY=... IMAGEKIT_URL_ENDPOINT=...
//   supabase functions deploy upload-media

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const IMAGEKIT_PRIVATE_KEY = Deno.env.get('IMAGEKIT_PRIVATE_KEY') ?? '';
const IMAGEKIT_URL_ENDPOINT = (
  Deno.env.get('IMAGEKIT_URL_ENDPOINT') ?? 'https://ik.imagekit.io/7sn'
).replace(/\/+$/, '');

/// A compressed 1600px JPEG lands around 300 KB; five minutes of speech at
/// 64 kbps lands around 2.4 MB. The caps are per kind, so a picture can never
/// borrow the audio budget and slip 20 MB through the door.
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_AUDIO_BYTES = 24 * 1024 * 1024;

const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
const AUDIO_EXTENSIONS = ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus', 'flac', '3gp'];

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-file-name',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/// Resolves the caller from their JWT. Returns null for a missing, expired or
/// forged token, which is the only thing that gates the upload.
async function userIdFrom(request: Request): Promise<string | null> {
  const header = request.headers.get('Authorization') ?? '';
  if (!header.startsWith('Bearer ')) {
    return null;
  }
  const response = await fetch(SUPABASE_URL + '/auth/v1/user', {
    headers: {
      Authorization: header,
      apikey: SUPABASE_ANON_KEY,
    },
  });
  if (!response.ok) {
    return null;
  }
  const user = await response.json();
  return typeof user?.id === 'string' ? user.id : null;
}

/// Splits the client name into an ImageKit-safe stem and a lowercase
/// extension. Arabic names pass through untouched - only separators and
/// punctuation are folded - because the stem is never put in a header.
function splitName(raw: string | null): { stem: string; extension: string } {
  const value = (raw ?? '').trim();
  const dot = value.lastIndexOf('.');
  const stem = (dot > 0 ? value.slice(0, dot) : value)
    .replace(/[^\p{L}\p{N}_-]+/gu, '-')
    .slice(0, 60)
    .replace(/^-+|-+$/g, '');
  const extension = dot > 0 ? value.slice(dot + 1).toLowerCase() : '';
  return { stem: stem || 'card', extension };
}

/// Which of the two caps applies, or null for a file we refuse to host.
function kindOf(extension: string): 'image' | 'audio' | null {
  if (IMAGE_EXTENSIONS.includes(extension)) {
    return 'image';
  }
  if (AUDIO_EXTENSIONS.includes(extension)) {
    return 'audio';
  }
  return null;
}

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    binary += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return btoa(binary);
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }
  if (!IMAGEKIT_PRIVATE_KEY) {
    return json({ error: 'not_configured' }, 500);
  }

  const userId = await userIdFrom(request);
  if (userId === null) {
    return json({ error: 'unauthorized' }, 401);
  }

  const name = splitName(request.headers.get('x-file-name'));
  const kind = kindOf(name.extension);
  if (kind === null) {
    return json({ error: 'unsupported_type' }, 415);
  }

  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length === 0) {
    return json({ error: 'empty_body' }, 400);
  }
  const limit = kind === 'image' ? MAX_IMAGE_BYTES : MAX_AUDIO_BYTES;
  if (bytes.length > limit) {
    return json({ error: 'too_large', kind, limit }, 413);
  }

  const form = new FormData();
  form.append('file', toBase64(bytes));
  form.append('fileName', name.stem + '.' + name.extension);
  form.append('folder', '/cards/' + userId);
  form.append('useUniqueFileName', 'true');

  let response: Response;
  try {
    response = await fetch('https://upload.imagekit.io/api/v1/files/upload', {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + btoa(IMAGEKIT_PRIVATE_KEY + ':'),
      },
      body: form,
    });
  } catch (error) {
    return json({ error: 'network', message: String(error) }, 502);
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    return json(
      {
        error: 'imagekit_failed',
        status: response.status,
        message: payload?.message ?? '',
      },
      502,
    );
  }

  const url = typeof payload?.url === 'string' ? payload.url : '';
  if (!url.startsWith(IMAGEKIT_URL_ENDPOINT)) {
    return json({ error: 'unexpected_url' }, 502);
  }

  return json({
    url,
    fileId: payload.fileId ?? '',
    thumbnailUrl: payload.thumbnailUrl ?? '',
    width: payload.width ?? 0,
    height: payload.height ?? 0,
    size: payload.size ?? bytes.length,
    name: payload.name ?? '',
    kind,
  });
});

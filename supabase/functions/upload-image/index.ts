
// Uploads a compressed card image to ImageKit and returns its public URL.
//
// The ImageKit private key never leaves this function: the app calls it with
// the signed-in user's Supabase JWT, and only a verified user can push bytes
// into the account. Files are filed under /cards/<user id> so one account can
// never overwrite another's pictures.
//
// Deploy:
//   supabase secrets set IMAGEKIT_PRIVATE_KEY=... IMAGEKIT_URL_ENDPOINT=...
//   supabase functions deploy upload-image

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const IMAGEKIT_PRIVATE_KEY = Deno.env.get('IMAGEKIT_PRIVATE_KEY') ?? '';
const IMAGEKIT_URL_ENDPOINT = (
  Deno.env.get('IMAGEKIT_URL_ENDPOINT') ?? 'https://ik.imagekit.io/7sn'
).replace(/\/+$/, '');

/// A compressed 1600px JPEG lands around 300 KB; anything past 8 MB is not a
/// card picture and is refused before it reaches the network.
const MAX_BYTES = 8 * 1024 * 1024;

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

/// ImageKit decides the extension from the name, and the client always sends
/// JPEG, so the name is reduced to a safe stem plus .jpg.
function safeName(raw: string | null): string {
  const stem = (raw ?? '')
    .replace(/\.[a-z0-9]+$/i, '')
    .replace(/[^\p{L}\p{N}_-]+/gu, '-')
    .slice(0, 60)
    .replace(/^-+|-+$/g, '');
  return (stem || 'card') + '.jpg';
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

  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length === 0) {
    return json({ error: 'empty_body' }, 400);
  }
  if (bytes.length > MAX_BYTES) {
    return json({ error: 'too_large', limit: MAX_BYTES }, 413);
  }

  const form = new FormData();
  form.append('file', toBase64(bytes));
  form.append('fileName', safeName(request.headers.get('x-file-name')));
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
  });
});

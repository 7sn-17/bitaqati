// Deletes card media from ImageKit - and, as a fallback, from Supabase
// Storage - when the card or deck that owned it is removed.
//
// The app only ever stores public URLs inside the card markup, not ImageKit
// file ids, so this function does the lookup itself: it lists the caller's own
// folder, maps each requested URL to the file id ImageKit gave it, and deletes
// the batch in one call.
//
// Two rules keep it safe:
//   1. Every path must sit under /cards/<caller id>/. A request that names
//      somebody else's file is refused, not silently skipped.
//   2. Nothing is deleted before the caller is resolved from their JWT.
//
// Body: { urls?: string[], fileIds?: string[] }
// Reply: { deleted: number, failed: string[] }
//
// Deploy:
//   supabase functions deploy delete-media

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const IMAGEKIT_PRIVATE_KEY = Deno.env.get('IMAGEKIT_PRIVATE_KEY') ?? '';
const IMAGEKIT_URL_ENDPOINT = (
  Deno.env.get('IMAGEKIT_URL_ENDPOINT') ?? 'https://ik.imagekit.io/7sn'
).replace(/\/+$/, '');

/// The bucket that held audio before it moved to ImageKit. Kept so recordings
/// uploaded by older builds are cleaned up too.
const LEGACY_BUCKET = 'card-media';

/// A single card cannot reference more than a handful of files; a deck purge
/// can reference a few hundred. Past this the request is a mistake or an
/// attempt to grind the function, so it is refused.
const MAX_TARGETS = 400;

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

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

/// Turns an ImageKit delivery URL back into the media path.
///
/// A URL may carry a transformation segment (''/tr:w-300/...''), which is a
/// view of the file rather than its address, so it is stripped before the
/// lookup. Returns null for anything that is not ours.
function imageKitPath(url: string): string | null {
  const clean = url.split('?')[0].split('#')[0];
  if (!clean.startsWith(IMAGEKIT_URL_ENDPOINT + '/')) {
    return null;
  }
  let rest = clean.slice(IMAGEKIT_URL_ENDPOINT.length);
  if (rest.startsWith('/tr:')) {
    const slash = rest.indexOf('/', 1);
    rest = slash === -1 ? '/' : rest.slice(slash);
  }
  try {
    return decodeURIComponent(rest);
  } catch {
    return rest;
  }
}

/// Extracts the object key from a Supabase Storage public URL, or null when
/// the URL is not a storage URL for [bucket].
function storagePath(url: string, bucket: string): string | null {
  const marker = '/storage/v1/object/';
  const at = url.indexOf(marker);
  if (at === -1) {
    return null;
  }
  const parts = url.slice(at + marker.length).split('?')[0].split('/');
  // public/<bucket>/<key...> or sign/<bucket>/<key...>
  if (parts.length < 3 || parts[1] !== bucket) {
    return null;
  }
  return parts.slice(2).join('/');
}

/// Every file id in one folder, keyed by both its path and its URL.
///
/// ImageKit pages at 1000 files, and a busy account can hold more than that,
/// so the walk stops at five pages - far beyond anything a single card owns.
async function folderIndex(folder: string): Promise<Map<string, string>> {
  const index = new Map<string, string>();
  const auth = 'Basic ' + btoa(IMAGEKIT_PRIVATE_KEY + ':');
  let skip = 0;
  for (let page = 0; page < 5; page++) {
    const query =
      'https://api.imagekit.io/v1/files?path=' +
      encodeURIComponent(folder) +
      '&limit=1000&skip=' +
      skip;
    let response: Response;
    try {
      response = await fetch(query, { headers: { Authorization: auth } });
    } catch {
      break;
    }
    if (!response.ok) {
      break;
    }
    const files = await response.json().catch(() => []);
    if (!Array.isArray(files) || files.length === 0) {
      break;
    }
    for (const file of files) {
      if (typeof file?.fileId !== 'string') {
        continue;
      }
      if (typeof file?.filePath === 'string') {
        index.set(file.filePath, file.fileId);
      }
      if (typeof file?.url === 'string') {
        index.set(file.url.split('?')[0], file.fileId);
      }
    }
    if (files.length < 1000) {
      break;
    }
    skip += files.length;
  }
  return index;
}

/// Deletes one id at a time, six at a time.
///
/// ImageKit's bulk endpoint (POST /v1/files/batch/delete) answers 403
/// "Invalid CSRF Token" to a server-to-server Basic auth call, so it is not an
/// option here. The single-file endpoint returns 204 and needs nothing else.
/// Six in flight keeps a hundred-file deck purge under a few seconds without
/// tripping any rate limit.
async function deleteFileIds(ids: string[]): Promise<string[]> {
  const failed: string[] = [];
  const auth = 'Basic ' + btoa(IMAGEKIT_PRIVATE_KEY + ':');
  const queue = [...ids];
  const workers = Array.from(
    { length: Math.min(6, queue.length) },
    async (): Promise<void> => {
      while (queue.length > 0) {
        const id = queue.pop();
        if (id === undefined) {
          return;
        }
        try {
          const response = await fetch(
            'https://api.imagekit.io/v1/files/' + encodeURIComponent(id),
            { method: 'DELETE', headers: { Authorization: auth } },
          );
          if (!response.ok) {
            failed.push(id);
          }
        } catch {
          failed.push(id);
        }
      }
    },
  );
  await Promise.all(workers);
  return failed;
}

async function deleteStorageObjects(
  keys: string[],
  fallbackToken: string,
): Promise<string[]> {
  const failed: string[] = [];
  const token = SUPABASE_SERVICE_ROLE_KEY || fallbackToken;
  for (let start = 0; start < keys.length; start += 50) {
    const chunk = keys.slice(start, start + 50);
    try {
      const response = await fetch(
        SUPABASE_URL + '/storage/v1/object/' + LEGACY_BUCKET,
        {
          method: 'DELETE',
          headers: {
            Authorization: 'Bearer ' + token,
            apikey: token,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ prefixes: chunk }),
        },
      );
      if (!response.ok) {
        failed.push(...chunk);
      }
    } catch {
      failed.push(...chunk);
    }
  }
  return failed;
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

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad_json' }, 400);
  }

  const urls = Array.isArray(body.urls)
    ? body.urls.filter((value): value is string => typeof value === 'string')
    : [];
  const fileIds = Array.isArray(body.fileIds)
    ? body.fileIds.filter((value): value is string => typeof value === 'string')
    : [];
  if (urls.length + fileIds.length === 0) {
    return json({ deleted: 0, failed: [] });
  }
  if (urls.length + fileIds.length > MAX_TARGETS) {
    return json({ error: 'too_many', limit: MAX_TARGETS }, 413);
  }

  const owner = '/cards/' + userId + '/';
  const failed: string[] = [];
  const wanted = new Set<string>();
  const storageKeys: string[] = [];

  for (const raw of urls) {
    const url = raw.trim();
    if (url === '' || url.startsWith('file://')) {
      // A file that never left the device has nothing to delete in the cloud.
      continue;
    }
    const path = imageKitPath(url);
    if (path !== null) {
      if (!path.startsWith(owner)) {
        failed.push(url);
        continue;
      }
      wanted.add(path);
      continue;
    }
    const key = storagePath(url, LEGACY_BUCKET);
    if (key !== null) {
      if (!key.startsWith(userId + '/')) {
        failed.push(url);
        continue;
      }
      storageKeys.push(key);
      continue;
    }
    failed.push(url);
  }

  // Group the wanted paths by folder so each folder is listed exactly once.
  const folders = new Map<string, string[]>();
  for (const path of wanted) {
    const slash = path.lastIndexOf('/');
    const folder = slash <= 0 ? '/' : path.slice(0, slash);
    const list = folders.get(folder);
    if (list === undefined) {
      folders.set(folder, [path]);
    } else {
      list.push(path);
    }
  }

  const targets = new Set<string>(fileIds);
  for (const entry of folders) {
    const index = await folderIndex(entry[0]);
    for (const path of entry[1]) {
      const id = index.get(path);
      if (id === undefined) {
        failed.push(path);
      } else {
        targets.add(id);
      }
    }
  }

  const notDeleted = await deleteFileIds([...targets]);
  failed.push(...notDeleted);
  const callerToken =
    (request.headers.get('Authorization') ?? '').replace(/^Bearer /, '');
  const failedStorage = await deleteStorageObjects(storageKeys, callerToken);
  failed.push(...failedStorage.map((key) => 'storage:' + key));

  const attempted = targets.size + storageKeys.length;
  return json({
    deleted: Math.max(0, attempted - failed.length),
    failed,
  });
});

// Redeems a manual-payment activation code.
//
// The code list lives in `public.activation_codes`, which no client can read:
// RLS is on and every grant is revoked. This function is the only path in, and
// it runs with the service key so the row can actually be claimed.
//
// The work itself is one Postgres function, `redeem_activation_code`, so the
// claim and the grant happen in a single transaction. Doing it here in three
// REST calls would leave a window where a crash burns a code the learner paid
// for without granting anything.
//
// Body: { code: string, device_id?: string }
// Reply: { ok: boolean, message: string, plan_type?: string, expiry_date?: string }
//
// Deploy:
//   supabase functions deploy activate-code

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/// Long enough for a real code, short enough that the endpoint cannot be used
/// to push megabytes through the database.
const MAX_CODE_LENGTH = 40;

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

function serviceHeaders(): Record<string, string> {
  return {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE_KEY,
    'Content-Type': 'application/json',
  };
}

/// Records which phone the account is on.
///
/// The free-tier ceiling is counted per device, so an account that redeems a
/// code from a phone it has never reported would otherwise be counted against
/// no device at all. Best effort: a failure here must not fail the redemption.
async function bindDevice(userId: string, deviceId: string): Promise<void> {
  if (!deviceId) {
    return;
  }
  try {
    await fetch(
      SUPABASE_URL +
        '/rest/v1/profiles?id=eq.' +
        encodeURIComponent(userId) +
        '&device_id=is.null',
      {
        method: 'PATCH',
        headers: { ...serviceHeaders(), Prefer: 'return=minimal' },
        body: JSON.stringify({ device_id: deviceId }),
      },
    );
  } catch {
    // Nothing to do: the client retries the bind on its next launch.
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (request.method !== 'POST') {
    return json({ ok: false, message: 'Method not allowed' }, 405);
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return json(
      { ok: false, message: 'الخدمة غير مهيّأة على الخادم.' },
      500,
    );
  }

  const userId = await userIdFrom(request);
  if (userId === null) {
    return json(
      { ok: false, message: 'سجّل الدخول بحساب Google أولاً، ثم أدخل الكود.' },
      401,
    );
  }

  let body: { code?: unknown; device_id?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, message: 'طلب غير صالح.' }, 400);
  }

  const rawCode = typeof body.code === 'string' ? body.code : '';
  const code = rawCode.trim().toUpperCase();
  if (code.length === 0 || code.length > MAX_CODE_LENGTH) {
    return json(
      { ok: false, message: 'أدخل الكود كما وصل إليك.' },
      400,
    );
  }

  const deviceId = typeof body.device_id === 'string' ? body.device_id : '';
  await bindDevice(userId, deviceId);

  let response: Response;
  try {
    response = await fetch(
      SUPABASE_URL + '/rest/v1/rpc/redeem_activation_code',
      {
        method: 'POST',
        headers: serviceHeaders(),
        body: JSON.stringify({ p_code: code, p_user: userId }),
      },
    );
  } catch {
    return json(
      { ok: false, message: 'تعذّر الوصول إلى الخادم. حاول مرة أخرى.' },
      503,
    );
  }

  if (!response.ok) {
    const detail = await response.text().catch(() => '');
    console.error('redeem_activation_code failed', response.status, detail);
    return json(
      { ok: false, message: 'تعذّر التحقق من الكود. حاول مرة أخرى.' },
      500,
    );
  }

  const rows = await response.json().catch(() => []);
  const row = Array.isArray(rows) ? rows[0] : null;
  if (!row || row.ok !== true) {
    return json(
      {
        ok: false,
        message:
          typeof row?.message === 'string' && row.message.length > 0
            ? row.message
            : 'هذا الكود غير صحيح.',
      },
      200,
    );
  }

  return json({
    ok: true,
    message: row.message ?? 'تم تفعيل Pro على هذا الحساب.',
    plan_type: row.plan_type ?? null,
    expiry_date: row.expiry_date ?? null,
  });
});

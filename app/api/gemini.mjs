// Vercel Function: trợ lý AI Gemini cho bản web Lắng.
// Khoá GEMINI_API_KEY đặt trong Vercel → Project Settings → Environment Variables, KHÔNG nằm trong mã web
// (nhúng khoá vào bản web thì ai mở trang cũng đọc được).
//   GET  /api/gemini            → {"enabled": true|false}  (app hỏi khi khởi động)
//   POST /api/gemini?model=...  → chuyển nguyên yêu cầu generateContent sang Google, kèm khoá
const MODEL_OK = /^(gemini|gemma)-[a-z0-9.\-]{1,60}$/; // Gemini hoặc Gemma (cùng một khoá)
const MAX_BODY = 200_000; // byte — đủ cho câu hỏi + số liệu thời tiết

export function GET() {
  return Response.json(
    { enabled: Boolean(process.env.GEMINI_API_KEY) },
    { headers: { 'Cache-Control': 'public, max-age=300, s-maxage=300' } },
  );
}

// NHIỀU NGƯỜI DÙNG CÙNG LÚC: hạn mức Gemini là của CẢ trang (một khoá) → chia đều cho mọi người:
//  • mỗi người (theo IP) tối đa PER_MIN câu / phút — một người hỏi dồn không làm người khác hết lượt
//  • mỗi máy chủ tối đa MAX_INFLIGHT câu đang chờ cùng lúc; quá thì trả "bận" NGAY (app dùng câu trả lời có sẵn)
//  • Google chậm quá 18 giây thì bỏ, Google báo hết lượt (429) thì báo "bận" kèm thời gian thử lại
// Có Upstash Redis (đã dùng cho thống kê) thì đếm chung cho mọi máy chủ; không có thì đếm trong từng máy chủ.
const PER_MIN = Number(process.env.AI_PER_MIN || 8);
const MAX_INFLIGHT = Number(process.env.AI_MAX_INFLIGHT || 12);
let inflight = 0;
const local = new Map(); // ip → { m, n }

function redisConf() {
  const url = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;
  return url && token ? { url: url.replace(/\/$/, ''), token } : null;
}

async function overLimit(ip) {
  const minute = Math.floor(Date.now() / 60000);
  const c = redisConf();
  if (c) {
    try {
      const k = `es:ai:${ip}:${minute}`;
      const r = await fetch(`${c.url}/pipeline`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${c.token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify([['INCR', k], ['EXPIRE', k, 90]]),
        signal: AbortSignal.timeout(1500),
      });
      if (r.ok) return (await r.json())[0].result > PER_MIN;
    } catch {
      // Redis chậm / lỗi: đếm tại chỗ, không chặn người dùng vì lỗi của mình
    }
  }
  const e = local.get(ip);
  if (!e || e.m !== minute) {
    local.set(ip, { m: minute, n: 1 });
    if (local.size > 5000) local.clear();
    return false;
  }
  e.n++;
  return e.n > PER_MIN;
}

const busy = (sec, why) =>
  Response.json({ error: 'busy', why }, { status: 429, headers: { 'Retry-After': String(sec), 'Cache-Control': 'no-store' } });

export async function POST(request) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return Response.json({ error: 'AI chưa được bật' }, { status: 503 });

  // chỉ nhận yêu cầu từ chính trang này
  const origin = request.headers.get('origin');
  const host = request.headers.get('x-forwarded-host') || request.headers.get('host');
  if (origin) {
    try {
      if (new URL(origin).host !== host) return Response.json({ error: 'forbidden' }, { status: 403 });
    } catch {
      return Response.json({ error: 'forbidden' }, { status: 403 });
    }
  }

  const url = new URL(request.url);
  const model = url.searchParams.get('model') || process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite';
  if (!MODEL_OK.test(model)) return Response.json({ error: 'model không hợp lệ' }, { status: 400 });

  const body = await request.text();
  if (body.length > MAX_BODY) return Response.json({ error: 'quá dài' }, { status: 413 });

  const ip = (request.headers.get('x-forwarded-for') || '').split(',')[0].trim() || 'x';
  if (await overLimit(ip)) return busy(20, 'per-user');
  if (inflight >= MAX_INFLIGHT) return busy(5, 'server');
  inflight++;
  try {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
      body,
      signal: AbortSignal.timeout(18000),
    });
    if (r.status === 429 || r.status === 503) return busy(30, `google-${r.status}`);
    return new Response(await r.text(), {
      status: r.status,
      headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
    });
  } catch (e) {
    return Response.json({ error: 'timeout' }, { status: 504, headers: { 'Cache-Control': 'no-store' } });
  } finally {
    inflight--;
  }
}

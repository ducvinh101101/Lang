// Vercel Function: THỐNG KÊ LƯỢT DÙNG Lắng (ẩn danh) — cho cả app Windows/Android và bản web.
//
//   POST /api/stats  {"id": "<mã ngẫu nhiên của máy>", "platform": "web|windows|android|ios", "mode": "blind|kid|standard",
//                     "events": ["open", "voice", ...]}
//   GET  /api/stats  → tổng số + 30 ngày gần nhất (trang /stats.html đọc cái này)
//
// Lưu trữ: Upstash Redis (Vercel → Storage → Upstash Redis → Connect to project). Vercel tự thêm biến môi trường
// KV_REST_API_URL + KV_REST_API_TOKEN (hoặc UPSTASH_REDIS_REST_URL + UPSTASH_REDIS_REST_TOKEN).
// KHÔNG lưu thông tin cá nhân: chỉ đếm. "Người dùng khác nhau" đếm bằng HyperLogLog trên mã ngẫu nhiên của máy
// (Redis không giữ lại mã gốc).

const EVENTS = {
  open: 'Lượt mở app',
  blind: 'Lượt dùng chế độ khiếm thị',
  kid: 'Lượt dùng chế độ bạn nhỏ',
  map: 'Lượt khám phá bản đồ bằng âm thanh',
  today: 'Lượt xem bản đồ hôm nay / theo ngày',
  voice: 'Câu lệnh giọng nói',
  ai: 'Câu hỏi cho trợ lý AI',
  weather: 'Lượt nghe thời tiết thật',
  lesson: 'Bài học hoàn thành',
  game: 'Lượt chơi trò chơi',
  challenge: 'Thử thách tìm bằng tai hoàn thành',
};
const PLATFORMS = new Set(['web', 'windows', 'android', 'ios', 'macos', 'linux']);
const MODES = new Set(['blind', 'kid', 'standard']);
const P = 'es:'; // tiền tố khoá

function redisConf() {
  const url = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;
  return url && token ? { url: url.replace(/\/$/, ''), token } : null;
}

async function pipeline(cmds) {
  const c = redisConf();
  if (!c) throw new Error('no-redis');
  const r = await fetch(`${c.url}/pipeline`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${c.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmds),
  });
  if (!r.ok) throw new Error(`redis ${r.status}`);
  return (await r.json()).map((x) => x.result);
}

// ngày theo giờ Việt Nam
function day(d = new Date()) {
  return new Date(d.getTime() + 7 * 3600 * 1000).toISOString().slice(0, 10);
}

const CORS = {
  'Access-Control-Allow-Origin': '*', // app Windows/Android gửi từ ngoài trình duyệt; web gửi cùng tên miền
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function POST(request) {
  // chưa cài Upstash Redis → thống kê đang tắt: trả 200 kèm "off" (không phải lỗi) để app thôi gửi trong lần dùng này
  if (!redisConf()) return Response.json({ ok: false, off: true }, { headers: CORS });
  let b;
  try {
    const t = await request.text();
    if (t.length > 4000) return Response.json({ ok: false }, { status: 413, headers: CORS });
    b = JSON.parse(t);
  } catch {
    return Response.json({ ok: false }, { status: 400, headers: CORS });
  }
  const id = typeof b.id === 'string' && /^[a-zA-Z0-9-]{8,64}$/.test(b.id) ? b.id : null;
  const platform = PLATFORMS.has(b.platform) ? b.platform : 'other';
  const mode = MODES.has(b.mode) ? b.mode : 'standard';
  // app gom sự kiện rồi gửi một lần (~20 giây/lần) → đếm theo số lần xuất hiện, mỗi loại tối đa 50
  const counts = new Map();
  for (const e of Array.isArray(b.events) ? b.events.slice(0, 200) : []) {
    if (e in EVENTS) counts.set(e, Math.min(50, (counts.get(e) || 0) + 1));
  }
  if (!id || counts.size === 0) return Response.json({ ok: false }, { status: 400, headers: CORS });

  // chống spam đơn giản: mỗi máy tối đa 120 lần gửi / giờ — đếm CHUNG một lượt gọi Redis với phần ghi số liệu
  const ip = (request.headers.get('x-forwarded-for') || '').split(',')[0].trim() || 'x';
  const d = day();
  const rl = `${P}rl:${id}:${ip}`;
  const [n] = await pipeline([['INCR', rl], ['EXPIRE', rl, 3600]]).catch(() => [0]);
  if (n > 120) return Response.json({ ok: false, error: 'quá nhiều' }, { status: 429, headers: CORS });

  const cmds = [
    ['PFADD', `${P}users`, id],
    ['PFADD', `${P}users:${d}`, id],
    ['EXPIRE', `${P}users:${d}`, 86400 * 400],
  ];
  for (const [e, k] of counts) {
    cmds.push(['HINCRBY', `${P}total`, e, k]);
    cmds.push(['HINCRBY', `${P}day:${d}`, e, k]);
    if (e === 'open') {
      cmds.push(['HINCRBY', `${P}platform`, platform, 1]);
      cmds.push(['HINCRBY', `${P}mode`, mode, 1]);
    }
  }
  cmds.push(['EXPIRE', `${P}day:${d}`, 86400 * 400]);
  cmds.push(['SADD', `${P}days`, d]);
  try {
    await pipeline(cmds);
  } catch {
    return Response.json({ ok: false }, { status: 503, headers: CORS });
  }
  return Response.json({ ok: true }, { headers: CORS });
}

export async function GET() {
  if (!redisConf()) return Response.json({ ready: false, labels: EVENTS }, { headers: CORS });
  const days = [];
  const now = Date.now();
  for (let k = 29; k >= 0; k--) days.push(day(new Date(now - k * 86400 * 1000)));
  const res = await pipeline([
    ['HGETALL', `${P}total`],
    ['PFCOUNT', `${P}users`],
    ['HGETALL', `${P}platform`],
    ['HGETALL', `${P}mode`],
    ['SMEMBERS', `${P}days`],
    ...days.map((d) => ['HGETALL', `${P}day:${d}`]),
    ...days.map((d) => ['PFCOUNT', `${P}users:${d}`]),
  ]);
  const obj = (arr) => {
    const o = {};
    for (let i = 0; arr && i < arr.length; i += 2) o[arr[i]] = Number(arr[i + 1]);
    return o;
  };
  const allDays = (res[4] || []).sort();
  return Response.json(
    {
      ready: true,
      labels: EVENTS,
      total: obj(res[0]),
      users: res[1] || 0,
      platform: obj(res[2]),
      mode: obj(res[3]),
      since: allDays[0] || null,
      daily: days.map((d, k) => ({ day: d, ...obj(res[5 + k]), users: res[5 + days.length + k] || 0 })),
      updated: new Date().toISOString(),
    },
    { headers: { ...CORS, 'Cache-Control': 's-maxage=60, stale-while-revalidate=300' } },
  );
}

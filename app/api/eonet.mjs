// Vercel Function: danh sách thiên tai đang diễn ra của NASA EONET cho bản web Lắng. Không cần khoá.
//   GET /api/eonet?status=open&days=30&limit=400
// NHIỀU NGƯỜI DÙNG CÙNG LÚC: dữ liệu này giống nhau cho mọi người → CDN của Vercel giữ bản sao 15 phút
// (s-maxage), hết hạn vẫn trả bản cũ ngay trong lúc lấy bản mới (stale-while-revalidate). Mỗi máy chủ còn nhớ
// bản gần nhất: NASA chậm / lỗi thì trả bản đó thay vì báo lỗi.
const OK = new Set(['status', 'days', 'limit', 'category', 'start', 'end', 'bbox']);
const mem = new Map(); // khoá → { t, body }
const TTL = 10 * 60 * 1000;

export async function GET(request) {
  const src = new URL(request.url).searchParams;
  const q = new URLSearchParams();
  for (const k of [...src.keys()].sort()) {
    const v = src.get(k);
    if (OK.has(k) && v.length < 40) q.set(k, v);
  }
  const key = q.toString();
  const hit = mem.get(key);
  if (hit && Date.now() - hit.t < TTL) return reply(hit.body, 'hit');
  try {
    const r = await fetch(`https://eonet.gsfc.nasa.gov/api/v3/events?${q}`, { signal: AbortSignal.timeout(12000) });
    if (!r.ok) throw new Error(`EONET ${r.status}`);
    const body = await r.text();
    mem.set(key, { t: Date.now(), body });
    if (mem.size > 20) mem.delete(mem.keys().next().value);
    return reply(body, 'miss');
  } catch (e) {
    if (hit) return reply(hit.body, 'stale');
    return Response.json({ error: String(e) }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
}

function reply(body, state) {
  return new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300, s-maxage=900, stale-while-revalidate=3600',
      'X-Cache-State': state,
    },
  });
}

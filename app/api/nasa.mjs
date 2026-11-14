// Vercel Function: số liệu khí hậu NASA POWER (theo tháng, 1981 → nay) cho bản web Lắng. Không cần khoá.
//   GET /api/nasa?parameters=T2M,PRECTOTCORR&community=AG&latitude=..&longitude=..&start=1981&end=2025&format=JSON
// Số liệu quá khứ gần như không đổi → CDN giữ 1 ngày (dùng lại tới 1 tuần trong lúc lấy bản mới); NASA POWER chậm
// (vài giây) nên lần thứ hai trở đi ở cùng một nơi trả về gần như tức thì, dù nhiều người cùng hỏi.
const OK = new Set(['parameters', 'community', 'latitude', 'longitude', 'start', 'end', 'format']);
const mem = new Map();
const TTL = 24 * 3600 * 1000;

export async function GET(request) {
  const src = new URL(request.url).searchParams;
  const q = new URLSearchParams();
  for (const k of [...src.keys()].sort()) {
    const v = src.get(k);
    if (OK.has(k) && v.length < 60) q.set(k, v);
  }
  const lat = Number(q.get('latitude')), lon = Number(q.get('longitude'));
  if (!(Math.abs(lat) <= 90 && Math.abs(lon) <= 180)) return Response.json({ error: 'toạ độ sai' }, { status: 400 });
  const key = q.toString();
  const hit = mem.get(key);
  if (hit && Date.now() - hit.t < TTL) return reply(hit.body, 'hit');
  try {
    const r = await fetch(`https://power.larc.nasa.gov/api/temporal/monthly/point?${q}`, { signal: AbortSignal.timeout(25000) });
    const body = await r.text();
    if (!r.ok) {
      if (hit) return reply(hit.body, 'stale');
      return new Response(body, { status: r.status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
    }
    mem.set(key, { t: Date.now(), body });
    if (mem.size > 200) mem.delete(mem.keys().next().value);
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
      'Cache-Control': 'public, max-age=86400, s-maxage=86400, stale-while-revalidate=604800',
      'X-Cache-State': state,
    },
  });
}

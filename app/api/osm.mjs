// Vercel Function: hỏi OpenStreetMap (Overpass) thay cho bản web Lắng — "quanh đây có gì".
//   GET /api/osm?data=<câu hỏi Overpass QL>
// Vì sao cần: nhiều mạng / trình duyệt chặn gọi thẳng máy chủ Overpass (lỗi CORS, "Failed to fetch"), máy chủ chính
// hay quá tải. Hàm này hỏi song song 3 máy chủ, lấy câu trả lời đầu tiên; CDN của Vercel giữ bản sao 1 ngày
// (bản đồ quanh một điểm hầu như không đổi) nên người sau hỏi cùng chỗ nhận ngay.
// Chỉ nhận câu hỏi dạng đọc (out:json, có around/bbox), dài tối đa 4 KB — không cho dùng làm proxy tuỳ ý.
const HOSTS = ['overpass-api.de', 'overpass.kumi.systems', 'overpass.private.coffee', 'maps.mail.ru/osm/tools/overpass'];
const mem = new Map(); // câu hỏi → { t, body }
const TTL = 6 * 60 * 60 * 1000;

export async function GET(request) {
  const q = new URL(request.url).searchParams.get('data') || '';
  if (!q || q.length > 4096 || !q.startsWith('[out:json]') || !/around:\d{1,5},/.test(q)) {
    return Response.json({ error: 'bad query' }, { status: 400, headers: { 'Cache-Control': 'no-store' } });
  }
  const hit = mem.get(q);
  if (hit && Date.now() - hit.t < TTL) return reply(hit.body, 'hit');
  const ctl = new AbortController();
  try {
    const body = await Promise.any(
      HOSTS.map(async (h) => {
        // POST (như Overpass khuyên dùng) — một số máy chủ chặn GET dài từ máy chủ đám mây
        const t0 = setTimeout(() => ctl.abort(), 24000); // Vercel cho tối đa 30 giây
        const r = await fetch(`https://${h}/api/interpreter`, {
          method: 'POST',
          headers: {
            'User-Agent': 'Lang/1.0 (NASA Space Apps 2026 app for blind users; https://sense-app-two.vercel.app)',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: `data=${encodeURIComponent(q)}`,
          signal: ctl.signal,
        }).finally(() => clearTimeout(t0));
        if (!r.ok) throw new Error(`${h} ${r.status}`);
        const t = await r.text();
        if (!t.startsWith('{')) throw new Error(`${h} not json`);
        return t;
      }),
    );
    ctl.abort(); // huỷ các máy chủ chậm hơn
    mem.set(q, { t: Date.now(), body });
    if (mem.size > 200) mem.delete(mem.keys().next().value);
    return reply(body, 'miss');
  } catch (e) {
    if (hit) return reply(hit.body, 'stale');
    // ghi rõ từng máy chủ lỗi gì (để biết vì sao)
    const why = e && e.errors ? e.errors.map((x) => String(x && x.message ? x.message : x)) : [String(e)];
    return Response.json({ error: 'overpass', why }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
}

function reply(body, state) {
  return new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800',
      'X-Cache-State': state,
    },
  });
}

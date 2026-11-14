// Vercel Function: ẢNH THIÊN VĂN HÔM NAY của NASA (APOD) cho bản web Lắng.
//   GET /api/apod
// Khoá NASA_API_KEY đặt trong Vercel → Environment Variables (đăng ký miễn phí tại api.nasa.gov), không lộ ra trình duyệt.
// Ảnh giống nhau cho mọi người trong ngày → CDN giữ 1 giờ: hàng nghìn người mở cùng lúc vẫn chỉ tốn
// khoảng một lượt gọi NASA mỗi giờ (khoá DEMO_KEY chỉ có 30 lượt/giờ).
let mem = null; // { t, body }
const TTL = 3600 * 1000;

export async function GET() {
  if (mem && Date.now() - mem.t < TTL) return reply(mem.body, 'hit');
  const key = process.env.NASA_API_KEY || 'DEMO_KEY';
  try {
    // NASA đôi khi báo lỗi 500 cho ảnh "hôm nay" (chưa đăng xong, hoặc máy chủ trục trặc) → lấy ảnh hôm qua, rồi hôm kia
    let body = null, last = '';
    // Bài là video nhúng thì NASA đôi khi trả lời giải thích hỏng ("To view this video please enable JavaScript…")
    // → bỏ qua, lấy ngày trước đó có lời giải thích thật (người khiếm thị nghe phần giải thích)
    const until = Date.now() + 24000; // Vercel cho tối đa 30 giây
    for (let back = 0; back <= 4 && body == null && Date.now() < until; back++) {
      const day = back === 0 ? '' : `&date=${new Date(Date.now() - (back * 24 + 5) * 3600 * 1000).toISOString().slice(0, 10)}`;
      let r;
      try {
        r = await fetch(`https://api.nasa.gov/planetary/apod?thumbs=true${day}&api_key=${encodeURIComponent(key)}`, {
          signal: AbortSignal.timeout(Math.max(2000, Math.min(8000, until - Date.now()))),
        });
      } catch (e) {
        last = String(e); // NASA chậm quá → thử ngày trước (thường đã có sẵn trong bộ nhớ đệm của NASA)
        continue;
      }
      if (!r.ok) {
        last = `APOD ${r.status}`;
        continue;
      }
      const t = await r.text();
      let ex = '';
      try {
        ex = String(JSON.parse(t).explanation || '');
      } catch (_) {}
      if (ex.length < 80 || /enable JavaScript|upgrading to a web browser/i.test(ex)) {
        last = 'APOD explanation missing';
        continue;
      }
      body = t;
    }
    if (body == null) throw new Error(last);
    mem = { t: Date.now(), body };
    return reply(body, 'miss');
  } catch (e) {
    if (mem) return reply(mem.body, 'stale');
    return Response.json({ error: String(e) }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
}

function reply(body, state) {
  return new Response(body, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=600, s-maxage=3600, stale-while-revalidate=86400',
      'X-Cache-State': state,
    },
  });
}

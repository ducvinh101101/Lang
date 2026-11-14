// Vercel Function: GIỌNG ĐỌC TIẾNG VIỆT cho bản web (cùng giọng Piper "vais1000" đóng gói trong app máy tính).
//   GET /api/tts?t=<câu>&s=<tốc độ 0.5–2>   → audio/wav (16-bit, 22 kHz)
//   GET /api/tts?ping=1                     → {"ok": true}
// Vì sao: Chrome trên Windows, Firefox… KHÔNG có giọng tiếng Việt → đọc tiếng Việt bằng giọng Anh rất khó nghe.
// Edge (HoaiMy/NamMinh), Safari (Linh), Chrome Android (Google) có giọng Việt tốt → app vẫn dùng giọng của trình duyệt.
// NHIỀU NGƯỜI DÙNG: mỗi đoạn câu là một địa chỉ cố định → CDN của Vercel giữ bản đã đọc 1 năm; câu hay gặp
// (lời chào, hướng dẫn, tên nơi…) chỉ tổng hợp một lần cho mọi người. Mô hình nạp một lần cho mỗi máy chủ (~1 giây).
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const MAX_CHARS = 400;
const PER_MIN = 150; // đoạn câu / phút / IP
let tts = null;
let loading = null;
const hits = new Map();

// Thư mục làm việc của hàm trên Vercel không cố định (gốc dự án, hoặc có thêm thư mục con "app/" khi dự án đặt
// Root Directory) → tìm theo cả thư mục chạy lẫn vị trí của chính tệp này.
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOTS = [process.cwd(), path.join(HERE, '..'), HERE, path.join(process.cwd(), 'app'), '/var/task', '/var/task/app'];
let foundDir;
function modelDir() {
  if (foundDir !== undefined) return foundDir;
  for (const r of ROOTS) {
    for (const d of ['assets/voices/vi', '_tts/vi']) {
      const p = path.join(r, d);
      if (fs.existsSync(path.join(p, 'tokens.txt'))) return (foundDir = p);
    }
  }
  return (foundDir = null);
}

function load() {
  if (tts) return Promise.resolve(tts);
  loading ??= (async () => {
    const dir = modelDir();
    if (!dir) throw new Error('no-model');
    // mô hình ~63 MB được chia 3 phần (giới hạn GitHub) → ghép một lần vào /tmp của máy chủ
    const model = '/tmp/earthsense-vi.onnx';
    if (!fs.existsSync(model)) {
      const parts = fs.readdirSync(dir).filter((f) => f.startsWith('model.onnx.part')).sort();
      fs.writeFileSync(model + '.tmp', Buffer.concat(parts.map((p) => fs.readFileSync(path.join(dir, p)))));
      fs.renameSync(model + '.tmp', model);
    }
    const sherpa = require('sherpa-onnx-node');
    tts = new sherpa.OfflineTts({
      model: {
        vits: { model, tokens: path.join(dir, 'tokens.txt'), dataDir: path.join(dir, 'espeak-ng-data') },
        numThreads: 1,
        debug: false,
        provider: 'cpu',
      },
      maxNumSentences: 1,
    });
    return tts;
  })();
  loading.catch(() => {
    loading = null;
  });
  return loading;
}

function wav(samples, rate) {
  const n = samples.length;
  const b = Buffer.alloc(44 + n * 2);
  b.write('RIFF', 0);
  b.writeUInt32LE(36 + n * 2, 4);
  b.write('WAVE', 8);
  b.write('fmt ', 12);
  b.writeUInt32LE(16, 16);
  b.writeUInt16LE(1, 20);
  b.writeUInt16LE(1, 22);
  b.writeUInt32LE(rate, 24);
  b.writeUInt32LE(rate * 2, 28);
  b.writeUInt16LE(2, 32);
  b.writeUInt16LE(16, 34);
  b.write('data', 36);
  b.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  return b;
}

function limited(ip) {
  const m = Math.floor(Date.now() / 60000);
  const e = hits.get(ip);
  if (!e || e.m !== m) {
    hits.set(ip, { m, n: 1 });
    if (hits.size > 5000) hits.clear();
    return false;
  }
  return ++e.n > PER_MIN;
}

export async function GET(request) {
  const url = new URL(request.url);
  if (url.searchParams.has('ping')) {
    const dir = modelDir();
    return Response.json(
      // chưa thấy mô hình → kèm các chỗ đã tìm để dễ sửa cấu hình deploy
      dir ? { ok: true } : { ok: false, cwd: process.cwd(), here: HERE, tried: ROOTS },
      { headers: { 'Cache-Control': dir ? 'public, max-age=300, s-maxage=300' : 'no-store', 'Access-Control-Allow-Origin': '*' } },
    );
  }
  const text = (url.searchParams.get('t') || '').replace(/[\u0000-\u001f]/g, ' ').trim();
  const speed = Math.min(2, Math.max(0.5, Number(url.searchParams.get('s')) || 1));
  if (!text || text.length > MAX_CHARS) return Response.json({ error: 'text' }, { status: 400 });
  const ip = (request.headers.get('x-forwarded-for') || '').split(',')[0].trim() || 'x';
  if (limited(ip)) return Response.json({ error: 'busy' }, { status: 429, headers: { 'Retry-After': '10' } });
  try {
    const engine = await load();
    const a = engine.generate({ text, sid: 0, speed });
    return new Response(wav(a.samples, a.sampleRate), {
      headers: {
        'Content-Type': 'audio/wav',
        'Access-Control-Allow-Origin': '*', // cho bản chạy thử trên máy (localhost) dùng giọng của trang đã deploy
        // cùng câu + cùng tốc độ luôn ra cùng một tiếng → CDN giữ lâu, dùng chung cho mọi người
        'Cache-Control': 'public, max-age=86400, s-maxage=31536000, immutable',
      },
    });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}

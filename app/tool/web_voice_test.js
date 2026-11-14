// THỬ BẢN WEB BẰNG GIỌNG NÓI GIẢ LẬP — không cần micro, không cần nói.
// Cách dùng: mở https://sense-app-two.vercel.app/ → F12 → tab Console → dán TOÀN BỘ tệp này → Enter
// → bấm "Chạm bất kỳ đâu để bắt đầu". Script tự "nói" từng câu khó vào app (thay bộ nhận giọng của trình duyệt),
// ghi lại app hiểu thành lệnh gì và trả lời gì, rồi in bảng ĐẠT / SAI ở cuối (console.table).
// GPS giả: đứng cạnh Hồ Gươm (Hà Nội). Đổi CASES bên dưới để thêm câu.
(() => {
  const CASES = [
    // [câu nói, chữ PHẢI có trong lời app (bỏ trống = chỉ cần có trả lời), chữ KHÔNG được có]
    ['tôi đang ở đâu', 'Hà Nội', 'Bạn đang ở Việt Nam.'],
    ['thời tiết chỗ tôi', 'độ', 'Phần thời tiết'],
    ['thời tiết ở đắk nông', 'Lâm Đồng', 'Quảng Ngãi'],
    ['hà giang có mưa không', 'Hà Giang', 'không tìm thấy'],
    ['thời tiết xã gia lâm hà nội', 'Gia Lâm', ''],
    ['salon tóc gần đây', 'không tìm cửa hàng', 'lỗi 500'],
    ['cảng nội địa gia lâm', 'Gia Lâm', 'cảng nội địa Gia Lâm,'],
    ['tuần sau sa pa có lạnh không', 'Sa Pa', 'không tìm thấy'],
    ['ngày mai đà nẵng có mưa không', 'Đà Nẵng', ''],
    ['hà lội có nắng không', 'Hà Nội', 'Xóm'],
    ['chỉ số uv ở thành phố hồ chí minh hôm nay', 'UV', ''],
    ['độ cao đỉnh phan xi păng', '3.143', ''],
    ['địa hình từ hà nội đến lào cai', 'Lát cắt', ''],
    ['sao hỏa có mấy mặt trăng', 'Phobos', 'Tập truyện: Mặt Trăng'],
    ['nói chậm thôi', 'chậm hơn', 'Vâng'],
    ['ừm à ờ', null, 'chưa hiểu'], // null = app PHẢI im lặng
    ['ảnh thiên văn hôm nay là gì', 'NASA', 'không liên quan'],
    ['xưa và nay ở hà nội', 'ấm hơn', 'mát hơn'],
    ['quanh đây có gì', '', 'chưa có nhiều thông tin'],
    ['phóng to', '', 'Nga'],
    ['thời tiết thành phố huế', 'Huế', ''],
    ['bình dương có nóng không', 'Bình Dương', 'không tìm thấy'],
    ['đây là đâu', '', ''],
    ['nghe 24 giờ tới', '24 giờ tới', 'Nghèn'],
    ['nghe 24 giờ tới ở huế', 'Huế', 'Nghèn'],
  ];

  const log = [];
  window.__voiceLog = log;
  for (const k of ['log', 'info']) {
    const o = console[k].bind(console);
    console[k] = (...a) => {
      try { log.push([Date.now(), a.join(' ')]); } catch (_) {}
      o(...a);
    };
  }
  const queue = [];
  class FakeRec {
    constructor() { this.lang = 'vi-VN'; this._dead = false; }
    start() {
      setTimeout(() => { this.onstart?.({}); this.onaudiostart?.({}); }, 10);
      const t0 = Date.now();
      const poll = () => {
        if (this._dead) return;
        const s = queue.shift();
        if (s !== undefined) {
          this.onspeechstart?.({});
          const ev = { results: { length: 1, 0: { isFinal: true, 0: { transcript: s, confidence: 0.9 } } } };
          setTimeout(() => {
            if (this._dead) return;
            this.onresult?.(ev);
            setTimeout(() => { this._dead = true; this.onend?.({}); }, 50);
          }, 150);
          return;
        }
        if (Date.now() - t0 > 4000) { this._dead = true; this.onerror?.({ error: 'no-speech' }); this.onend?.({}); return; }
        this._t = setTimeout(poll, 100);
      };
      this._t = setTimeout(poll, 100);
    }
    stop() { if (this._dead) return; this._dead = true; clearTimeout(this._t); this.onend?.({}); }
    abort() { this.stop(); }
  }
  window.SpeechRecognition = FakeRec;
  window.webkitSpeechRecognition = FakeRec;
  const pos = { coords: { latitude: 21.0287, longitude: 105.8523, accuracy: 15, altitude: null, altitudeAccuracy: null, heading: null, speed: null } };
  // trình duyệt coi như đã cho phép vị trí (để thử phần GPS)
  try {
    const oq = navigator.permissions.query.bind(navigator.permissions);
    navigator.permissions.query = (d) =>
      d && d.name === 'geolocation' ? Promise.resolve({ state: 'granted', onchange: null, addEventListener() {}, removeEventListener() {} }) : oq(d);
  } catch (_) {}
  try {
    Object.defineProperty(navigator, 'geolocation', {
      configurable: true,
      value: {
        getCurrentPosition: (ok) => setTimeout(() => ok({ ...pos, timestamp: Date.now() }), 100),
        watchPosition: (ok) => { setTimeout(() => ok({ ...pos, timestamp: Date.now() }), 100); return 1; },
        clearWatch: () => {},
      },
    });
  } catch (_) {}

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const said = (from) => log.slice(from).map((x) => x[1]).filter((m) => m.includes('[app nói]')).map((m) => m.slice(m.indexOf('[app nói]') + 10));

  async function run() {
    // chờ app vào vòng nghe (sau khi bấm bắt đầu)
    while (!log.some((x) => x[1].includes('bắt đầu nghe'))) await sleep(300);
    await sleep(8000); // lời chào
    const rows = [];
    for (const [s, must, mustNot] of CASES) {
      const i0 = log.length, t0 = Date.now();
      queue.push(s);
      let last = log.length, quiet = Date.now(), until = 0;
      while (Date.now() - t0 < 60000) {
        await sleep(250);
        if (log.length !== last) {
          for (const [ts, m] of log.slice(last)) {
            const k = m.indexOf('[app nói] ');
            if (k >= 0) until = Math.max(until, ts) + ((m.length - k) / 13) * 1000; // ~13 chữ / giây
          }
          last = log.length;
          quiet = Date.now();
        }
        const any = said(i0).length > 0;
        if (any && Date.now() > until + 800 && Date.now() - quiet > 1500) break;
        if (!any && Date.now() - t0 > 15000 && Date.now() - quiet > 4000) break;
      }
      const out = said(i0).join(' ');
      const cmd = (log.slice(i0).map((x) => x[1]).find((m) => m.includes('[lệnh]')) || '').replace(/^.*→ /, '');
      let ok;
      if (must === null) ok = out === '' || !out.includes(mustNot);
      else ok = out !== '' && (!must || out.includes(must)) && (!mustNot || !out.includes(mustNot));
      rows.push({ 'câu nói': s, 'kết quả': ok ? 'ĐẠT' : 'SAI', 'giây': Math.round((Date.now() - t0) / 1000), 'lệnh': cmd.slice(0, 60), 'app nói': out.slice(0, 160) });
      console.log(`[thử giọng] ${ok ? 'ĐẠT' : 'SAI'} "${s}" → ${out.slice(0, 200)}`);
    }
    console.table(rows);
    const bad = rows.filter((r) => r['kết quả'] === 'SAI').length;
    console.log(`[thử giọng] XONG: ${rows.length - bad}/${rows.length} đạt`);
    window.__voiceResult = rows;
  }
  run();
  return 'Đã cài micro giả — hãy bấm "Chạm bất kỳ đâu để bắt đầu".';
})();

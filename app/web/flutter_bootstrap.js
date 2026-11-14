{{flutter_js}}
{{flutter_build_config}}

// Tải app ngầm ngay khi mở trang, nhưng chỉ CHẠY sau khi người dùng bấm "Bắt đầu" (hoặc Enter / Space):
// lần chạm đó mở khoá âm thanh (Web Audio) và giọng đọc (speechSynthesis) của trình duyệt.
(function () {
  const btn = document.getElementById('go');
  const status = document.getElementById('status');
  let clicked = false, runner = null, started = false;

  function say(text) { if (status) status.textContent = text; }

  // Đọc to trạng thái (người khiếm thị không thấy chữ "Đang tải…"); dùng giọng của trình duyệt
  function speak(text) {
    try {
      if (!('speechSynthesis' in window)) return;
      let en = false;
      try { en = JSON.parse(window.localStorage.getItem('flutter.lang') || '""') === 'en'; } catch (_) {}
      const u = new SpeechSynthesisUtterance(en ? 'Loading Lang, one moment.' : text);
      u.lang = en ? 'en-US' : 'vi-VN';
      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(u);
    } catch (_) {}
  }

  // Mở khoá giọng đọc của trình duyệt ngay trong lần bấm (Chrome chặn speechSynthesis khi chưa tương tác)
  function unlockSpeech() {
    try {
      if ('speechSynthesis' in window) {
        const u = new SpeechSynthesisUtterance(' ');
        u.volume = 0;
        window.speechSynthesis.speak(u);
      }
    } catch (_) {}
  }

  async function maybeStart() {
    if (!clicked || !runner || started) return;
    started = true;
    say('Đang mở Lắng…');
    await runner.runApp();
    const s = document.getElementById('start');
    if (s) s.remove();
  }

  // Lưu chế độ đọc cho app (shared_preferences trên web = localStorage, khoá "flutter.<tên>", giá trị dạng JSON)
  function setSpeechMode(mode) {
    try { window.localStorage.setItem('flutter.speechMode', JSON.stringify(mode)); } catch (_) {}
  }

  // CHẠM BẤT KỲ ĐÂU (hoặc nhấn phím bất kỳ) là bắt đầu — không phải tìm nút, không phải chọn chế độ.
  // App tự đọc to (chế độ tự động); trình duyệt bắt buộc có MỘT lần chạm mới cho phát tiếng / dùng micro.
  function startOnce(e) {
    if (clicked) return;
    if (e && e.type === 'keydown' && (e.key === 'Tab' || e.key === 'Shift')) return; // để trình đọc màn hình di chuyển
    setSpeechMode('auto');
    go();
  }
  document.addEventListener('pointerdown', startOnce, { capture: true });
  document.addEventListener('keydown', startOnce, { capture: true });
  if (btn) btn.addEventListener('click', startOnce);

  function go() {
      clicked = true;
      unlockSpeech();
      if (btn) {
        btn.setAttribute('aria-busy', 'true');
        btn.textContent = runner ? 'Đang mở…' : 'Đang tải…';
      }
      say(runner ? 'Đang mở Lắng…' : 'Đang tải ứng dụng, chờ một chút…');
      if (!runner) speak('Đang tải ứng dụng, chờ một chút nhé.');
      maybeStart();
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      runner = await engineInitializer.initializeEngine();
      if (!clicked) say('Sẵn sàng. Chạm vào bất kỳ đâu trên màn hình để bắt đầu.');
      maybeStart();
    },
  });
})();

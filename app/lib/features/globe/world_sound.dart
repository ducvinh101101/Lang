// NGHE THỜI TIẾT / KHÍ HẬU bằng nhạc cụ Việt cho một điểm bất kỳ trên quả địa cầu.
//  • đàn bầu: nhiệt độ (càng nóng nốt càng cao; luyến từ nhiệt độ thật sang "cảm giác như")
//  • t'rưng: mưa (càng nhiều tiếng lách cách càng dễ mưa)
//  • sóng: gió (càng to gió càng mạnh)
//  • chiêng: nắng gắt (UV cao)
//  • tiếng lép bép: không khí ô nhiễm
import 'dart:async';
import 'dart:math' as math;

import '../../audio/audio_engine.dart';
import '../../data/nasa_normalized_data.dart';
import '../../live/live_weather.dart';
import '../../live/nasa_power.dart';

/// −10 °C … 40 °C → 0 … 1
double tempX(double t) => ((t + 10) / 50).clamp(0.0, 1.0);

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

class WorldSound {
  final AudioEngine audio;
  WorldSound(this.audio);

  /// true = lệnh đang gọi đã bị lệnh mới thay → không chơi nữa (GlobePage gán).
  bool Function()? hold;

  int _gen = 0;
  bool get playing => _playing;
  bool _playing = false;

  void stop() {
    if (hold?.call() ?? false) return; // lệnh cũ không được tắt nhạc của lệnh mới
    _gen++;
    _playing = false;
    _endPhrase();
  }

  // Chuỗi nốt (24 giờ, các năm, 12 tháng) chơi như MỘT câu đàn bầu liền tiếng: dây ngân liên tục, nốt sau
  // luyến từ nốt trước (uốn cần đàn), quãng xa thì gảy lại — nghe như người chơi đàn thật thay vì từng tiếng rời.
  DanbauPhrase? _phrase;

  Future<void> _note(double f, double pan, int stepMs, int my) async {
    if (my != _gen) return;
    final p = _phrase;
    if (p == null) {
      final np = await audio.phraseStart(f, pan: pan, amp: 0.24);
      if (my != _gen) {
        np?.end(ms: 80); // đã bị dừng trong lúc chờ: không để dây ngân mãi
        return;
      }
      _phrase = np;
    } else {
      p.to(f, pan: pan, stepMs: stepMs);
    }
  }

  void _endPhrase() {
    _phrase?.end();
    _phrase = null;
  }

  /// Bây giờ ở một nơi: khoảng 2,5 giây.
  Future<void> now(LiveWeather w) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      final n = w.now;
      final f0 = toScale(tempX(n.temp)), f1 = toScale(tempX(n.feels));
      unawaited(audio.danbauNote(f0, f1, 1.1, 0.32, 0));
      final today = w.days.isNotEmpty ? w.days.first : null;
      final rainP = math.max((w.hours.take(6).map((h) => h.rainProb ?? 0).fold<int>(0, math.max)) / 100,
          n.precip > 0.1 ? 0.9 : 0.0);
      await _wait(500);
      if (my != _gen) return;
      if (n.wind >= 8) audio.song((n.wind / 60).clamp(0.12, 0.6), 0);
      if (rainP >= 0.2) {
        final k = (rainP * 10).round();
        for (var j = 0; j < k && my == _gen; j++) {
          audio.trung(randHigh(), 0.10 + 0.18 * rainP, -0.6 + 1.2 * _rnd.nextDouble());
          await _wait(70);
        }
      }
      final uv = n.uv ?? today?.uv ?? 0;
      if (uv >= 6 && my == _gen) {
        await _wait(150);
        audio.chieng((0.12 + (uv - 6) * 0.04).clamp(0.12, 0.4));
      }
      if ((w.aqi ?? 0) > 100 && my == _gen) {
        for (var j = 0; j < 8 && my == _gen; j++) {
          audio.crackle(((w.aqi! - 100) / 150).clamp(0.2, 0.8), -0.5 + _rnd.nextDouble());
          await _wait(60);
        }
      }
      await _wait(900);
    } finally {
      if (my == _gen) _playing = false;
    }
  }

  /// 24 giờ tới: mỗi giờ một nốt, từ tai trái sang tai phải; t'rưng khi giờ đó dễ mưa.
  Future<void> hours(LiveWeather w, {int count = 24}) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      final hs = w.hours.take(count).toList();
      for (var k = 0; k < hs.length && my == _gen; k++) {
        final h = hs[k];
        final pan = hs.length <= 1 ? 0.0 : -0.85 + 1.7 * k / (hs.length - 1);
        await _note(toScale(tempX(h.temp)), pan, 300, my);
        final p = (h.rainProb ?? 0) / 100;
        if (p >= 0.3) {
          for (var j = 0; j < (p * 5).round(); j++) {
            Future.delayed(Duration(milliseconds: 40 + j * 45), () {
              if (my == _gen) audio.trung(randHigh(), 0.1 + 0.15 * p, pan);
            });
          }
        }
        await _wait(300);
      }
    } finally {
      if (my == _gen) {
        _playing = false;
        _endPhrase();
      }
    }
  }

  /// Chuỗi năm NASA: mỗi năm một nốt (thấp = năm mát nhất, cao = năm nóng nhất trong chuỗi), trái → phải.
  /// Năm mưa nhiều hơn bình thường có thêm tiếng t'rưng.
  Future<void> years(NasaClimate c) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      final t = c.tempYear;
      final valid = t.where((x) => !x.isNaN).toList();
      if (valid.isEmpty) return;
      final lo = valid.reduce(math.min), hi = valid.reduce(math.max);
      final rv = c.rainYear.where((x) => !x.isNaN).toList();
      final rMean = rv.isEmpty ? double.nan : rv.reduce((a, b) => a + b) / rv.length;
      for (var k = 0; k < t.length && my == _gen; k++) {
        if (t[k].isNaN) {
          await _wait(160);
          continue;
        }
        final x = hi - lo < 0.05 ? 0.5 : (t[k] - lo) / (hi - lo);
        final pan = t.length <= 1 ? 0.0 : -0.85 + 1.7 * k / (t.length - 1);
        await _note(toScale(0.15 + 0.8 * x), pan, 230, my);
        final r = c.rainYear[k];
        if (!rMean.isNaN && !r.isNaN && r > rMean * 1.1) {
          final n = ((r / rMean - 1) * 12).round().clamp(1, 4);
          for (var j = 0; j < n; j++) {
            Future.delayed(Duration(milliseconds: 30 + j * 40), () {
              if (my == _gen) audio.trung(randHigh(), 0.12, pan);
            });
          }
        }
        // mỗi thập kỷ một tiếng mõ để biết đang ở đâu trong chuỗi
        if ((c.y0 + k) % 10 == 0) audio.mo();
        await _wait(230);
      }
    } finally {
      if (my == _gen) {
        _playing = false;
        _endPhrase();
      }
    }
  }

  /// 12 tháng của một năm (NASA): nốt theo nhiệt độ, t'rưng theo mưa.
  Future<void> months(List<double> temp, List<double> rain) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      for (var m = 0; m < 12 && my == _gen; m++) {
        final pan = -0.85 + 1.7 * m / 11;
        if (!temp[m].isNaN) await _note(toScale(tempX(temp[m])), pan, 380, my);
        final r = rain[m];
        if (!r.isNaN && r > 50) {
          final n = (r / 100).round().clamp(1, 6);
          for (var j = 0; j < n; j++) {
            Future.delayed(Duration(milliseconds: 40 + j * 45), () {
              if (my == _gen) audio.trung(randHigh(), 0.12, pan);
            });
          }
        }
        await _wait(380);
      }
    } finally {
      if (my == _gen) {
        _playing = false;
        _endPhrase();
      }
    }
  }

  /// Một ngày: nốt nhiệt độ thấp → cao nhất, t'rưng theo lượng mưa, sóng theo gió.
  Future<void> day(DayRecord d) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      unawaited(audio.danbauNote(toScale(tempX(d.tmin)), toScale(tempX(d.tmax)), 1.2, 0.3, 0));
      await _wait(600);
      if (!d.wind.isNaN && d.wind >= 10 && my == _gen) audio.song((d.wind / 70).clamp(0.12, 0.6), 0);
      if (!d.rain.isNaN && d.rain >= 1) {
        final n = (d.rain / 4).round().clamp(2, 14);
        for (var j = 0; j < n && my == _gen; j++) {
          audio.trung(randHigh(), 0.16, -0.6 + 1.2 * _rnd.nextDouble());
          await _wait(65);
        }
      }
      await _wait(700);
    } finally {
      if (my == _gen) _playing = false;
    }
  }

  /// 12 tháng điểm cháy rừng NASA FIRMS (MODIS MCD14ML):
  /// phát nhạc cụ "tiếng lửa khô" (hạt nổ ngắn dải 1,5–4 kHz qua audio.crackle) từ tai trái sang tai phải,
  /// mật độ hạt tỉ lệ với căn bậc hai số điểm cháy trong tháng; mỗi quý điểm một nhịp trống trầm.
  Future<void> fireHotspots(List<int> monthlyHotspots) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      if (monthlyHotspots.isEmpty) return;
      final maxVal = monthlyHotspots.reduce(math.max).clamp(1, 999999);
      for (var m = 0; m < monthlyHotspots.length && my == _gen; m++) {
        final pan = monthlyHotspots.length <= 1 ? 0.0 : -0.85 + 1.7 * m / (monthlyHotspots.length - 1);
        final count = monthlyHotspots[m];
        final ratio = math.sqrt(count / maxVal).clamp(0.08, 1.0);
        // Mỗi quý (tháng 1, 4, 7, 10) gõ một nhịp trống trầm đánh dấu mùa
        if (m % 3 == 0) audio.trong(0.14, pan);
        final grains = (1 + ratio * 7).round().clamp(1, 8);
        for (var g = 0; g < grains && my == _gen; g++) {
          final jitterPan = (pan + (_rnd.nextDouble() - 0.5) * 0.18).clamp(-1.0, 1.0);
          audio.crackle((0.18 + 0.62 * ratio).clamp(0.18, 0.85), jitterPan);
          await _wait((340 / grains).round().clamp(35, 160));
        }
        await _wait(60);
      }
    } finally {
      if (my == _gen) _playing = false;
    }
  }

  /// Chuỗi ngày của một sự kiện thiên tai lịch sử (NASA POWER Daily: Bão Yagi 09/2024, Mưa lũ miền Trung 10/2020):
  /// đàn bầu theo nhiệt độ ngày, t'rưng dồn dập theo lượng mưa (PRECTOTCORR), sóng biển theo tốc độ gió (WS10M).
  Future<void> eventDays(List<HistoricalEventDay> days) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      if (days.isEmpty) return;
      for (var i = 0; i < days.length && my == _gen; i++) {
        final d = days[i];
        final pan = days.length <= 1 ? 0.0 : -0.85 + 1.7 * i / (days.length - 1);
        await _note(toScale(tempX(d.tmaxC)), pan, 280, my);
        if (d.ws10mKmh >= 14) {
          audio.song((d.ws10mKmh / 55).clamp(0.14, 0.65), pan);
        }
        if (d.rainMm >= 5) {
          final drops = (math.sqrt(d.rainMm) * 0.75).round().clamp(1, 9);
          for (var j = 0; j < drops; j++) {
            Future.delayed(Duration(milliseconds: 25 + j * 30), () {
              if (my == _gen) audio.trung(randHigh(), (0.12 + d.rainMm / 600).clamp(0.12, 0.34), pan);
            });
          }
        }
        await _wait(280);
      }
    } finally {
      if (my == _gen) {
        _playing = false;
        _endPhrase();
      }
    }
  }

  /// Chuỗi dị thường nhiệt độ toàn cầu NASA GISTEMP v4 (1880–2025):
  /// lấy mẫu các mốc năm tiêu biểu để phát trong ~9 giây từ tai trái sang tai phải.
  Future<void> gistempYears(List<(int, double)> series) async {
    if (hold?.call() ?? false) return;
    final my = ++_gen;
    _endPhrase();
    _playing = true;
    try {
      if (series.isEmpty) return;
      final step = math.max(1, (series.length / 36).round());
      final sampled = <(int, double)>[];
      for (var i = 0; i < series.length; i += step) {
        sampled.add(series[i]);
      }
      if (sampled.last.$1 != series.last.$1) sampled.add(series.last);
      final vals = [for (final s in sampled) s.$2];
      final lo = vals.reduce(math.min), hi = vals.reduce(math.max);
      for (var k = 0; k < sampled.length && my == _gen; k++) {
        final (yr, anom) = sampled[k];
        final x = hi - lo < 0.05 ? 0.5 : (anom - lo) / (hi - lo);
        final pan = sampled.length <= 1 ? 0.0 : -0.85 + 1.7 * k / (sampled.length - 1);
        await _note(toScale(0.12 + 0.82 * x), pan, 220, my);
        if (yr % 20 == 0 || k == sampled.length - 1) audio.mo();
        await _wait(220);
      }
    } finally {
      if (my == _gen) {
        _playing = false;
        _endPhrase();
      }
    }
  }
}

final _rnd = math.Random();

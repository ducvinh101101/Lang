// Câu chữ mô tả một ô bản đồ — dùng cho phụ đề, đọc chi tiết, trợ lý sau này. Chuyển từ cmpText/detailTexts của bản web.
import '../app_state.dart';
import '../core/format.dart';
import '../core/geo.dart';
import '../data/climate_data.dart';

typedef Bi = ({String vi, String en});

Bi compareText(String v, double val, double clim, double sd) {
  if (val.isNaN || clim.isNaN) return (vi: 'không có dữ liệu', en: 'no data');
  final z = (val - clim) / ((sd.isNaN || sd <= 0) ? 1.0 : sd);
  const near = (vi: 'gần mức trung bình', en: 'near normal');
  if (v == 'temp') {
    final d = val - clim;
    if (z.abs() < 1) return near;
    return d > 0
        ? (vi: 'cao hơn trung bình ${fmtNum(d, 1)} độ', en: '${fmtNum(d, 1, lang: 'en')} °C above normal')
        : (vi: 'thấp hơn trung bình ${fmtNum(-d, 1)} độ', en: '${fmtNum(-d, 1, lang: 'en')} °C below normal');
  }
  if (v == 'fire' && clim < 0.05) {
    return val < 0.05 ? (vi: 'gần như không có', en: 'almost none') : (vi: 'cao hơn trung bình', en: 'above normal');
  }
  if (clim <= 0) return near;
  final pct = ((val / clim - 1) * 100).round();
  if (z.abs() < 1) return near;
  return pct > 0
      ? (vi: 'cao hơn trung bình $pct%', en: '$pct% above normal')
      : (vi: 'thấp hơn trung bình ${-pct}%', en: '${-pct}% below normal');
}

/// Từ đơn giản cho trẻ nhỏ thay vì con số + đơn vị. Ngưỡng theo tháng (mưa: mm/tháng), [daily]: theo ngày.
Bi kidWord(String v, double val, double norm, {bool daily = false}) {
  if (val.isNaN) return (vi: 'không có số liệu', en: 'no data');
  if (daily && v == 'rain') {
    if (val < 0.5) return (vi: 'không mưa', en: 'no rain');
    if (val < 5) return (vi: 'mưa nhỏ', en: 'light rain');
    if (val < 20) return (vi: 'mưa vừa', en: 'moderate rain');
    if (val < 50) return (vi: 'mưa to', en: 'heavy rain');
    return (vi: 'mưa rất rất to', en: 'very heavy rain');
  }
  if (daily && v == 'fire') {
    if (val < 0.5) return (vi: 'không có đám cháy', en: 'no fires');
    if (val < 3) return (vi: 'có đám cháy', en: 'some fires');
    return (vi: 'nhiều đám cháy', en: 'many fires');
  }
  switch (v) {
    case 'rain':
      if (val < 30) return (vi: 'gần như không mưa', en: 'almost no rain');
      if (val < 100) return (vi: 'mưa ít', en: 'a little rain');
      if (val < 300) return (vi: 'mưa vừa', en: 'some rain');
      if (val < 600) return (vi: 'mưa nhiều', en: 'lots of rain');
      return (vi: 'mưa rất rất nhiều', en: 'a huge amount of rain');
    case 'temp':
      if (val < 12) return (vi: 'lạnh', en: 'cold');
      if (val < 20) return (vi: 'mát', en: 'cool');
      if (val < 27) return (vi: 'ấm', en: 'warm');
      if (val < 33) return (vi: 'nóng', en: 'hot');
      return (vi: 'rất nóng', en: 'very hot');
    case 'fire':
      if (norm < 0.05) return (vi: 'không có đám cháy', en: 'no fires');
      if (norm < 0.3) return (vi: 'ít đám cháy', en: 'a few fires');
      if (norm < 0.6) return (vi: 'khá nhiều đám cháy', en: 'quite a few fires');
      return (vi: 'rất nhiều đám cháy', en: 'lots of fires');
    default: // biến mới: dùng mức tương đối trong thang của biến
      if (norm < 0.25) return (vi: 'thấp', en: 'low');
      if (norm < 0.6) return (vi: 'vừa', en: 'medium');
      if (norm < 0.85) return (vi: 'cao', en: 'high');
      return (vi: 'rất cao', en: 'very high');
  }
}

class CellReport {
  final int i;
  final int type;
  final int region;
  final String? near;
  final double lon, lat;
  final double value, clim, sd;

  /// 'Hoàng Sa' | 'Trường Sa' | null — ô biển thuộc vùng quần đảo của Việt Nam.
  final String? island;
  CellReport(this.i, this.type, this.region, this.near, this.lon, this.lat, this.value, this.clim, this.sd)
      : island = type == cellVn ? null : islandAt(lon, lat);

  factory CellReport.of(AppState s, int i) {
    final geo = s.mapData.geo;
    final lon = cellLon(i), lat = cellLat(i);
    final type = geo.type[i];
    final isVn = type == cellVn;
    return CellReport(
      i,
      type,
      geo.region[i],
      geo.nearestPlace(lon, lat),
      lon,
      lat,
      isVn ? s.mapData.values(s.v, s.year, s.month)[i] : double.nan,
      isVn ? s.mapData.clim(s.v, i, s.month) : double.nan,
      isVn ? s.mapData.sd(s.v, i, s.month) : double.nan,
    );
  }

  bool get isIslands => island != null;

  Bi _islandName() => (vi: 'Quần đảo $island, Việt Nam', en: '${island == 'Hoàng Sa' ? 'Hoang Sa (Paracel)' : 'Truong Sa (Spratly)'} Islands, Vietnam');

  /// Tên khu vực ngắn, đọc khi rê ngón tay qua ranh giới.
  Bi area() {
    if (type == cellVn) return (vi: regions[region].vi, en: regions[region].en);
    if (island != null) return _islandName();
    if (type == cellSea) return (vi: 'Biển', en: 'Sea');
    return (vi: 'Ngoài lãnh thổ Việt Nam', en: 'Outside Vietnam');
  }

  Bi place() {
    if (island != null) return _islandName();
    if (type == cellSea) return near == null ? (vi: 'Biển', en: 'Sea') : (vi: 'Biển, ngoài khơi $near', en: 'Sea, off $near');
    if (type != cellVn) return (vi: 'Ngoài lãnh thổ Việt Nam', en: 'Outside Vietnam');
    final r = regions[region];
    return near == null ? (vi: r.vi, en: r.en) : (vi: '$near · ${r.vi}', en: '$near · ${r.en}');
  }

  String valueText(AppState s) {
    if (type != cellVn || value.isNaN) return '—';
    final m = s.mapData.vars[s.v]!;
    return '${fmtNum(value, m.decimals, lang: s.lang)} ${m.unit(s.lang)}'.trim();
  }

  String coords(AppState s) {
    final ns = s.t('B', 'N'), ew = s.t('Đ', 'E');
    var out = '${fmtNum(lat, 1, lang: s.lang)}°$ns ${fmtNum(lon, 1, lang: s.lang)}°$ew';
    if (type == cellVn) {
      final km = s.mapData.geo.coastKm[i];
      out += s.t(' · cách biển ~${fmtNum(km, 0)} km', ' · ~${fmtNum(km, 0, lang: 'en')} km from the sea');
    }
    return out;
  }

  /// Câu ngắn khi ngón tay dừng lại (giá trị + so sánh).
  Bi short(AppState s) {
    if (type != cellVn) return area();
    final m = s.mapData.vars[s.v]!;
    if (value.isNaN) return (vi: 'Không có dữ liệu', en: 'No data');
    // bản đồ hôm nay: không có mức trung bình để so → đọc từ mô tả (mưa nhỏ, mưa to…) thay cho so sánh
    if (clim.isNaN) {
      final w = kidWord(s.v, value, m.norm(value), daily: m.daily);
      final wv = w.vi.replaceAll('rất rất', 'rất'), we = w.en;
      if (m.key == 'fire') return (vi: '${m.vi}: $wv', en: '${m.en}: $we');
      return (
        vi: '${fmtNum(value, m.decimals)} ${m.spokenVi}, $wv',
        en: '${fmtNum(value, m.decimals, lang: 'en')} ${m.spokenEn}, $we',
      );
    }
    final c = compareText(s.v, value, clim, sd);
    return (
      vi: '${fmtNum(value, m.decimals)} ${m.spokenVi}, ${c.vi}',
      en: '${fmtNum(value, m.decimals, lang: 'en')} ${m.spokenEn}, ${c.en}',
    );
  }

  /// Câu cho bạn nhỏ: từ đơn giản + con số làm tròn.
  Bi kidShort(AppState s) {
    if (type != cellVn) return area();
    final m = s.mapData.vars[s.v]!;
    final w = kidWord(s.v, value, value.isNaN ? 0 : m.norm(value), daily: m.daily);
    if (value.isNaN) return w;
    if (clim.isNaN) {
      // hôm nay: chỉ nói mưa/nắng thế nào, không so với "mọi năm"
      if (s.v == 'fire') return w;
      return (vi: '${w.vi}, khoảng ${fmtNum(value, 0)} ${m.spokenVi}', en: '${w.en}, about ${fmtNum(value, 0, lang: 'en')} ${m.spokenEn}');
    }
    final c = compareText(s.v, value, clim, sd);
    final usual = c.vi == 'gần mức trung bình'
        ? (vi: 'như mọi năm', en: 'like most years')
        : (c.vi.startsWith('cao') ? (vi: 'nhiều hơn mọi năm', en: 'more than usual') : (vi: 'ít hơn mọi năm', en: 'less than usual'));
    final usualTemp = c.vi == 'gần mức trung bình'
        ? usual
        : (c.vi.startsWith('cao') ? (vi: 'nóng hơn mọi năm', en: 'warmer than usual') : (vi: 'mát hơn mọi năm', en: 'cooler than usual'));
    final u = s.v == 'temp' ? usualTemp : usual;
    if (s.v == 'fire') return (vi: '${w.vi}, ${u.vi}', en: '${w.en}, ${u.en}'); // chỉ số cháy khó hiểu với trẻ
    return (
      vi: '${w.vi}, khoảng ${fmtNum(value, 0)} ${m.spokenVi}, ${u.vi}',
      en: '${w.en}, about ${fmtNum(value, 0, lang: 'en')} ${m.spokenEn}, ${u.en}',
    );
  }

  /// Tên gọi ngắn của chỗ này: địa danh gần nhất, không thì tên vùng.
  Bi name() {
    if (type != cellVn) return area();
    final r = regions[region];
    return near == null ? (vi: r.vi, en: r.en) : (vi: near!, en: near!);
  }

  /// Số liệu MỌI lớp tại ô này (lớp đang nghe đứng đầu) — "thời tiết ở đây" gồm mưa, nhiệt độ, cháy…
  List<({VarMeta m, double value, double clim, double sd})> readings(AppState s) {
    if (type != cellVn) return const [];
    final keys = orderedVarKeys(s.mapData.vars);
    keys
      ..remove(s.v)
      ..insert(0, s.v);
    return [
      for (final k in keys)
        if (s.mapData.vars[k] != null)
          (
            m: s.mapData.vars[k]!,
            value: s.mapData.values(k, s.year, s.month)[i],
            clim: s.mapData.clim(k, i, s.month),
            sd: s.mapData.sd(k, i, s.month),
          ),
    ];
  }

  /// Một lớp đọc thành câu: "Lượng mưa 320 mi-li-mét, mưa nhiều, cao hơn trung bình 20%".
  static Bi line(({VarMeta m, double value, double clim, double sd}) x, {bool compare = true, bool kid = false}) {
    final m = x.m, v = x.value;
    if (v.isNaN) return (vi: '${m.vi}: chưa có số liệu', en: '${m.en}: no data');
    var w = kidWord(m.key, v, m.norm(v), daily: m.daily);
    // người lớn: bỏ cách nói trẻ con "rất rất"
    if (!kid) w = (vi: w.vi.replaceAll('rất rất', 'rất'), en: w.en.replaceAll('a huge amount of', 'very heavy'));
    final c = compareText(m.key, v, x.clim, x.sd);
    final cv = compare && !c.vi.startsWith('không') ? ', ${c.vi}' : '';
    final ce = compare && !c.en.startsWith('no ') ? ', ${c.en}' : '';
    if (m.key == 'fire') {
      // chỉ số cháy khó hình dung bằng con số → đọc bằng lời; "không có đám cháy" thì khỏi so sánh (tránh lặp)
      final none = m.daily ? v < 0.5 : m.norm(v) < 0.05;
      return (vi: 'Cháy rừng: ${w.vi}${none ? '' : cv}', en: 'Fires: ${w.en}${none ? '' : ce}');
    }
    final d = kid ? 0 : m.decimals;
    final word = m.key == 'rain' || m.key == 'temp' || kid;
    return (
      vi: '${m.vi} ${fmtNum(v, d)} ${m.spokenVi}${word ? ', ${w.vi}' : ''}$cv',
      en: '${m.en} ${fmtNum(v, d, lang: 'en')} ${m.spokenEn}${word ? ', ${w.en}' : ''}$ce',
    );
  }

  /// Câu ngắn khi chạm nhanh một lần: tên chỗ + thời tiết mọi lớp (không so sánh, cho gọn).
  Bi brief(AppState s) {
    if (type != cellVn) return place();
    final n = name();
    final ls = [for (final x in readings(s)) line(x, compare: false, kid: s.kidMode)];
    return (
      vi: '${n.vi}. ${ls.map((l) => l.vi).join('. ')}.',
      en: '${n.en}. ${ls.map((l) => l.en).join('. ')}.',
    );
  }

  /// Câu đầy đủ cho chạm đúp / nút "Đọc chỗ này": nơi, thời điểm, mọi lớp kèm so sánh với trung bình.
  Bi detail(AppState s) {
    if (island == 'Hoàng Sa') {
      return (
        vi: 'Quần đảo Hoàng Sa, thuộc thành phố Đà Nẵng, Việt Nam. Nằm giữa Biển Đông, cách Đà Nẵng khoảng 170 hải lý về phía đông.',
        en: 'Hoang Sa (Paracel) Islands, part of Da Nang city, Vietnam, in the middle of the East Sea, about 170 nautical miles east of Da Nang.',
      );
    }
    if (island == 'Trường Sa') {
      return (
        vi: 'Quần đảo Trường Sa, thuộc tỉnh Khánh Hòa, Việt Nam, ở phía nam Biển Đông, cách Cam Ranh khoảng 250 hải lý. '
            'Trên bản đồ, quần đảo được vẽ thu nhỏ trong khung vì phần lớn nằm xa hơn về phía đông.',
        en: 'Truong Sa (Spratly) Islands, part of Khanh Hoa province, Vietnam, in the southern East Sea, about 250 nautical miles from Cam Ranh. '
            'On this map they are drawn in an inset box because most of the islands lie further east.',
      );
    }
    if (type == cellSea) {
      return near == null ? (vi: 'Biển Đông', en: 'East Sea') : (vi: 'Biển Đông, ngoài khơi $near', en: 'East Sea, off $near');
    }
    if (type != cellVn) return (vi: 'Ngoài lãnh thổ Việt Nam', en: 'Outside Vietnam');
    final r = regions[region];
    final ls = [for (final x in readings(s)) line(x, kid: s.kidMode)];
    final km = s.mapData.geo.coastKm[i];
    final coastVi = km.isNaN ? '' : (km < 8 ? ' Sát biển.' : ' Cách biển khoảng ${fmtNum(km, 0)} ki-lô-mét.');
    final coastEn = km.isNaN ? '' : (km < 8 ? ' On the coast.' : ' About ${fmtNum(km, 0, lang: 'en')} kilometres from the sea.');
    return (
      vi: '${near != null ? 'Gần $near, ' : ''}${r.vi}. ${s.liveMapOn ? s.liveWhen('vi') : 'Tháng ${s.month + 1} năm ${s.year}'}. '
          '${ls.map((l) => l.vi).join('. ')}.$coastVi',
      en: '${near != null ? 'Near $near, ' : ''}${r.en}. ${s.liveMapOn ? s.liveWhen('en') : '${monthsEn[s.month]} ${s.year}'}. '
          '${ls.map((l) => l.en).join('. ')}.$coastEn',
    );
  }
}

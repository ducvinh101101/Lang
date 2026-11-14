// HỆ THỐNG TRÍCH XUẤT TRI THỨC (RAG - Retrieval-Augmented Generation) CHO TRỢ LÝ AI:
// Trích xuất tri thức chính xác từ cơ sở dữ liệu nội tại (địa hình, địa danh, vũ trụ, khí hậu NASA)
// đưa vào ngữ cảnh prompt trước khi gọi LLM (In-Context RAG) và cung cấp các công cụ tra cứu động (Agent Tools).
import 'dart:async';
import '../data/nasa_normalized_data.dart';

import '../features/globe/hanoi_guide.dart' as hg;
import '../features/globe/terrain_data.dart' as td;
import '../features/globe/vn_landmarks.dart' as lm;
import '../features/space/planets.dart' as sp;
import '../features/voice/commands.dart' show normVi;
import 'nasa_power.dart';

class EarthRag {
  /// Trích xuất tri thức liên quan từ câu hỏi (In-Context RAG):
  /// Tự động dò tìm địa danh Việt Nam, đỉnh núi/địa hình thế giới, thiên thể Hệ Mặt Trời
  /// và thông tin nơi đang xem để nhúng thẳng vào prompt lượt 1 (không tốn thêm lượt mạng).
  static String extractContext(
    String query, {
    String? place,
    double? lat,
    double? lon,
    String lang = 'vi',
  }) {
    final q = normVi(query);
    final buf = StringBuffer();

    // 1. Địa danh Việt Nam
    final matchedLandmarks = <lm.Landmark>[];
    for (final l in lm.vnLandmarks) {
      final nameNorm = normVi(l.name);
      if (q.contains(nameNorm) || l.aliases.any((a) => q.contains(a))) {
        matchedLandmarks.add(l);
      }
    }
    if (matchedLandmarks.isNotEmpty) {
      buf.writeln('--- Tri thức Địa danh & Văn hóa Việt Nam (RAG) ---');
      for (final l in matchedLandmarks.take(3)) {
        if (lang == 'vi') {
          buf.writeln('• ${l.name} (${l.province}, ${lm.regionNamesVi[l.region] ?? ''}): ${l.vi} (Tọa độ: ${l.lat.toStringAsFixed(2)}°B, ${l.lon.toStringAsFixed(2)}°Đ)');
        } else {
          buf.writeln('• ${l.en} (${l.province}, ${lm.regionNamesEn[l.region] ?? ''}): ${l.enText}');
        }
      }
    }

    // 1b. Cẩm nang địa điểm ăn uống, vui chơi, du lịch các xã/phường Hà Nội
    final hz = hg.findHanoiZone(name: place ?? '', raw: query, lat: lat, lon: lon);
    if (hz != null) {
      buf.writeln('--- Cẩm nang Ăn uống, Vui chơi & Du lịch Hà Nội (RAG) ---');
      // phần quán ăn, chỗ ở đang ẩn → không đưa món ăn, quán vào ngữ cảnh AI
      final food = hg.kHanoiFoodStayEnabled;
      if (lang == 'vi') {
        buf.writeln('• ${hz.titleVi}: ${hz.tourVi} ${hz.funVi}${food ? ' ${hz.foodVi}' : ''}');
      } else {
        buf.writeln('• ${hz.titleEn}: ${hz.tourEn} ${hz.funEn}${food ? ' ${hz.foodEn}' : ''}');
      }
    }

    // 2. Đỉnh núi & Địa hình (Việt Nam & Thế giới)
    final matchedPeaks = <td.Peak>[];
    for (final p in td.peaks) {
      final nameNorm = normVi(p.vi);
      if (q.contains(nameNorm) || p.alias.any((a) => q.contains(a))) {
        matchedPeaks.add(p);
      }
    }
    final matchDeepest = q.contains('mariana') || q.contains('challenger') || q.contains('vuc sau') || q.contains('ranh sau');
    final matchedLandforms = <td.Landform>[];
    for (final lf in td.landforms) {
      if (q.contains(normVi(lf.vi))) {
        matchedLandforms.add(lf);
      }
    }

    if (matchedPeaks.isNotEmpty || matchDeepest || matchedLandforms.isNotEmpty) {
      buf.writeln('--- Tri thức Địa hình & Độ cao (RAG) ---');
      for (final p in matchedPeaks.take(3)) {
        if (lang == 'vi') {
          buf.writeln('• ${p.vi}: độ cao chính thức ${p.h} mét, ${p.noteVi}. Tọa độ: ${p.lat.toStringAsFixed(2)}°, ${p.lon.toStringAsFixed(2)}°.');
        } else {
          buf.writeln('• ${p.en}: official elevation ${p.h} m, ${p.noteEn}.');
        }
      }
      if (matchDeepest) {
        if (lang == 'vi') {
          buf.writeln('• ${td.deepest.vi}: nơi sâu nhất Trái Đất, độ sâu ${td.deepest.h} mét dưới mực nước biển.');
        } else {
          buf.writeln('• ${td.deepest.en}: deepest point on Earth, depth ${td.deepest.h} m.');
        }
      }
      for (final lf in matchedLandforms.take(2)) {
        if (lang == 'vi') {
          buf.writeln('• ${lf.vi}: ${lf.noteVi}.');
        } else {
          buf.writeln('• ${lf.en}: ${lf.noteEn}.');
        }
      }
    }

    // 3. Thiên thể & Hệ Mặt Trời
    final matchedPlanets = <sp.Planet>[];
    for (final p in sp.planets) {
      if (q.contains(normVi(p.vi)) || p.aliases.any((a) => q.contains(a))) {
        matchedPlanets.add(p);
      }
    }
    if (matchedPlanets.isNotEmpty) {
      buf.writeln('--- Tri thức Thiên văn & Vũ trụ (RAG) ---');
      for (final p in matchedPlanets.take(2)) {
        // Lấy đoạn mở đầu hoặc tóm tắt thực tế
        final summary = p.chapters.take(2).join(' ');
        buf.writeln('• ${p.vi} (${p.en}): $summary');
      }
    }

    // 4. Tri thức chuẩn hóa từ NASA (QA Bank, GISTEMP, FIRMS, Bão Yagi/Lũ 2020, Cảnh địa hình Đà Lạt)
    final repo = NasaNormalizedRepo.cached;
    if (repo != null) {
      final qaHit = repo.matchQa(query);
      if (qaHit != null) {
        buf.writeln('--- Ngân hàng Hỏi – Đáp kiểm chứng NASA (qa_bank.json) ---');
        buf.writeln('• Câu hỏi chuẩn: ${qaHit.questionVi}');
        buf.writeln('• Trả lời kiểm chứng: ${qaHit.answerVi} (Nguồn: ${qaHit.source})');
      }
      final evHit = repo.matchHistoricalEvent(query);
      if (evHit != null) {
        buf.writeln('--- Sự kiện thiên tai lịch sử NASA POWER Daily ---');
        buf.writeln('• ${evHit.spokenSummary(en: lang == 'en')}');
      }
      if (q.contains('chay rung') || q.contains('diem chay') || q.contains('firms') || q.contains('modis')) {
        final fr = repo.findFirmsRegion(query);
        buf.writeln('--- Điểm cháy rừng vệ tinh NASA FIRMS (MODIS MCD14ML) ---');
        buf.writeln('• ${fr.spokenSummary(en: lang == 'en')}');
      }
      if (q.contains('gistemp') || q.contains('nong len toan cau') || q.contains('am len toan cau') || q.contains('trai dat nong len')) {
        buf.writeln('--- Chuỗi dị thường nhiệt độ toàn cầu NASA GISTEMP v4 ---');
        buf.writeln('• ${repo.gistempSummaryText(en: lang == 'en')}');
      }
      if ((lat != null && lon != null && repo.dalatScene.contains(lat, lon)) || q.contains('da lat') || q.contains('langbiang')) {
        final cell = repo.dalatScene.cellAt(lat ?? repo.dalatScene.centerLat, lon ?? repo.dalatScene.centerLon);
        if (cell != null) {
          buf.writeln('--- Lưới địa hình đa lớp vệ tinh Đà Lạt (SRTM + MODIS + JRC + HydroRIVERS) ---');
          buf.writeln('• ${cell.spokenSummary(en: lang == 'en')}');
        }
      }
    }

    // 5. Ngữ cảnh vị trí hiện tại
    if (place != null && place.trim().isNotEmpty) {
      buf.writeln('--- Ngữ cảnh vị trí hiện tại ---');
      buf.writeln('• Nơi đang quan sát trên quả địa cầu: $place${lat != null && lon != null ? ' (Tọa độ: ${lat.toStringAsFixed(2)}°B, ${lon.toStringAsFixed(2)}°Đ)' : ''}.');
      buf.writeln('• Chủ quyền quốc gia: Quần đảo Hoàng Sa và Trường Sa là của Việt Nam.');
    }

    return buf.toString().trim();
  }

  /// Tra cứu danh lam thắng cảnh Việt Nam theo tên (dùng cho Tool tra_cuu_dia_danh).
  static Map<String, Object?> lookupLandmark(String name) {
    final q = normVi(name);
    for (final l in lm.vnLandmarks) {
      if (normVi(l.name) == q || l.aliases.any((a) => a == q || q.contains(a))) {
        return {
          'ten': l.name,
          'tieng_anh': l.en,
          'tinh_thanh': l.province,
          'vung_mien': lm.regionNamesVi[l.region] ?? l.region,
          'toa_do': {'vi_do': l.lat, 'kinh_do': l.lon},
          'mo_ta': l.vi,
        };
      }
    }
    final hz = hg.findHanoiZone(name: name, raw: name);
    if (hz != null) {
      return {
        'ten': hz.titleVi,
        'tieng_anh': hz.titleEn,
        'tinh_thanh': 'Hà Nội',
        'toa_do': {'vi_do': hz.lat, 'kinh_do': hz.lon},
        'du_lich': hz.tourVi,
        'vui_choi': hz.funVi,
        'an_uong': hz.foodVi,
      };
    }
    return {'thong_bao': 'Không tìm thấy địa danh "$name" trong danh mục trọng điểm.'};
  }

  /// Tra cứu đỉnh núi hoặc dạng địa hình theo tên (dùng cho Tool tra_cuu_dia_hinh).
  static Map<String, Object?> lookupTerrain(String name) {
    final q = normVi(name);
    for (final p in td.peaks) {
      if (normVi(p.vi) == q || p.alias.any((a) => a == q || q.contains(a))) {
        return {
          'ten': p.vi,
          'tieng_anh': p.en,
          'do_cao_met': p.h,
          'toa_do': {'vi_do': p.lat, 'kinh_do': p.lon},
          'dac_diem': p.noteVi,
        };
      }
    }
    for (final lf in td.landforms) {
      if (normVi(lf.vi) == q || normVi(lf.vi).contains(q) || q.contains(normVi(lf.vi))) {
        return {
          'ten': lf.vi,
          'tieng_anh': lf.en,
          'dac_diem': lf.noteVi,
          'khung_toa_do': {'vi_do_0': lf.lat0, 'vi_do_1': lf.lat1, 'kinh_do_0': lf.lon0, 'kinh_do_1': lf.lon1},
        };
      }
    }
    if (q.contains('mariana') || q.contains('challenger')) {
      return {
        'ten': td.deepest.vi,
        'do_sau_met': td.deepest.h,
        'toa_do': {'vi_do': td.deepest.lat, 'kinh_do': td.deepest.lon},
        'dac_diem': 'Vực sâu nhất thế giới trong rãnh Mariana.',
      };
    }
    return {'thong_bao': 'Không tìm thấy dữ liệu địa hình cho "$name".'};
  }

  /// Tra cứu thông tin thiên văn (dùng cho Tool tra_cuu_vu_tru).
  static Map<String, Object?> lookupSpace(String name) {
    final q = normVi(name);
    for (final p in sp.planets) {
      if (normVi(p.vi) == q || p.aliases.any((a) => a == q || q.contains(a))) {
        return {
          'ten': p.vi,
          'tieng_anh': p.en,
          'thong_tin': p.facts,
        };
      }
    }
    return {'thong_bao': 'Không tìm thấy thông tin thiên thể "$name".'};
  }

  /// Tra cứu dữ liệu khí hậu lịch sử NASA POWER theo tọa độ (dùng cho Tool tra_cuu_khi_hau_nasa).
  static Future<Map<String, Object?>> lookupNasaClimate(
    double lat,
    double lon,
    String placeName,
    NasaPowerService nasa,
  ) async {
    try {
      final c = await nasa.climate(lat, lon);
      // xu hướng xưa – nay lấy từ ERA5 (một nguồn thống nhất): chuỗi NASA POWER ở Việt Nam có bước nhảy theo thời gian
      // (mưa thập niên 1980 thấp bất thường, nhảy bậc quanh 2016) nên KHÔNG dùng POWER để nói ấm lên / mát đi.
      EraTrend? tr;
      try {
        tr = await nasa.extremes(lat, lon);
      } catch (_) {}
      final rt = c.recent(c.tempYear), rr = c.recent(c.rainYear);
      if (tr == null) {
        return {
          'dia_diem': placeName,
          'nguon': 'NASA POWER (mức gần đây); không có số liệu xu hướng vì mất kết nối',
          'nhiet_do_10_nam_gan_day': rt.isNaN ? 'không có' : '${rt.toStringAsFixed(1)} độ C',
          'luong_mua_10_nam_gan_day_mm': rr.isNaN ? 'không có' : rr.toStringAsFixed(0),
          'luu_y': 'Không nói xu hướng ấm lên hay mát đi khi không có số liệu xu hướng.',
        };
      }
      final dt = tr.t1 - tr.t0;
      final dr = tr.rain0 > 1 ? (tr.rain1 / tr.rain0 - 1) * 100 : double.nan;
      return {
        'dia_diem': placeName,
        'giai_doan': 'từ năm ${tr.y0} đến năm ${tr.y1}',
        'nguon_xu_huong': 'ERA5 (tái phân tích khí hậu, một nguồn thống nhất cho cả chuỗi năm)',
        'nguon_so_lieu_thang': 'NASA POWER',
        'nhiet_do_thap_nien_1980': tr.t0.isNaN ? 'không có' : '${tr.t0.toStringAsFixed(1)} độ C',
        'nhiet_do_10_nam_gan_day': tr.t1.isNaN ? 'không có' : '${tr.t1.toStringAsFixed(1)} độ C',
        'do_lech_nhiet_do': dt.isNaN ? 'không rõ' : (dt >= 0 ? 'ấm hơn ${dt.toStringAsFixed(1)} độ' : 'mát hơn ${(-dt).toStringAsFixed(1)} độ'),
        'nam_nong_nhat': tr.hottestYear(),
        'ngay_tren_35_do_moi_nam': '${tr.hot0.round()} → ${tr.hot1.round()}',
        'luong_mua_thay_doi_phan_tram': dr.isNaN ? 'không rõ' : dr.toStringAsFixed(0),
      };
    } catch (e) {
      return {'loi': 'Không lấy được dữ liệu khí hậu NASA: $e'};
    }
  }
}

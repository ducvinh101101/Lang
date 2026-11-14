// Lỗi tìm thấy khi tự dùng thử toàn bộ app (11/2026).
import 'package:earthsense/features/globe/world_commands.dart';
import 'package:earthsense/features/history/history_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rê tay / chạm địa hình kèm tên nơi → mở đúng nơi đó (trước: mở ở nơi cũ)', () {
    const cases = {
      'khám phá bằng tay Đà Lạt': ('explore', 'Đà Lạt'),
      'rê tay khám phá Đà Lạt': ('explore', 'Đà Lạt'),
      'rê tay ở Sa Pa': ('explore', 'Sa Pa'),
      'chạm địa hình Đà Lạt': ('terrain', 'Đà Lạt'),
      'cho tôi sờ địa hình Phan Xi Păng nhé': ('terrain', 'Phan Xi Păng'),
      'khám phá bằng tay': ('explore', ''),
      'rê tay ở đây': ('explore', ''),
      'khám phá bằng tay quanh đây': ('explore', ''),
    };
    cases.forEach((s, want) {
      final c = parseWorld(s);
      expect(c.kind.name, want.$1, reason: s);
      expect(c.target, want.$2, reason: s);
    });
  });
  test('"năm ngoái" trong câu thời tiết → khí hậu năm trước', () {
    final c = parseWorld('thời tiết Huế năm ngoái thế nào');
    expect(c.kind, WKind.climate);
    expect(c.target, 'Huế');
    expect(c.year, DateTime.now().year - 1);
    expect(parseWorld('năm ngoái tôi đi Huế').kind, isNot(WKind.climate));
  });
  test('"3 năm qua" khi số liệu chỉ có đến 2025 → nói rõ mốc số liệu; hỏi năm cụ thể thì không', () {
    final r = resolveRange(spanMonths: 36, dataY0: 1981, dataY1: 2025);
    expect(r.describeVi(), contains('số liệu NASA mới có đến hết năm 2025'));
    expect(r.describeVi(), contains('mỗi bản ghi là một tháng'));
    final r2 = resolveRange(from: DateTime(2020, 1), to: DateTime(2020, 12), dataY0: 1981, dataY1: 2025);
    expect(r2.describeVi(), isNot(contains('số liệu NASA')));
  });
}

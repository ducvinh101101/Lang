// Bản web: nhãn nhật ký đúng, giọng máy chủ chia đoạn đầu ngắn (phản hồi nhanh).
import 'package:earthsense/core/crash_guard.dart';
import 'package:earthsense/speech/remote_voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nhật ký: chỉ lỗi thật mới gắn [LỖI]', () {
    expect(CrashGuard.tagOf('[app nói] Quả địa cầu đây. Bạn muốn nghe gì?'), '[nhật ký]');
    expect(CrashGuard.tagOf('[app nói] Mình chưa dùng được micro, có lỗi gì đó'), '[nhật ký]');
    expect(CrashGuard.tagOf('[giọng máy chủ] sẵn sàng'), '[nhật ký]');
    expect(CrashGuard.tagOf('[lệnh] "thời tiết Hà Nội" → weather'), '[nhật ký]');
    expect(CrashGuard.tagOf('[tìm xã/phường] "xã Gia Lâm" → xã Gia Lâm, Hà Nội'), '[nhật ký]');
    expect(CrashGuard.tagOf('[nhận giọng web] lỗi: not-allowed'), '[LỖI]');
    expect(CrashGuard.tagOf('[lệnh] lỗi: Bad state'), '[LỖI]');
    expect(CrashGuard.tagOf('[tts] speak lỗi: x'), '[LỖI]');
    expect(CrashGuard.tagOf('Lần chạy trước kết thúc bất thường khi: soft:tts:speaking'), '[LỖI]');
    expect(CrashGuard.tagOf('[EONET] ClientException: Failed to fetch'), '[LỖI]');
    expect(CrashGuard.tagOf('Khởi động giọng đọc quá 45 giây → vào app trước'), '[LỖI]');
  });

  test('giọng máy chủ: đoạn đầu ngắn, không mất chữ', () {
    const s = 'Hà Nội hôm nay trời nhiều mây, nhiệt độ từ hai mươi hai đến hai mươi tám độ, chiều tối có thể mưa rào. '
        'Ngày mai trời nắng.';
    final c = RemoteVoice.chunks(s, firstShort: true);
    expect(c.first, 'Hà Nội hôm nay trời nhiều mây,');
    expect(c.length, 3);
    expect(c.join(' ').replaceAll(RegExp(r'\s+'), ' '), s.trim());
    // câu ngắn: giữ nguyên
    expect(RemoteVoice.chunks('Quả địa cầu đây.', firstShort: true), ['Quả địa cầu đây.']);
    // đoạn dài hơn 220 chữ vẫn bị chia
    final long = List.filled(40, 'mưa rào rải rác').join(' ');
    expect(RemoteVoice.chunks(long).every((p) => p.length <= 221), isTrue);
  });
}

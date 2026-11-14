/// Định dạng số không cần package intl: tiếng Việt dùng dấu phẩy thập phân, dấu chấm ngăn nghìn.
String fmtNum(double x, int decimals, {String lang = 'vi'}) {
  if (x.isNaN) return '—';
  final neg = x < 0;
  final s = x.abs().toStringAsFixed(decimals);
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(lang == 'vi' ? '.' : ',');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (parts.length > 1) out += (lang == 'vi' ? ',' : '.') + parts[1];
  return neg ? '-$out' : out;
}

const monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// m: 0..11
String monthLabel(int m, int year, String lang) =>
    lang == 'vi' ? 'tháng ${m + 1}/$year' : '${monthsEn[m]} $year';

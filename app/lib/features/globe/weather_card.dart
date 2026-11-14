import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../../live/live_weather.dart';

class GlobeLoc {
  final String vi, en;
  final double lat, lon, zoom;
  const GlobeLoc(this.vi, this.en, this.lat, this.lon, this.zoom);
}

/// Thẻ thời tiết trực quan bán trong suốt (Glassmorphism) hiển thị các chỉ số chi tiết.
class LiveWeatherCard extends StatefulWidget {
  final GlobeLoc loc;
  final LiveWeather weather;
  final bool isEn;
  final VoidCallback onClose;
  final VoidCallback? onMore;

  const LiveWeatherCard({
    super.key,
    required this.loc,
    required this.weather,
    required this.isEn,
    required this.onClose,
    this.onMore,
  });

  @override
  State<LiveWeatherCard> createState() => _LiveWeatherCardState();
}

class _LiveWeatherCardState extends State<LiveWeatherCard> {
  bool _expanded = false;

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.wb_cloudy_rounded;
    if (code >= 45 && code <= 48) return Icons.blur_on_rounded; // sương mù
    if (code >= 51 && code <= 67) return Icons.grain_rounded; // mưa phùn, mưa
    if (code >= 80 && code <= 82) return Icons.grain_rounded; // mưa rào (rất hay gặp ở Việt Nam) — không phải tuyết
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) return Icons.ac_unit_rounded; // tuyết, mưa tuyết rào
    if (code >= 95) return Icons.thunderstorm_rounded; // dông bão
    return Icons.cloud_rounded;
  }

  Color _aqiColor(int? aqi) {
    if (aqi == null) return const Color(0xFF9EA3A8); // không có số liệu: xám, không giả vờ là "tốt"
    if (aqi <= 50) return const Color(0xFF43D8A0); // Tốt - xanh lá
    if (aqi <= 100) return const Color(0xFFFFD166); // Trung bình - vàng
    if (aqi <= 150) return const Color(0xFFF78C6B); // Kém - cam
    return const Color(0xFFEF476F); // Xấu/nguy hại - đỏ
  }

  String _aqiLabel(int? aqi) {
    if (aqi == null) return widget.isEn ? 'No data' : 'Chưa có';
    if (aqi <= 50) return widget.isEn ? 'Good' : 'Tốt';
    if (aqi <= 100) return widget.isEn ? 'Moderate' : 'Trung bình';
    if (aqi <= 150) return widget.isEn ? 'Unhealthy' : 'Kém';
    return widget.isEn ? 'Poor' : 'Xấu';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    final now = w.now;
    final locName = widget.isEn ? widget.loc.en : widget.loc.vi;
    final today = w.days.isNotEmpty ? w.days.first : null;

    final wmo = wmoText(now.code);
    final desc = widget.isEn
        ? (wmo.$2.isNotEmpty ? wmo.$2 : (now.desc.isNotEmpty ? now.desc : 'Clear sky'))
        : (wmo.$1.isNotEmpty ? wmo.$1 : (now.desc.isNotEmpty ? now.desc : 'Trời quang'));

    final weatherSummary = widget.isEn
        ? 'Weather card for $locName: ${now.temp.round()} degrees Celsius, $desc. Feels like ${now.feels.round()} degrees. Humidity ${now.humidity} percent, wind ${now.wind.round()} kilometers per hour.'
        : 'Thẻ thời tiết tại $locName: ${now.temp.round()} độ C, $desc. Cảm giác như ${now.feels.round()} độ. Độ ẩm ${now.humidity} phần trăm, gió ${now.wind.round()} km một giờ.';

    final mq = MediaQuery.sizeOf(context);
    final maxCardW = math.max(260.0, math.min(mq.width - 32, _expanded ? 460.0 : 380.0));
    final maxCardH = math.max(240.0, math.min(mq.height - 180, 520.0));

    return Semantics(
      label: weatherSummary,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxCardW,
            maxHeight: maxCardH,
          ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xD80D151B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x66E4BB63), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x77000000), blurRadius: 28, offset: Offset(0, 10)),
                  BoxShadow(color: Color(0x22E4BB63), blurRadius: 18, spreadRadius: -2),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tiêu đề & Nút đóng
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFFE4BB63)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locName,
                            style: const TextStyle(
                              color: Color(0xFFFBF4E4),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _expanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                            size: 20,
                            color: const Color(0xFFE4BB63),
                          ),
                          tooltip: widget.isEn ? 'Expand/Collapse' : 'Mở rộng/Thu gọn',
                          onPressed: () => setState(() => _expanded = !_expanded),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xAAFFFFFF)),
                          tooltip: widget.isEn ? 'Close' : 'Đóng thẻ',
                          onPressed: widget.onClose,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Nhiệt độ & Thời tiết chính
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(_weatherIcon(now.code), size: 48, color: const Color(0xFFFFD166)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${now.temp.round()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                      ),
                                    ),
                                    const Text(
                                      '°C',
                                      style: TextStyle(
                                        color: Color(0xFFE4BB63),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE0E5EA),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.isEn ? 'Feels like ${now.feels.round()}°' : 'Cảm giác như ${now.feels.round()}°',
                              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 13),
                            ),
                            if (today != null)
                              Text(
                                '${today.tmin.round()}° – ${today.tmax.round()}°',
                                style: const TextStyle(
                                  color: Color(0xFFFBF4E4),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Lưới 4 chỉ số quan trọng (Độ ẩm, Gió, UV, AQI)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(
                            icon: Icons.water_drop_rounded,
                            iconColor: const Color(0xFF4FA8F6),
                            label: widget.isEn ? 'Humidity' : 'Độ ẩm',
                            value: '${now.humidity}%',
                          ),
                          _MetricItem(
                            icon: Icons.air_rounded,
                            iconColor: const Color(0xFF74C69D),
                            label: widget.isEn ? 'Wind' : 'Gió',
                            value: '${now.wind.round()} km/h',
                          ),
                          _MetricItem(
                            icon: Icons.wb_sunny_outlined,
                            iconColor: const Color(0xFFFFB703),
                            label: 'UV',
                            value: now.uv != null ? now.uv!.toStringAsFixed(1) : (today?.uv != null ? today!.uv!.toStringAsFixed(1) : '—'),
                          ),
                          _MetricItem(
                            icon: Icons.eco_rounded,
                            iconColor: _aqiColor(w.aqi),
                            label: 'AQI',
                            value: w.aqi != null ? '${w.aqi}' : '—',
                            sublabel: _aqiLabel(w.aqi),
                          ),
                        ],
                      ),
                    ),

                    // Dự báo mở rộng (theo giờ hoặc 3 ngày)
                    if (_expanded && w.hours.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        widget.isEn ? 'Hourly Forecast' : 'Dự báo vài giờ tới',
                        style: const TextStyle(color: Color(0xFFE4BB63), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 74,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: w.hours.take(6).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final h = w.hours[idx];
                            return Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x22FFFFFF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Text(
                                    '${h.time.hour}:00',
                                    style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 11),
                                  ),
                                  Icon(_weatherIcon(h.code), size: 18, color: const Color(0xFFFFD166)),
                                  Text(
                                    '${h.temp.round()}°',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sublabel;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Text(
          sublabel ?? label,
          style: const TextStyle(color: Color(0xFF9EA3A8), fontSize: 11),
        ),
      ],
    );
  }
}

// touch_map_page.dart — màn "di tay đọc vùng". Dùng: Navigator.push(..., TouchMapPage())
// Đã chạy `flutter analyze` (Flutter 3.44).
import 'package:flutter/material.dart';
import 'finger_reader.dart';
import 'profile_scan.dart';
import 'touch_map.dart';
import 'touch_sound.dart';

class TouchMapPage extends StatefulWidget {
  const TouchMapPage({super.key, this.root = 'assets/touch'});
  final String root;
  @override
  State<TouchMapPage> createState() => _TouchMapPageState();
}

class _TouchMapPageState extends State<TouchMapPage> {
  final sound = TouchSound();
  TouchMap? map;
  FingerReader? reader;
  String layer = 'elev';
  String? _title; // tên tỉnh đang mở ở cấp 2

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await sound.init();
    await _open('vn');
    await sound.introduceElevation();
  }

  Future<void> _open(String folder, {String? intro}) async {
    reader?.up();
    final m = await TouchMap.load('${widget.root}/$folder');
    setState(() {
      map = m;
      reader = FingerReader(m, sound)..layer = m.layers.containsKey(layer) ? layer : 'elev';
    });
    if (intro != null) sound.say(intro);
  }

  void _toggleLayer() {
    final m = map;
    if (m == null) return;
    final next = layer == 'elev' && m.layers.containsKey('pop') ? 'pop' : 'elev';
    setState(() { layer = next; reader?.layer = next; });
    sound.say(next == 'elev'
        ? 'Lớp độ cao. Nốt càng cao là đất càng cao.'
        : 'Lớp dân cư. Càng nhiều tiếng xe là càng đông người.');
  }

  void _doubleTap(Offset pos, Size size) {
    final m = map, r = reader;
    if (m == null || r == null || m.level != 'vn') return;
    final id = r.idAt(pos.dx, pos.dy, size.width, size.height);
    final reg = m.regions[id];
    if (reg?.level2 == null) return;
    final intro = reg!.intro.isNotEmpty ? '${reg.nameVi}. ${reg.intro}' : 'Mở bản đồ ${reg.nameVi}.';
    _title = reg.nameVi;
    _open(reg.level2!, intro: intro);
  }

  /// Quét mặt cắt địa hình của bản đồ đang mở (Bắc - Nam rồi Tây - Đông, mỗi lượt ≤ 8 giây).
  Future<void> _scan() async {
    final m = map;
    if (m == null) return;
    reader?.up();
    final title = m.level == 'vn' ? 'Cả nước' : (_title ?? '');
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileScanPage(map: m, sound: sound, title: title)));
  }

  void _dataSource() {
    final cards = map?.dataCards.values.map((c) => '${c['dataset']}. ${c['limitation_vi']}').join(' ');
    if (cards != null) sound.say('Nguồn dữ liệu: $cards');
  }

  @override
  void dispose() {
    reader?.up();
    sound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = map, r = reader;
    return Scaffold(
      appBar: AppBar(
        title: Text(m == null ? 'Đang tải…' : (m.level == 'vn' ? 'Cả nước' : (_title ?? 'Bản đồ tỉnh'))),
        actions: [
          if (m != null && m.level != 'vn')
            TextButton(onPressed: () => _open('vn', intro: 'Cả nước.'), child: const Text('Cả nước')),
          IconButton(onPressed: _toggleLayer, icon: const Icon(Icons.layers), tooltip: 'Đổi lớp độ cao / dân cư'),
          IconButton(onPressed: _scan, icon: const Icon(Icons.show_chart), tooltip: 'Quét mặt cắt địa hình'),
          IconButton(onPressed: _dataSource, icon: const Icon(Icons.info_outline), tooltip: 'Nguồn dữ liệu'),
        ],
      ),
      body: m == null || r == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(builder: (context, box) {
                // Khung bản đồ giữ ĐÚNG tỉ lệ cols:rows để ngón tay khớp với ô;
                // dải quần đảo cao bằng bản đồ nên dùng chung thang vĩ độ.
                final stripW = m.islands.isEmpty ? 0.0 : 56.0;
                var h = box.maxHeight, w = h * m.aspect;
                if (w > box.maxWidth - stripW) { w = box.maxWidth - stripW; h = w / m.aspect; }
                final size = Size(w, h);
                return Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: w, height: h,
                      child: GestureDetector(
                        onDoubleTapDown: (d) => _doubleTap(d.localPosition, size),
                        onDoubleTap: () {},
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) => r.move(e.localPosition.dx, e.localPosition.dy, w, h),
                          onPointerMove: (e) => r.move(e.localPosition.dx, e.localPosition.dy, w, h),
                          onPointerUp: (_) => r.up(),
                          onPointerCancel: (_) => r.up(),
                          child: Image.asset(m.basemapAsset, fit: BoxFit.fill,
                              filterQuality: FilterQuality.none, gaplessPlayback: true),
                        ),
                      ),
                    ),
                    if (m.islands.isNotEmpty)
                      SizedBox(
                        width: stripW, height: h,
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) => r.moveIslands(e.localPosition.dy, h),
                          onPointerMove: (e) => r.moveIslands(e.localPosition.dy, h),
                          onPointerUp: (_) => r.up(),
                          child: CustomPaint(painter: _IslandPainter(m)),
                        ),
                      ),
                  ]),
                );
              }),
            ),
    );
  }
}

class _IslandPainter extends CustomPainter {
  _IslandPainter(this.m);
  final TouchMap m;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFAACDEB));
    final span = m.rows * m.step;
    for (final i in m.islands) {
      final y0 = (m.latTop - i.latTop) / span * size.height;
      final y1 = (m.latTop - i.latBottom) / span * size.height;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(6, y0, size.width - 6, y1), const Radius.circular(6)),
          Paint()..color = const Color(0xFFE8D9A8));
    }
  }

  @override
  bool shouldRepaint(covariant _IslandPainter old) => old.m != m;
}

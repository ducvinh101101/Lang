import 'package:earthsense/live/vn_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tách tên tỉnh (mới, cũ) khỏi tên xã', () {
    var r = splitProvince('xã Tân Lập tỉnh Tây Ninh');
    expect(r.place, 'xã Tân Lập');
    expect(r.province, 'Tây Ninh');
    r = splitProvince('xã Mường Hoa, Yên Bái');
    expect(r.place, 'xã Mường Hoa');
    expect(r.province, 'Lào Cai');
    expect(r.oldProvince, 'Yên Bái');
    r = splitProvince('phường Bến Nghé thành phố Hồ Chí Minh');
    expect(r.place, 'phường Bến Nghé');
    expect(r.province, 'Hồ Chí Minh');
    r = splitProvince('xã Tân Lập ở Bình Dương');
    expect(r.place, 'xã Tân Lập');
    expect(r.province, 'Hồ Chí Minh');
    expect(splitProvince('xã Bát Tràng').province, isNull);
    expect(splitProvince('Hà Nội').province, isNull); // chỉ có tên tỉnh: không tách
  });

  test('tiền tố hành chính, so tên tỉnh', () {
    expect(stripAdminPrefix('xã Tân Lập'), 'Tân Lập');
    expect(stripAdminPrefix('Thị trấn Sa Pa'), 'Sa Pa');
    expect(stripAdminPrefix('Phường Hải Châu'), 'Hải Châu');
    expect(hasAdminPrefix('Tân Lập'), isFalse);
    expect(sameProvince('Tỉnh Tây Ninh', 'Tây Ninh'), isTrue);
    expect(sameProvince('Thành phố Hồ Chí Minh', 'Hồ Chí Minh'), isTrue);
    expect(sameProvince('Tỉnh Lâm Đồng', 'Tây Ninh'), isFalse);
    expect(provincesNow.length, 34);
  });
}

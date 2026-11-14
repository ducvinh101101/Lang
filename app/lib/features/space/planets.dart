// KHÁM PHÁ VŨ TRỤ: mỗi thiên thể là một "tập truyện audio" vài phút, kể từng đoạn ngắn để người nghe có thể
// dừng, nghe tiếp hoặc hỏi xen. So sánh kích thước theo một thước đo quen thuộc:
//   "Nếu Trái Đất là một hạt đậu xanh (khoảng 8 mi-li-mét)…"
// (đã tính theo đường kính thật: Sao Mộc ≈ 9 cm = quả cam lớn, Mặt Trời ≈ 87 cm = quả bóng tập thể dục).
// Số liệu theo NASA (science.nasa.gov / nssdc.gsfc.nasa.gov). Âm thanh đặc trưng do app tổng hợp (audio/synth.dart).
import 'dart:ui' show Color;

import '../voice/commands.dart' show normVi;

class Planet {
  final int sound; // chỉ số âm thanh planet_<n>
  final String vi, en;
  final List<String> aliases; // đã bỏ dấu
  final Color color, color2;
  final bool rings, bands;
  final List<String> chapters;
  const Planet(this.sound, this.vi, this.en, this.aliases, this.color, this.color2, this.chapters,
      {this.rings = false, this.bands = false});

  /// Tóm tắt cho trợ lý AI khi người nghe hỏi tiếp.
  String get facts => chapters.join(' ');
}

const planets = <Planet>[
  Planet(0, 'Mặt Trời', 'the Sun', ['mat troi', 'ong mat troi', 'sun'], Color(0xFFFFC34D), Color(0xFFFF7A1A), [
    'Tập truyện: Mặt Trời, ngọn lửa giữ ấm cả Hệ Mặt Trời. Mặt Trời không phải là hành tinh mà là một ngôi sao, ngôi sao gần chúng ta nhất. '
        'Nó là một quả cầu khí nóng khổng lồ, chủ yếu là hy-đrô và hê-li. Mặt Trời nặng gấp khoảng 333 nghìn lần Trái Đất '
        'và chiếm khoảng 99,8 phần trăm khối lượng của cả Hệ Mặt Trời.',
    'Đường kính Mặt Trời lớn gấp khoảng 109 lần Trái Đất. Hãy tưởng tượng Trái Đất chỉ là một hạt đậu xanh nằm trong lòng bàn tay bạn. '
        'Khi đó Mặt Trời to như một quả bóng tập thể dục, cao gần tới thắt lưng. Lòng Mặt Trời có thể chứa khoảng 1 triệu 300 nghìn Trái Đất.',
    'Bề mặt Mặt Trời nóng khoảng 5500 độ C, còn ở lõi tới khoảng 15 triệu độ. Trong lõi, các hạt hy-đrô liên tục hợp nhất thành hê-li, '
        'gọi là phản ứng tổng hợp hạt nhân, giải phóng năng lượng thành ánh sáng và hơi ấm.',
    'Ánh sáng từ Mặt Trời tới Trái Đất mất khoảng 8 phút 20 giây, qua quãng đường khoảng 150 triệu ki-lô-mét. '
        'Nghĩa là khi bạn cảm thấy nắng ấm trên da, đó là ánh sáng đã rời Mặt Trời từ hơn 8 phút trước.',
    'Mặt Trời không hề yên tĩnh. Nó có những vết đen, những vụ bùng nổ gọi là lửa Mặt Trời, và luôn thổi ra một dòng hạt gọi là gió Mặt Trời. '
        'Khi dòng hạt này chạm vào từ trường Trái Đất, ở gần hai cực sinh ra cực quang lung linh. Mặt Trời mạnh lên rồi yếu đi theo chu kỳ khoảng 11 năm.',
    'Mặt Trời đã khoảng 4,6 tỷ năm tuổi, mới đi được khoảng nửa cuộc đời. Tàu Parker Solar Probe của NASA là vật thể do con người làm ra bay gần Mặt Trời nhất: '
        'cuối năm 2024, nó lướt qua cách bề mặt khoảng 6 triệu ki-lô-mét, với tốc độ gần 700 nghìn ki-lô-mét một giờ. '
        'Một lời nhắc nhỏ: đừng bao giờ nhìn thẳng vào Mặt Trời. Hết tập. Bạn có thể hỏi mình bất cứ điều gì về Mặt Trời.',
  ]),
  Planet(1, 'Sao Thủy', 'Mercury', ['sao thuy', 'thuy tinh', 'mercury'], Color(0xFFA9A49C), Color(0xFF6E6A64), [
    'Tập truyện: Sao Thủy, hành tinh nhỏ nhất và gần Mặt Trời nhất. Sao Thủy cách Mặt Trời trung bình khoảng 58 triệu ki-lô-mét, '
        'chỉ bằng khoảng bốn phần mười khoảng cách từ Trái Đất tới Mặt Trời.',
    'Đường kính Sao Thủy khoảng 4880 ki-lô-mét, chỉ lớn hơn Mặt Trăng một chút. Nếu Trái Đất là một hạt đậu xanh, thì Sao Thủy chỉ như một hạt vừng. '
        'Có những mặt trăng còn to hơn Sao Thủy, như Ganymede của Sao Mộc và Titan của Sao Thổ.',
    'Sao Thủy chạy quanh Mặt Trời nhanh nhất: một năm ở đó chỉ dài 88 ngày Trái Đất. Nhưng nó tự quay rất chậm. '
        'Tính từ lúc Mặt Trời mọc tới lần mọc tiếp theo, một ngày trên Sao Thủy dài khoảng 176 ngày Trái Đất. Tức là một ngày dài bằng hai năm!',
    'Sao Thủy gần như không có khí quyển để giữ nhiệt. Ban ngày nóng tới khoảng 430 độ C, đủ làm chảy chì; ban đêm lạnh xuống khoảng âm 180 độ. '
        'Chênh lệch hơn 600 độ, lớn nhất trong các hành tinh.',
    'Bề mặt Sao Thủy đầy hố va chạm, trông giống Mặt Trăng. Điều bất ngờ là trong những hố sâu gần hai cực, nơi ánh nắng không bao giờ chiếu tới, '
        'các nhà khoa học đã tìm thấy dấu hiệu của băng nước.',
    'Tàu MESSENGER của NASA đã bay quanh Sao Thủy từ năm 2011 đến năm 2015 và vẽ bản đồ toàn bộ hành tinh. '
        'Tàu BepiColombo của châu Âu và Nhật Bản đang trên đường tới đó để nghiên cứu tiếp. Hết tập. Bạn có thể hỏi mình về Sao Thủy.',
  ]),
  Planet(2, 'Sao Kim', 'Venus', ['sao kim', 'kim tinh', 'venus', 'sao mai', 'sao hom'], Color(0xFFE8C98A), Color(0xFFB98A45), [
    'Tập truyện: Sao Kim, hành tinh nóng nhất dù không gần Mặt Trời nhất. Sao Kim là hành tinh thứ hai, cách Mặt Trời khoảng 108 triệu ki-lô-mét. '
        'Người Việt quen gọi nó là sao Mai khi mọc lúc rạng sáng, và sao Hôm khi hiện ra lúc chiều tối. Sau Mặt Trăng, nó là vật sáng nhất trên bầu trời đêm.',
    'Sao Kim gần bằng Trái Đất: đường kính khoảng 12100 ki-lô-mét, bằng 95 phần trăm Trái Đất. Nếu Trái Đất là một hạt đậu xanh, '
        'Sao Kim là một hạt đậu xanh nhỏ hơn một chút. Vì thế người ta gọi nó là chị em sinh đôi của Trái Đất. Nhưng hai chị em này rất khác tính.',
    'Bề mặt Sao Kim nóng khoảng 465 độ C, nóng hơn cả Sao Thủy dù Sao Thủy gần Mặt Trời hơn. Lý do là khí quyển Sao Kim cực dày, gần như toàn khí CO2, '
        'giữ nhiệt như một tấm chăn khổng lồ. Đó là hiệu ứng nhà kính. Ngày hay đêm, ở xích đạo hay ở cực, nhiệt độ gần như nhau.',
    'Áp suất không khí trên mặt đất Sao Kim lớn gấp khoảng 90 lần Trái Đất, giống như bạn đang lặn sâu gần một cây số dưới biển. '
        'Trên cao là những đám mây axit sun-fu-ric dày đặc che kín bầu trời.',
    'Sao Kim quay rất chậm, và quay ngược chiều với hầu hết các hành tinh, nên ở đó Mặt Trời mọc ở phía tây, lặn ở phía đông. '
        'Nó cần 243 ngày Trái Đất để tự quay một vòng, lâu hơn cả một năm của nó là 225 ngày.',
    'Năm 1970, tàu Venera 7 của Liên Xô là tàu đầu tiên hạ cánh xuống một hành tinh khác và gửi được tín hiệu về Trái Đất. '
        'Các tàu sau đó chỉ trụ được chừng một, hai giờ trước khi bị sức nóng và áp suất phá hủy. NASA đang chuẩn bị các sứ mệnh mới tên là DAVINCI và VERITAS. '
        'Hết tập. Bạn có thể hỏi mình về Sao Kim.',
  ]),
  Planet(3, 'Trái Đất', 'Earth', ['trai dat', 'dia cau', 'earth'], Color(0xFF3F7FBF), Color(0xFF2F6B3A), [
    'Tập truyện: Trái Đất, ngôi nhà xanh của chúng ta. Trái Đất là hành tinh thứ ba tính từ Mặt Trời, cách Mặt Trời khoảng 150 triệu ki-lô-mét. '
        'Đây là nơi duy nhất mà con người biết là có sự sống.',
    'Đường kính Trái Đất khoảng 12742 ki-lô-mét. Khoảng 71 phần trăm bề mặt là đại dương. Nước ở đây tồn tại cả ba dạng: lỏng trong biển, '
        'rắn trong băng, và hơi trong mây. Điều này rất hiếm có trong Hệ Mặt Trời.',
    'Khí quyển Trái Đất gồm khoảng 78 phần trăm khí ni-tơ và 21 phần trăm ô-xi. Nó cho ta thở, giữ ấm như một tấm chăn, '
        'và tầng ô-dôn che bớt tia cực tím. Từ trường Trái Đất như một tấm khiên vô hình, đẩy lùi dòng hạt từ Mặt Trời.',
    'Trái Đất tự quay một vòng mất khoảng 24 giờ, tạo ra ngày và đêm. Nó đi quanh Mặt Trời mất khoảng 365 ngày 6 giờ, vì vậy cứ bốn năm lại có một năm nhuận. '
        'Trục Trái Đất nghiêng khoảng 23,5 độ nên có các mùa: miền Bắc Việt Nam có mùa đông lạnh và mùa hè nóng.',
    'Ứng dụng này được làm cho cuộc thi của NASA về khí hậu. Dữ liệu vệ tinh cho thấy Trái Đất đang ấm lên: nhiệt độ trung bình toàn cầu đã cao hơn '
        'cuối thế kỷ 19 hơn một độ, kéo theo nắng nóng, mưa lớn và nước biển dâng nhiều hơn. Bạn có thể nói: khí hậu Hà Nội, để nghe nơi mình đã thay đổi ra sao.',
    'Trái Đất có một vệ tinh tự nhiên là Mặt Trăng. Mặt Trăng giúp giữ trục Trái Đất ổn định và tạo nên thủy triều. '
        'Từ không gian, các nhà du hành thấy Trái Đất như một viên bi xanh trắng giữa bóng tối. Hết tập. Bạn có thể hỏi mình về Trái Đất.',
  ]),
  Planet(4, 'Mặt Trăng', 'the Moon', ['mat trang', 'ong trang', 'moon'], Color(0xFFC9C6C0), Color(0xFF7F7C77), [
    'Tập truyện: Mặt Trăng, người bạn đồng hành của Trái Đất. Mặt Trăng cách chúng ta trung bình khoảng 384 nghìn ki-lô-mét. '
        'Ánh sáng đi quãng đường đó chỉ mất khoảng 1,3 giây.',
    'Đường kính Mặt Trăng khoảng 3475 ki-lô-mét, bằng khoảng một phần tư Trái Đất. Nếu Trái Đất là một hạt đậu xanh, '
        'Mặt Trăng chỉ như một hạt kê, đặt cách hạt đậu khoảng 24 cen-ti-mét, tức gần một gang tay.',
    'Trọng lực trên Mặt Trăng chỉ bằng khoảng một phần sáu Trái Đất. Một người nặng 60 ký sẽ thấy mình nhẹ như 10 ký, và có thể nhảy cao gấp nhiều lần.',
    'Mặt Trăng tự quay một vòng đúng bằng thời gian nó đi quanh Trái Đất, khoảng 27 ngày, nên luôn hướng một mặt về phía chúng ta. '
        'Mặt Trăng không tự phát sáng mà phản chiếu ánh sáng Mặt Trời. Vì thế ta thấy trăng khuyết rồi tròn theo chu kỳ khoảng 29 ngày rưỡi, '
        'đó là cơ sở của âm lịch, của ngày rằm và Tết Trung thu.',
    'Mặt Trăng gần như không có không khí, nên không có gió và âm thanh không truyền đi được. Ban ngày nóng khoảng 120 độ C, ban đêm lạnh xuống khoảng âm 170 độ. '
        'Dấu chân của các nhà du hành có thể còn nguyên hàng triệu năm.',
    'Ngày 20 tháng 7 năm 1969, Neil Armstrong và Buzz Aldrin của sứ mệnh Apollo 11 trở thành những người đầu tiên đặt chân lên Mặt Trăng. '
        'Đến năm 1972 đã có 12 người đi bộ trên đó. Chương trình Artemis của NASA đang chuẩn bị đưa con người quay lại. '
        'Mặt Trăng còn đang xa dần Trái Đất, khoảng 3,8 cen-ti-mét mỗi năm. Hết tập. Bạn có thể hỏi mình về Mặt Trăng.',
  ]),
  Planet(5, 'Sao Hỏa', 'Mars', ['sao hoa', 'hoa tinh', 'mars', 'hanh tinh do'], Color(0xFFC1440E), Color(0xFF7A2A0A), [
    'Tập truyện: Sao Hỏa, hành tinh đỏ. Sao Hỏa là hành tinh thứ tư tính từ Mặt Trời, cách Mặt Trời khoảng 228 triệu ki-lô-mét. '
        'Màu đỏ cam của nó đến từ bụi sắt ô-xít, tức là gỉ sắt, phủ khắp bề mặt.',
    'Đường kính Sao Hỏa khoảng 6780 ki-lô-mét, chỉ bằng khoảng một nửa Trái Đất. Nếu Trái Đất là một hạt đậu xanh, Sao Hỏa như một hạt tiêu. '
        'Trọng lực ở đó bằng khoảng 38 phần trăm Trái Đất: người nặng 50 ký sẽ thấy mình chỉ nặng chừng 19 ký.',
    'Một ngày trên Sao Hỏa dài 24 giờ 37 phút, gần giống Trái Đất. Nhưng một năm dài 687 ngày, gần gấp đôi năm của chúng ta. '
        'Trục của nó nghiêng gần giống Trái Đất, nên Sao Hỏa cũng có bốn mùa, mỗi mùa dài gần gấp đôi.',
    'Khí quyển Sao Hỏa rất mỏng, chủ yếu là CO2, áp suất chưa bằng một phần trăm Trái Đất. Nhiệt độ trung bình khoảng âm 60 độ C. '
        'Ở đó có những cơn bão bụi có thể phủ kín cả hành tinh trong nhiều tuần. Hai cực có chỏm băng, gồm cả băng nước và băng khô.',
    'Sao Hỏa có ngọn núi lửa cao nhất Hệ Mặt Trời là Olympus Mons, cao khoảng 22 ki-lô-mét, gấp hai lần rưỡi đỉnh Everest. '
        'Nó còn có hẻm núi Valles Marineris dài khoảng 4000 ki-lô-mét, gần gấp đôi quốc lộ 1 từ Lạng Sơn đến Cà Mau.',
    'Nhiều dấu vết cho thấy xưa kia Sao Hỏa từng có sông và hồ. Xe tự hành Curiosity của NASA hạ cánh năm 2012, và xe Perseverance năm 2021 '
        'đang thu thập mẫu đá để tìm dấu vết sự sống cổ xưa. Đi cùng Perseverance là chiếc trực thăng nhỏ Ingenuity, '
        'máy bay có động cơ đầu tiên bay trên một hành tinh khác. Sao Hỏa có hai mặt trăng nhỏ hình củ khoai tên là Phobos và Deimos. '
        'Hết tập. Bạn có thể hỏi mình về Sao Hỏa.',
  ]),
  Planet(6, 'Sao Mộc', 'Jupiter', ['sao moc', 'moc tinh', 'jupiter'], Color(0xFFD8B48A), Color(0xFFA0633A), [
    'Tập truyện: Sao Mộc, gã khổng lồ của Hệ Mặt Trời. Sao Mộc là hành tinh thứ năm, cách Mặt Trời khoảng 778 triệu ki-lô-mét. '
        'Nó là hành tinh khí: không có mặt đất để đứng, chỉ toàn khí hy-đrô và hê-li, càng xuống sâu càng đặc và nóng.',
    'Đường kính Sao Mộc gấp khoảng 11 lần Trái Đất, và lòng nó có thể chứa hơn 1300 Trái Đất. Nếu Trái Đất là một hạt đậu xanh, '
        'thì Sao Mộc to bằng một quả cam lớn. Sao Mộc nặng hơn tất cả các hành tinh khác cộng lại, gấp hơn hai lần.',
    'Dù khổng lồ, Sao Mộc lại quay nhanh nhất: một ngày ở đó chỉ dài khoảng 10 giờ. Quay nhanh làm mây kéo dài thành những dải sọc màu kem và nâu đỏ '
        'chạy quanh hành tinh. Còn một năm của Sao Mộc dài gần 12 năm Trái Đất.',
    'Vết Đỏ Lớn trên Sao Mộc là một cơn bão xoáy khổng lồ, rộng hơn cả Trái Đất, đã được quan sát liên tục hơn 150 năm. '
        'Sao Mộc còn có từ trường cực mạnh và những cực quang rực rỡ nhất Hệ Mặt Trời.',
    'Sao Mộc có hơn một trăm mặt trăng. Bốn mặt trăng lớn do Galileo phát hiện năm 1610: Io có hàng trăm núi lửa đang hoạt động; '
        'Europa có thể có một đại dương nước mặn dưới lớp băng; Ganymede là mặt trăng lớn nhất Hệ Mặt Trời, còn lớn hơn Sao Thủy; và Callisto đầy hố va chạm.',
    'Tàu Juno của NASA đã bay quanh Sao Mộc từ năm 2016. Tàu Europa Clipper, phóng tháng 10 năm 2024, đang trên đường tới để tìm hiểu '
        'đại dương dưới băng của Europa có thể nuôi sự sống hay không. Lực hấp dẫn khổng lồ của Sao Mộc còn kéo lệch nhiều sao chổi, '
        'góp phần che chắn các hành tinh bên trong. Hết tập. Bạn có thể hỏi mình về Sao Mộc.',
  ], bands: true),
  Planet(7, 'Sao Thổ', 'Saturn', ['sao tho', 'tho tinh', 'saturn'], Color(0xFFE3CF9A), Color(0xFFB59A5A), [
    'Tập truyện: Sao Thổ, hành tinh có vành đai đẹp nhất. Sao Thổ là hành tinh thứ sáu, cách Mặt Trời khoảng 1,4 tỷ ki-lô-mét. '
        'Giống Sao Mộc, nó là hành tinh khí, chủ yếu là hy-đrô và hê-li.',
    'Đường kính Sao Thổ gấp khoảng 9 lần Trái Đất. Nếu Trái Đất là một hạt đậu xanh, Sao Thổ như một quả quýt to, còn vành đai trải rộng chừng một cái đĩa ăn cơm. '
        'Điều kỳ lạ: Sao Thổ nhẹ đến mức tính trung bình nó còn kém đặc hơn nước. Nếu có một bồn nước đủ lớn, Sao Thổ sẽ nổi.',
    'Vành đai Sao Thổ gồm vô số mảnh băng và đá, nhỏ như hạt cát đến to như ngôi nhà. Vành đai rộng hàng trăm nghìn ki-lô-mét, '
        'nhưng phần lớn chỉ dày khoảng chục mét đến một ki-lô-mét. Nếu thu nhỏ theo tỉ lệ, nó còn mỏng hơn một tờ giấy.',
    'Một ngày trên Sao Thổ dài khoảng 10 giờ rưỡi, còn một năm dài khoảng 29 năm Trái Đất. Ở cực bắc có một luồng mây xoáy hình lục giác kỳ lạ, '
        'mỗi cạnh còn dài hơn đường kính Trái Đất.',
    'Sao Thổ có 293 mặt trăng đã xác nhận theo NASA tính đến năm 2026, nhiều nhất Hệ Mặt Trời. Titan, mặt trăng lớn nhất, có khí quyển dày và những hồ chứa mê-tan lỏng: '
        'nơi duy nhất ngoài Trái Đất có hồ chất lỏng trên bề mặt. Mặt trăng Enceladus phun những cột hơi nước và băng từ đại dương ngầm ra không gian.',
    'Tàu Cassini của NASA và châu Âu bay quanh Sao Thổ 13 năm, từ 2004 đến 2017, và thả tàu Huygens hạ cánh xuống Titan năm 2005. '
        'Sứ mệnh Dragonfly của NASA sẽ đưa một chiếc máy bay không người lái tới bay trên Titan. Hết tập. Bạn có thể hỏi mình về Sao Thổ.',
  ], rings: true, bands: true),
  Planet(8, 'Sao Thiên Vương', 'Uranus', ['sao thien vuong', 'thien vuong tinh', 'thien vuong', 'uranus'], Color(0xFF9FD8E0), Color(0xFF5FA8B8), [
    'Tập truyện: Sao Thiên Vương, hành tinh nằm nghiêng. Đây là hành tinh thứ bảy, cách Mặt Trời khoảng 2,9 tỷ ki-lô-mét. '
        'Nó là hành tinh đầu tiên được phát hiện bằng kính thiên văn, bởi nhà thiên văn William Herschel năm 1781.',
    'Đường kính Sao Thiên Vương gấp khoảng 4 lần Trái Đất. Nếu Trái Đất là một hạt đậu xanh, Sao Thiên Vương như một quả vải. '
        'Nó là một hành tinh băng khổng lồ: bên trong nhiều nước, a-mô-ni-ắc và mê-tan. Khí mê-tan làm nó có màu xanh lơ nhạt.',
    'Điều đặc biệt nhất: trục quay của Sao Thiên Vương nghiêng khoảng 98 độ, nên nó gần như lăn tròn trên đường đi như một quả bóng. '
        'Một năm ở đó dài 84 năm Trái Đất, nên mỗi cực lần lượt có khoảng 42 năm ban ngày liên tục, rồi 42 năm đêm tối.',
    'Sao Thiên Vương có khí quyển lạnh nhất trong các hành tinh, có lúc xuống khoảng âm 224 độ C, lạnh hơn cả Sao Hải Vương ở xa hơn.',
    'Nó có 13 vành đai mảnh và tối màu, cùng gần ba mươi mặt trăng. Nhiều mặt trăng được đặt tên theo nhân vật trong kịch của Shakespeare, '
        'như Miranda, Ariel, Titania và Oberon.',
    'Đến nay mới chỉ có một con tàu ghé thăm Sao Thiên Vương: Voyager 2 của NASA, bay ngang qua năm 1986. '
        'Các nhà khoa học đang đề xuất một sứ mệnh mới để quay lại nghiên cứu hành tinh kỳ lạ này. Hết tập. Bạn có thể hỏi mình về Sao Thiên Vương.',
  ], rings: true),
  Planet(9, 'Sao Hải Vương', 'Neptune', ['sao hai vuong', 'hai vuong tinh', 'hai vuong', 'neptune'], Color(0xFF3F5FD8), Color(0xFF22348A), [
    'Tập truyện: Sao Hải Vương, hành tinh xa nhất và lộng gió nhất. Đây là hành tinh thứ tám, cách Mặt Trời khoảng 4,5 tỷ ki-lô-mét. '
        'Ánh sáng Mặt Trời phải đi hơn 4 giờ mới tới được đó.',
    'Sao Hải Vương là hành tinh đầu tiên được tìm ra nhờ tính toán. Các nhà thiên văn thấy Sao Thiên Vương chạy hơi lệch, và đoán có một hành tinh khác đang kéo nó. '
        'Năm 1846, dựa vào tính toán của Urbain Le Verrier, Johann Galle đã tìm thấy Sao Hải Vương gần đúng vị trí dự đoán.',
    'Đường kính Sao Hải Vương gấp khoảng 4 lần Trái Đất, cũng như một quả vải nếu Trái Đất là hạt đậu xanh. '
        'Nó có màu xanh lam đậm do khí mê-tan, và cũng là một hành tinh băng khổng lồ như Sao Thiên Vương.',
    'Sao Hải Vương có gió mạnh nhất Hệ Mặt Trời, lên tới khoảng 2000 ki-lô-mét một giờ, nhanh hơn cả tốc độ âm thanh trên Trái Đất. '
        'Năm 1989, tàu Voyager 2 nhìn thấy một cơn bão tối khổng lồ ở đó, gọi là Vết Tối Lớn.',
    'Một năm của Sao Hải Vương dài khoảng 165 năm Trái Đất. Từ khi được phát hiện năm 1846, phải đến năm 2011 nó mới đi trọn một vòng quanh Mặt Trời.',
    'Mặt trăng lớn nhất của nó là Triton, chạy ngược chiều quay của hành tinh và có những mạch phun khí ni-tơ. '
        'Triton lạnh khoảng âm 235 độ C, một trong những nơi lạnh nhất từng đo được. Hết tập, cũng là điểm cuối chuyến du hành qua các hành tinh. '
        'Bạn có thể hỏi mình bất cứ điều gì.',
  ], rings: true),
];

/// Tìm thiên thể theo câu nói (bỏ dấu, khớp nguyên cụm).
Planet? planetIn(String text) {
  // "sao hôm nay nóng thế" = "sao (tại sao) hôm nay…", không phải Sao Hôm (Sao Kim)
  final t = ' ${normVi(text)} '.replaceAll(' sao hom nay ', ' hom nay ');
  Planet? best, other;
  var len = 0, otherLen = 0;
  for (final p in planets) {
    for (final a in p.aliases) {
      if (!t.contains(' $a ')) continue;
      if (a.length > len) {
        best = p;
        len = a.length;
      }
      // hành tinh KHÁC Mặt Trăng VÀ KHÁC Trái Đất cũng được nhắc tới
      // (trừ câu gọi tên "Trái Đất ơi, kể về Mặt Trăng")
      if (!p.aliases.contains('mat trang') && !p.aliases.contains('trai dat') && a.length > otherLen && !t.contains(' $a oi ')) {
        other = p;
        otherLen = a.length;
      }
    }
  }
  // "Sao Hỏa có mấy mặt trăng", "mặt trăng của Sao Mộc": "mặt trăng" ở đây là VỆ TINH của hành tinh kia → hỏi hành tinh đó
  final satellite = RegExp(r' (may|bao nhieu|nhung|cac|hai|nhieu) mat trang | mat trang cua | how many moons ').hasMatch(t);
  if (best != null && best.aliases.contains('mat trang') && other != null && satellite) return other;
  // So sánh hành tinh với Trái Đất ("Sao Hỏa cách Trái Đất bao xa", "từ Trái Đất đến Sao Hỏa", "Sao Mộc to gấp mấy lần Trái Đất"):
  final compareEarth = RegExp(r' (cach|tu|den|so voi|gap|bao xa|bao nhieu ki lo met|bao lau|nhu the nao|the nao) ').hasMatch(t);
  if (best != null && best.aliases.contains('trai dat') && other != null && compareEarth) return other;
  return best;
}

const planetListVi = 'Hệ Mặt Trời gồm Mặt Trời và tám hành tinh, tính từ trong ra: Sao Thủy, Sao Kim, Trái Đất, Sao Hỏa, Sao Mộc, Sao Thổ, '
    'Sao Thiên Vương và Sao Hải Vương. Mình còn có tập về Mặt Trăng. Bạn nói, ví dụ: kể chuyện Sao Kim, hoặc kể chuyện Sao Mộc. '
    'Trong lúc nghe, sau mỗi đoạn mình dừng một chút: bạn nói "dừng" để thôi, "tiếp" để nghe tiếp, hoặc hỏi luôn một câu.';

// ĐỊA DANH NỔI BẬT CỦA VIỆT NAM theo vùng miền — dữ liệu NHẸ, có sẵn trong app (không cần mạng):
// toạ độ + vài câu giới thiệu ngắn, dễ nghe. Dùng cho:
//   • "kể về Vịnh Hạ Long", "Phố cổ Hội An có gì", "Sa Pa ở đâu" → bay tới và giới thiệu
//   • "miền Trung có địa danh gì nổi tiếng", "Tây Nguyên có gì đẹp", "ở Quảng Ninh có gì" → kể tên các nơi
//   • "thời tiết Sa Pa", "thời tiết Mũi Né" → toạ độ có sẵn, khỏi chờ dịch vụ tìm địa điểm
// Tên tỉnh theo đơn vị hành chính từ 1/7/2025 (34 tỉnh, thành).
import 'dart:math' as math;

import '../voice/commands.dart' show normVi;

class Landmark {
  final String name, en;
  final List<String> aliases; // đã bỏ dấu, viết thường
  final String province; // tỉnh / thành phố hiện nay
  final String region; // 'bac' | 'trung' | 'taynguyen' | 'nam'
  final double lat, lon;
  final String vi; // giới thiệu tiếng Việt
  final String enText; // một câu tiếng Anh
  const Landmark(this.name, this.en, this.aliases, this.province, this.region, this.lat, this.lon, this.vi, this.enText);
}

const regionNamesVi = {
  'bac': 'miền Bắc',
  'trung': 'miền Trung',
  'taynguyen': 'Tây Nguyên',
  'nam': 'miền Nam',
};
const regionNamesEn = {
  'bac': 'Northern Viet Nam',
  'trung': 'Central Viet Nam',
  'taynguyen': 'the Central Highlands',
  'nam': 'Southern Viet Nam',
};

const vnLandmarks = <Landmark>[
  // ---------------- MIỀN BẮC ----------------
  Landmark('Vịnh Hạ Long', 'Ha Long Bay', ['vinh ha long', 'ha long bay'], 'Quảng Ninh', 'bac', 20.91, 107.18,
      'Vịnh Hạ Long có khoảng một nghìn sáu trăm hòn đảo đá vôi nhô lên giữa làn nước xanh, nhiều đảo có hang động lớn như hang Sửng Sốt, động Thiên Cung. '
          'Đây là Di sản thiên nhiên thế giới được UNESCO công nhận từ năm 1994. Du khách thường đi tàu ngắm vịnh, chèo thuyền kayak và ngủ đêm trên vịnh.',
      'Ha Long Bay has about 1,600 limestone islands and is a UNESCO World Heritage Site.'),
  Landmark('Yên Tử', 'Yen Tu Mountain', ['yen tu', 'nui yen tu'], 'Quảng Ninh', 'bac', 21.12, 106.72,
      'Núi Yên Tử là nơi vua Trần Nhân Tông tu hành và lập nên dòng Thiền Trúc Lâm của người Việt. '
          'Trên núi có nhiều chùa, tháp cổ; chùa Đồng nằm gần đỉnh, cao hơn một nghìn mét. Mùa lễ hội đầu xuân rất đông người hành hương.',
      'Yen Tu is a sacred mountain where King Tran Nhan Tong founded the Truc Lam Zen school.'),
  Landmark('Hồ Hoàn Kiếm', 'Hoan Kiem Lake', ['ho hoan kiem', 'hoan kiem', 'ho guom', 'hoan kiem lake'], 'Hà Nội', 'bac', 21.0288, 105.8525,
      'Hồ Hoàn Kiếm, còn gọi là Hồ Gươm, nằm giữa trung tâm Hà Nội. Tên hồ gắn với truyền thuyết vua Lê Lợi trả gươm thần cho Rùa Vàng. '
          'Giữa hồ có Tháp Rùa; phía bắc hồ là đền Ngọc Sơn với cây cầu Thê Húc sơn đỏ. Cuối tuần, phố đi bộ quanh hồ rất nhộn nhịp.',
      'Hoan Kiem Lake, in the heart of Hanoi, is linked to the legend of King Le Loi returning a magic sword.'),
  Landmark('Văn Miếu Quốc Tử Giám', 'Temple of Literature', ['van mieu', 'van mieu quoc tu giam', 'quoc tu giam', 'temple of literature'],
      'Hà Nội', 'bac', 21.0294, 105.8355,
      'Văn Miếu được xây năm 1070 thời vua Lý Thánh Tông để thờ Khổng Tử. Năm 1076, Quốc Tử Giám được lập ở đây, được xem là trường đại học đầu tiên của Việt Nam. '
          'Trong khuôn viên có 82 tấm bia khắc tên các tiến sĩ, đặt trên lưng rùa đá.',
      'The Temple of Literature dates from 1070 and housed Viet Nam\'s first national university.'),
  Landmark('Hoàng thành Thăng Long', 'Imperial Citadel of Thang Long', ['hoang thanh thang long', 'hoang thanh', 'thanh thang long'],
      'Hà Nội', 'bac', 21.0353, 105.8403,
      'Hoàng thành Thăng Long là trung tâm quyền lực của nhiều triều đại suốt hơn một nghìn năm, từ thời Lý. '
          'Nơi đây có Đoan Môn, điện Kính Thiên và khu khảo cổ 18 Hoàng Diệu. Hoàng thành là Di sản văn hóa thế giới từ năm 2010.',
      'The Imperial Citadel of Thang Long was the seat of Vietnamese dynasties for over a thousand years.'),
  Landmark('Lăng Chủ tịch Hồ Chí Minh', 'Ho Chi Minh Mausoleum', ['lang bac', 'lang chu tich ho chi minh', 'lang ho chi minh', 'quang truong ba dinh', 'ba dinh'],
      'Hà Nội', 'bac', 21.0368, 105.8346,
      'Lăng Chủ tịch Hồ Chí Minh nằm trên Quảng trường Ba Đình, nơi Bác Hồ đọc Tuyên ngôn Độc lập ngày 2 tháng 9 năm 1945. '
          'Gần lăng có Nhà sàn Bác Hồ và Chùa Một Cột.',
      'The Ho Chi Minh Mausoleum stands on Ba Dinh Square, where independence was declared in 1945.'),
  Landmark('Phố cổ Hà Nội', 'Hanoi Old Quarter', ['pho co ha noi', 'pho co', '36 pho phuong', 'ba muoi sau pho phuong', 'old quarter'],
      'Hà Nội', 'bac', 21.0340, 105.8500,
      'Phố cổ Hà Nội nằm ngay phía bắc Hồ Hoàn Kiếm, được gọi là ba mươi sáu phố phường. Nhiều phố mang tên món hàng bán ở đó xưa kia '
          'như Hàng Bạc, Hàng Đào, Hàng Mã, Hàng Đường. Nhà ống hẹp và sâu, phố nhỏ đông người và xe máy, có chợ Đồng Xuân và nhiều món ăn đường phố.',
      'The Old Quarter, north of Hoan Kiem Lake, has streets named after the goods once sold there.'),
  Landmark('Hồ Tây', 'West Lake', ['ho tay', 'west lake'], 'Hà Nội', 'bac', 21.0560, 105.8200,
      'Hồ Tây là hồ lớn nhất trong nội thành Hà Nội, rộng khoảng năm trăm héc-ta, đi một vòng quanh hồ khoảng mười bảy cây số. '
          'Quanh hồ có chùa Trấn Quốc, phủ Tây Hồ, đường Thanh Niên rợp bóng cây; chiều tối nhiều người ra ngắm hoàng hôn trên hồ.',
      'West Lake is the largest lake in central Hanoi, with Tran Quoc Pagoda on its shore.'),
  Landmark('Chùa Trấn Quốc', 'Tran Quoc Pagoda', ['chua tran quoc', 'tran quoc pagoda'], 'Hà Nội', 'bac', 21.0479, 105.8366,
      'Chùa Trấn Quốc nằm trên một bán đảo nhỏ ở phía đông Hồ Tây, được xem là ngôi chùa cổ nhất Hà Nội, có từ thế kỷ thứ sáu. '
          'Chùa có bảo tháp nhiều tầng và cây bồ đề được chiết từ cây bồ đề ở Ấn Độ.',
      'Tran Quoc Pagoda, on a small peninsula of West Lake, is considered the oldest pagoda in Hanoi.'),
  Landmark('Chùa Một Cột', 'One Pillar Pagoda', ['chua mot cot', 'one pillar pagoda'], 'Hà Nội', 'bac', 21.0359, 105.8336,
      'Chùa Một Cột được dựng năm 1049 thời vua Lý Thái Tông. Ngôi chùa nhỏ đặt trên một cột đá giữa hồ vuông, '
          'trông như một bông sen nở trên mặt nước. Chùa nằm gần Lăng Chủ tịch Hồ Chí Minh.',
      'The One Pillar Pagoda, built in 1049, stands on a single stone pillar like a lotus rising from a pond.'),
  Landmark('Nhà hát Lớn Hà Nội', 'Hanoi Opera House', ['nha hat lon', 'nha hat lon ha noi', 'opera house'], 'Hà Nội', 'bac', 21.0242, 105.8575,
      'Nhà hát Lớn Hà Nội được người Pháp xây xong năm 1911, kiến trúc mô phỏng Nhà hát Opera Paris, có mái vòm và hàng cột lớn. '
          'Đến nay nhà hát vẫn biểu diễn nhạc giao hưởng, nhạc kịch và tổ chức nhiều sự kiện văn hóa lớn.',
      'The Hanoi Opera House, finished in 1911, was modelled on the Paris Opera.'),
  Landmark('Cầu Long Biên', 'Long Bien Bridge', ['cau long bien', 'long bien bridge'], 'Hà Nội', 'bac', 21.0434, 105.8592,
      'Cầu Long Biên là cây cầu thép bắc qua sông Hồng, được xây từ năm 1898 đến năm 1902. Cầu dài hơn hai cây số tính cả đường dẫn, '
          'ngày nay chỉ dành cho tàu hỏa, xe máy, xe đạp và người đi bộ. Đứng trên cầu nghe rõ tiếng tàu và tiếng gió sông Hồng.',
      'Long Bien Bridge is a steel bridge over the Red River, built from 1898 to 1902.'),
  Landmark('Nhà tù Hỏa Lò', 'Hoa Lo Prison', ['nha tu hoa lo', 'hoa lo', 'hoa lo prison'], 'Hà Nội', 'bac', 21.0253, 105.8466,
      'Nhà tù Hỏa Lò được người Pháp xây cuối thế kỷ mười chín để giam giữ những người Việt Nam yêu nước. '
          'Nay một phần nhà tù được giữ lại làm di tích, kể lại cuộc sống và đấu tranh của các tù nhân.',
      'Hoa Lo Prison was built by the French in the late 19th century; part of it is now a museum.'),
  Landmark('Bảo tàng Dân tộc học Việt Nam', 'Vietnam Museum of Ethnology', ['bao tang dan toc hoc', 'museum of ethnology'],
      'Hà Nội', 'bac', 21.0405, 105.7987,
      'Bảo tàng Dân tộc học giới thiệu đời sống của năm mươi tư dân tộc ở Việt Nam: trang phục, nhạc cụ, đồ dùng hằng ngày. '
          'Ngoài trời có vườn kiến trúc với nhà rông Tây Nguyên, nhà dài Ê Đê, nhà sàn Tày được dựng lại như thật.',
      'The Museum of Ethnology presents the life of Viet Nam\'s 54 ethnic groups, with traditional houses outdoors.'),
  Landmark('Làng gốm Bát Tràng', 'Bat Trang Ceramic Village', ['bat trang', 'lang gom bat trang', 'gom bat trang'], 'Hà Nội', 'bac', 20.9760, 105.9130,
      'Làng gốm Bát Tràng nằm bên bờ sông Hồng, phía đông nam Hà Nội, làm gốm sứ từ nhiều thế kỷ nay. '
          'Khách có thể tự tay nặn gốm trên bàn xoay, sờ thấy đất sét mềm và mát, rồi mang sản phẩm về làm kỷ niệm.',
      'Bat Trang is a centuries-old ceramic village where visitors can try the potter\'s wheel.'),
  Landmark('Thành Cổ Loa', 'Co Loa Citadel', ['co loa', 'thanh co loa', 'co loa citadel'], 'Hà Nội', 'bac', 21.1150, 105.8730,
      'Thành Cổ Loa ở phía bắc Hà Nội gắn với vua An Dương Vương, được xây khoảng thế kỷ thứ ba trước Công nguyên. '
          'Thành có nhiều vòng tường đất uốn lượn hình xoáy ốc, gắn với truyền thuyết nỏ thần và Mỵ Châu, Trọng Thủy.',
      'Co Loa Citadel, built around the 3rd century BC, has spiral earthen walls linked to the legend of the magic crossbow.'),
  Landmark('Làng cổ Đường Lâm', 'Duong Lam Ancient Village', ['duong lam', 'lang co duong lam'], 'Hà Nội', 'bac', 21.1580, 105.4740,
      'Làng cổ Đường Lâm ở Sơn Tây, phía tây Hà Nội, nổi tiếng với những ngôi nhà và tường xây bằng đá ong, cổng làng và giếng cổ. '
          'Đây là làng cổ đầu tiên của Việt Nam được xếp hạng di tích quốc gia, quê hương của hai vua Phùng Hưng và Ngô Quyền.',
      'Duong Lam is an ancient village of laterite houses, the first village in Viet Nam listed as a national heritage site.'),
  Landmark('Vườn quốc gia Ba Vì', 'Ba Vi National Park', ['nui ba vi', 'vuon quoc gia ba vi', 'dinh ba vi'], 'Hà Nội', 'bac', 21.0700, 105.3700,
      'Vườn quốc gia Ba Vì ở phía tây Hà Nội, có núi Ba Vì với đỉnh Vua cao khoảng một nghìn hai trăm chín mươi sáu mét, '
          'nơi có đền thờ Tản Viên Sơn Thánh. Trên núi mát hơn dưới đồng bằng nhiều, có rừng thông và nhiều loài cây quý.',
      'Ba Vi National Park, west of Hanoi, has cool forests and a mountain temple to the Mountain God Tan Vien.'),
  Landmark('Chùa Hương', 'Perfume Pagoda', ['chua huong', 'dong huong tich', 'perfume pagoda'], 'Hà Nội', 'bac', 20.618, 105.747,
      'Chùa Hương ở huyện Mỹ Đức cũ, phía nam Hà Nội, là quần thể chùa và hang động trong núi đá vôi. '
          'Khách thường đi đò dọc suối Yến rồi leo núi hoặc đi cáp treo lên động Hương Tích. Lễ hội chùa Hương kéo dài từ tháng Giêng đến tháng Ba âm lịch.',
      'The Perfume Pagoda is a complex of temples and caves reached by boat along the Yen stream.'),
  Landmark('Sa Pa', 'Sa Pa', ['sa pa', 'sapa'], 'Lào Cai', 'bac', 22.336, 103.844,
      'Sa Pa nằm trên núi cao khoảng một nghìn rưỡi mét, khí hậu mát mẻ quanh năm, mùa đông có thể có băng tuyết. '
          'Nơi đây nổi tiếng với ruộng bậc thang, bản làng của người Mông, người Dao đỏ, và là cửa ngõ lên đỉnh Fansipan.',
      'Sa Pa is a cool mountain town famous for rice terraces and Hmong and Red Dao villages.'),
  Landmark('Đỉnh Fansipan', 'Mount Fansipan', ['fansipan', 'phan xi pang', 'dinh fansipan', 'dinh phan xi pang'], 'Lào Cai', 'bac', 22.303, 103.775,
      'Fansipan cao 3.143 mét, là đỉnh núi cao nhất Việt Nam và cả bán đảo Đông Dương, nên được gọi là nóc nhà Đông Dương. '
          'Có thể leo bộ mất một đến hai ngày, hoặc đi cáp treo từ Sa Pa lên gần đỉnh.',
      'Fansipan, 3,143 metres high, is the highest peak in Indochina.'),
  Landmark('Mù Cang Chải', 'Mu Cang Chai', ['mu cang chai'], 'Lào Cai', 'bac', 21.85, 104.09,
      'Mù Cang Chải nổi tiếng với những thửa ruộng bậc thang uốn lượn trên sườn núi do người Mông làm nên. '
          'Đẹp nhất là mùa lúa chín vàng vào khoảng cuối tháng Chín đến đầu tháng Mười, và mùa nước đổ khoảng tháng Năm, tháng Sáu.',
      'Mu Cang Chai is famous for its mountain rice terraces, golden in late September.'),
  Landmark('Cao nguyên đá Đồng Văn', 'Dong Van Karst Plateau', ['dong van', 'cao nguyen da dong van', 'cao nguyen da'], 'Tuyên Quang', 'bac', 23.28, 105.36,
      'Cao nguyên đá Đồng Văn, thuộc vùng Hà Giang cũ, nay thuộc tỉnh Tuyên Quang, là vùng núi đá vôi hùng vĩ ở cực bắc. '
          'Đây là Công viên địa chất toàn cầu UNESCO. Gần đó có đèo Mã Pì Lèng nhìn xuống sông Nho Quế và cột cờ Lũng Cú.',
      'The Dong Van Karst Plateau in the far north is a UNESCO Global Geopark.'),
  Landmark('Đèo Mã Pì Lèng', 'Ma Pi Leng Pass', ['ma pi leng', 'deo ma pi leng'], 'Tuyên Quang', 'bac', 23.24, 105.41,
      'Mã Pì Lèng là một trong những con đèo hiểm trở và đẹp nhất Việt Nam, nối Đồng Văn với Mèo Vạc. '
          'Từ đèo nhìn xuống là hẻm vực sâu với dòng sông Nho Quế xanh ngọc chảy bên dưới.',
      'Ma Pi Leng is a dramatic mountain pass above the turquoise Nho Que river.'),
  Landmark('Cột cờ Lũng Cú', 'Lung Cu Flag Tower', ['lung cu', 'cot co lung cu'], 'Tuyên Quang', 'bac', 23.364, 105.316,
      'Cột cờ Lũng Cú đứng trên đỉnh núi Rồng, gần điểm cực Bắc của Việt Nam. Trên đỉnh cột có lá cờ đỏ sao vàng rộng 54 mét vuông, tượng trưng cho 54 dân tộc.',
      'Lung Cu Flag Tower stands near the northernmost point of Viet Nam.'),
  Landmark('Thác Bản Giốc', 'Ban Gioc Waterfall', ['ban gioc', 'thac ban gioc'], 'Cao Bằng', 'bac', 22.855, 106.723,
      'Thác Bản Giốc trên sông Quây Sơn, nằm ngay biên giới Việt Nam và Trung Quốc, là một trong những thác nước lớn và đẹp nhất Đông Nam Á. '
          'Thác chia nhiều tầng, đẹp nhất vào mùa nước từ khoảng tháng Sáu đến tháng Chín.',
      'Ban Gioc is a large multi-tiered waterfall on the Viet Nam–China border.'),
  Landmark('Hồ Ba Bể', 'Ba Be Lake', ['ho ba be', 'ba be'], 'Thái Nguyên', 'bac', 22.41, 105.62,
      'Hồ Ba Bể, thuộc vùng Bắc Kạn cũ, nay thuộc tỉnh Thái Nguyên, là hồ nước ngọt tự nhiên lớn nằm giữa núi rừng. '
          'Hồ nằm trong Vườn quốc gia Ba Bể; khách thường đi thuyền ngắm hồ, động Puông và thác Đầu Đẳng.',
      'Ba Be is a large natural freshwater lake inside a national park.'),
  Landmark('Mộc Châu', 'Moc Chau', ['moc chau', 'cao nguyen moc chau'], 'Sơn La', 'bac', 20.85, 104.63,
      'Cao nguyên Mộc Châu mát mẻ, có những đồi chè xanh mướt và các trang trại bò sữa. '
          'Mùa xuân, hoa mận, hoa mơ trắng nở khắp thung lũng; cuối năm có hoa cải trắng.',
      'Moc Chau is a cool plateau of tea hills, dairy farms and plum blossoms.'),
  Landmark('Đền Hùng', 'Hung Kings Temple', ['den hung', 'den hung vuong', 'hung kings temple'], 'Phú Thọ', 'bac', 21.37, 105.32,
      'Đền Hùng trên núi Nghĩa Lĩnh thờ các vua Hùng, những người dựng nước Văn Lang. '
          'Ngày Giỗ Tổ Hùng Vương mùng 10 tháng 3 âm lịch hằng năm là ngày lễ lớn của cả nước.',
      'The Hung Kings Temple honours the legendary founders of the nation.'),
  Landmark('Tràng An', 'Trang An', ['trang an', 'quan the trang an'], 'Ninh Bình', 'bac', 20.252, 105.897,
      'Quần thể danh thắng Tràng An gồm núi đá vôi, sông nước và nhiều hang động xuyên núi. '
          'Khách ngồi đò đi qua các hang tối rồi ra những thung lũng xanh. Tràng An là di sản thế giới hỗn hợp cả văn hóa và thiên nhiên, được công nhận năm 2014.',
      'Trang An is a UNESCO mixed heritage landscape of limestone peaks, rivers and caves explored by boat.'),
  Landmark('Tam Cốc Bích Động', 'Tam Coc', ['tam coc', 'bich dong', 'tam coc bich dong'], 'Ninh Bình', 'bac', 20.216, 105.937,
      'Tam Cốc có nghĩa là ba hang, được gọi là Hạ Long trên cạn. Khách đi đò dọc sông Ngô Đồng qua ba hang xuyên núi, hai bên là ruộng lúa và núi đá. '
          'Gần đó có chùa Bích Động nép vào vách núi.',
      'Tam Coc, the "Ha Long Bay on land", is explored by rowing boat through three caves.'),
  Landmark('Cố đô Hoa Lư', 'Hoa Lu Ancient Capital', ['hoa lu', 'co do hoa lu'], 'Ninh Bình', 'bac', 20.286, 105.907,
      'Hoa Lư là kinh đô đầu tiên của nhà nước phong kiến tập quyền Việt Nam, thời Đinh và Tiền Lê, từ năm 968 đến năm 1010, trước khi vua Lý Công Uẩn dời đô ra Thăng Long. '
          'Ngày nay còn đền thờ vua Đinh Tiên Hoàng và vua Lê Đại Hành.',
      'Hoa Lu was Viet Nam\'s capital from 968 to 1010.'),
  Landmark('Đảo Cát Bà', 'Cat Ba Island', ['cat ba', 'dao cat ba', 'vinh lan ha', 'lan ha'], 'Hải Phòng', 'bac', 20.73, 107.05,
      'Cát Bà là đảo lớn nhất trong quần đảo cùng tên ở Hải Phòng, có vườn quốc gia với rừng trên núi đá vôi. '
          'Bên cạnh là vịnh Lan Hạ yên tĩnh với nhiều bãi cát nhỏ, nối liền với vịnh Hạ Long.',
      'Cat Ba is a large island with a national park, next to quiet Lan Ha Bay.'),

  // ---------------- MIỀN TRUNG ----------------
  Landmark('Phong Nha Kẻ Bàng', 'Phong Nha-Ke Bang', ['phong nha', 'phong nha ke bang', 'dong phong nha', 'ke bang'], 'Quảng Trị', 'trung', 17.59, 106.28,
      'Vườn quốc gia Phong Nha Kẻ Bàng, thuộc vùng Quảng Bình cũ, nay thuộc tỉnh Quảng Trị, có hệ thống hang động đá vôi rất lớn và lâu đời. '
          'Nơi đây là Di sản thiên nhiên thế giới. Động Phong Nha đi bằng thuyền theo sông ngầm, động Thiên Đường dài hơn ba mươi ki-lô-mét.',
      'Phong Nha-Ke Bang National Park is a UNESCO site with vast limestone caves.'),
  Landmark('Hang Sơn Đoòng', 'Son Doong Cave', ['son doong', 'hang son doong'], 'Quảng Trị', 'trung', 17.457, 106.287,
      'Sơn Đoòng là hang động tự nhiên lớn nhất thế giới từng được biết, được đoàn thám hiểm Anh và Việt Nam khảo sát năm 2009. '
          'Trong hang có rừng cây và cả mây riêng. Mỗi năm chỉ một số ít đoàn được vào thám hiểm nhiều ngày.',
      'Son Doong is the largest known cave in the world, with its own jungle inside.'),
  Landmark('Kinh thành Huế', 'Hue Imperial City', ['kinh thanh hue', 'dai noi hue', 'dai noi', 'hoang thanh hue', 'co do hue'], 'Huế', 'trung', 16.469, 107.578,
      'Kinh thành Huế là kinh đô của triều Nguyễn, triều đại phong kiến cuối cùng của Việt Nam, từ năm 1802 đến năm 1945. '
          'Bên trong có Đại Nội với Ngọ Môn, điện Thái Hòa. Quần thể di tích Cố đô Huế là Di sản văn hóa thế giới đầu tiên của Việt Nam, năm 1993.',
      'Hue Imperial City was the capital of the Nguyen dynasty from 1802 to 1945.'),
  Landmark('Chùa Thiên Mụ', 'Thien Mu Pagoda', ['chua thien mu', 'thien mu', 'chua linh mu'], 'Huế', 'trung', 16.453, 107.545,
      'Chùa Thiên Mụ nằm trên đồi Hà Khê bên bờ sông Hương, được xây từ năm 1601. '
          'Biểu tượng của chùa là tháp Phước Duyên bảy tầng. Tiếng chuông chùa Thiên Mụ đã đi vào nhiều câu ca dao xứ Huế.',
      'Thien Mu Pagoda, built in 1601, overlooks the Perfume River.'),
  Landmark('Đèo Hải Vân', 'Hai Van Pass', ['hai van', 'deo hai van'], 'Đà Nẵng', 'trung', 16.19, 108.13,
      'Đèo Hải Vân nằm giữa Huế và Đà Nẵng, một bên là núi, một bên là biển, đỉnh đèo thường có mây phủ. '
          'Đèo được mệnh danh là thiên hạ đệ nhất hùng quan. Ngày nay xe có thể đi hầm Hải Vân xuyên núi.',
      'Hai Van Pass, between Hue and Da Nang, winds between mountains and sea.'),
  Landmark('Bà Nà Hills', 'Ba Na Hills', ['ba na', 'ba na hills', 'cau vang', 'nui ba na'], 'Đà Nẵng', 'trung', 15.995, 107.996,
      'Bà Nà là khu nghỉ trên núi cao khoảng một nghìn bốn trăm mét ở Đà Nẵng, khí hậu mát, có thể đi cáp treo lên. '
          'Nổi tiếng nhất là Cầu Vàng, cây cầu như được hai bàn tay đá khổng lồ nâng lên giữa mây.',
      'Ba Na Hills is a mountain resort known for the Golden Bridge held up by giant stone hands.'),
  Landmark('Ngũ Hành Sơn', 'Marble Mountains', ['ngu hanh son', 'marble mountains', 'non nuoc'], 'Đà Nẵng', 'trung', 16.003, 108.263,
      'Ngũ Hành Sơn gồm năm ngọn núi đá vôi mang tên Kim, Mộc, Thủy, Hỏa, Thổ, gần biển Non Nước. '
          'Trong núi có nhiều hang động và chùa; dưới chân núi có làng đá mỹ nghệ Non Nước.',
      'The Marble Mountains are five limestone hills with caves and pagodas.'),
  Landmark('Bán đảo Sơn Trà', 'Son Tra Peninsula', ['son tra', 'ban dao son tra', 'chua linh ung'], 'Đà Nẵng', 'trung', 16.12, 108.28,
      'Bán đảo Sơn Trà ôm lấy vịnh Đà Nẵng, có rừng nguyên sinh là nhà của loài voọc chà vá chân nâu quý hiếm. '
          'Trên bán đảo có chùa Linh Ứng với tượng Phật Bà Quan Âm cao nhìn ra biển.',
      'Son Tra Peninsula is home to rare red-shanked douc langurs.'),
  Landmark('Phố cổ Hội An', 'Hoi An Ancient Town', ['hoi an', 'pho co hoi an', 'chua cau'], 'Đà Nẵng', 'trung', 15.877, 108.326,
      'Phố cổ Hội An, thuộc vùng Quảng Nam cũ, nay thuộc thành phố Đà Nẵng, từng là thương cảng sầm uất từ thế kỷ 16, 17. '
          'Phố có những ngôi nhà mái ngói vàng, Chùa Cầu Nhật Bản và đêm rằm thả đèn hoa đăng trên sông Hoài. Hội An là Di sản văn hóa thế giới từ năm 1999.',
      'Hoi An is a well-preserved old trading port and a UNESCO World Heritage Site.'),
  Landmark('Thánh địa Mỹ Sơn', 'My Son Sanctuary', ['my son', 'thanh dia my son'], 'Đà Nẵng', 'trung', 15.764, 108.124,
      'Mỹ Sơn là quần thể đền tháp của vương quốc Chăm Pa, được xây trong nhiều thế kỷ, nằm trong một thung lũng giữa núi. '
          'Các tháp gạch đỏ được ghép rất khéo, đến nay người ta vẫn tìm hiểu cách xây. Mỹ Sơn là Di sản văn hóa thế giới từ năm 1999.',
      'My Son is a valley of ancient Cham brick temples, a UNESCO site.'),
  Landmark('Đảo Lý Sơn', 'Ly Son Island', ['ly son', 'dao ly son'], 'Quảng Ngãi', 'trung', 15.38, 109.12,
      'Lý Sơn là hòn đảo hình thành từ núi lửa cổ, có cổng Tò Vò và đỉnh Thới Lới. '
          'Đảo nổi tiếng với những cánh đồng tỏi trồng trên cát và lớp đá núi lửa.',
      'Ly Son is a volcanic island known for its garlic fields.'),
  Landmark('Kỳ Co Eo Gió', 'Ky Co and Eo Gio', ['ky co', 'eo gio', 'ky co eo gio'], 'Gia Lai', 'trung', 13.85, 109.29,
      'Kỳ Co và Eo Gió ở bán đảo Phương Mai, vùng Quy Nhơn, thuộc Bình Định cũ, nay thuộc tỉnh Gia Lai. '
          'Kỳ Co có bãi cát trắng, nước biển trong xanh; Eo Gió là eo biển gió lộng với đường đi bộ ven vách đá.',
      'Ky Co beach and Eo Gio strait near Quy Nhon have clear water and dramatic cliffs.'),
  Landmark('Gành Đá Đĩa', 'Ganh Da Dia', ['ganh da dia'], 'Đắk Lắk', 'trung', 13.36, 109.29,
      'Gành Đá Đĩa ở vùng Phú Yên cũ, nay thuộc tỉnh Đắk Lắk, là bãi đá ven biển gồm hàng nghìn cột đá bazan xếp sát nhau như những chồng đĩa. '
          'Các cột đá hình thành khi dung nham núi lửa nguội đi rất lâu về trước.',
      'Ganh Da Dia is a coastal field of basalt columns stacked like plates.'),
  Landmark('Vịnh Nha Trang', 'Nha Trang Bay', ['nha trang', 'vinh nha trang', 'hon mun'], 'Khánh Hòa', 'trung', 12.23, 109.22,
      'Vịnh Nha Trang có bờ biển dài, cát trắng và nhiều đảo như Hòn Tre, Hòn Mun với rạn san hô để lặn ngắm. '
          'Thành phố biển này nắng nhiều quanh năm, mùa mưa chủ yếu vào khoảng tháng Mười đến tháng Mười hai.',
      'Nha Trang Bay has long beaches, islands and coral reefs.'),
  Landmark('Tháp Bà Ponagar', 'Po Nagar Towers', ['thap ba', 'ponagar', 'thap ba ponagar', 'po nagar'], 'Khánh Hòa', 'trung', 12.265, 109.195,
      'Tháp Bà Ponagar là cụm tháp Chăm cổ trên đồi bên cửa sông Cái, Nha Trang, thờ Nữ thần mẹ xứ sở. '
          'Lễ hội Tháp Bà diễn ra vào tháng Ba âm lịch hằng năm.',
      'The Po Nagar Towers are ancient Cham temples in Nha Trang.'),
  Landmark('Mũi Né', 'Mui Ne', ['mui ne', 'doi cat mui ne', 'doi cat bay'], 'Lâm Đồng', 'trung', 10.93, 108.29,
      'Mũi Né, vùng Phan Thiết thuộc Bình Thuận cũ, nay thuộc tỉnh Lâm Đồng, nổi tiếng với đồi cát bay, đồi cát trắng và suối Tiên. '
          'Gió biển mạnh nên nơi đây là điểm lướt ván diều được nhiều người yêu thích.',
      'Mui Ne is known for its sand dunes and kitesurfing.'),

  // ---------------- TÂY NGUYÊN ----------------
  Landmark('Đà Lạt', 'Da Lat', ['da lat', 'ho xuan huong', 'thanh pho da lat'], 'Lâm Đồng', 'taynguyen', 11.941, 108.444,
      'Đà Lạt nằm trên cao nguyên Lâm Viên, cao khoảng một nghìn rưỡi mét, mát mẻ quanh năm nên được gọi là thành phố ngàn hoa. '
          'Giữa thành phố có hồ Xuân Hương; xung quanh là đồi thông, vườn hoa, vườn dâu và nhiều thác nước.',
      'Da Lat is a cool highland city of pine hills and flowers.'),
  Landmark('Biển Hồ Pleiku', 'Bien Ho Lake', ['bien ho', 'bien ho pleiku', 'ho to nung', 'to nung'], 'Gia Lai', 'taynguyen', 14.05, 108.0,
      'Biển Hồ, còn gọi là hồ Tơ Nưng, nằm gần Pleiku, là hồ nước hình thành trên miệng núi lửa đã tắt. '
          'Mặt hồ rộng, nước trong xanh, được ví như đôi mắt của phố núi Pleiku.',
      'Bien Ho near Pleiku is a lake in an old volcanic crater.'),
  Landmark('Buôn Đôn', 'Buon Don', ['buon don'], 'Đắk Lắk', 'taynguyen', 12.90, 107.78,
      'Buôn Đôn gắn với nghề săn và thuần dưỡng voi rừng lâu đời của đồng bào Tây Nguyên. '
          'Nơi đây có những cây cầu treo bắc qua sông Sêrêpốk và Vườn quốc gia Yok Đôn.',
      'Buon Don is known for its elephant heritage and suspension bridges.'),
  Landmark('Thác Dray Nur', 'Dray Nur Falls', ['dray nur', 'thac dray nur', 'thac dray sap', 'dray sap'], 'Đắk Lắk', 'taynguyen', 12.54, 107.89,
      'Thác Dray Nur và thác Dray Sáp trên sông Sêrêpốk là những thác nước hùng vĩ của Tây Nguyên. '
          'Dray Nur có màn nước rộng đổ xuống vách đá bazan, gắn với truyền thuyết tình yêu của người Ê Đê.',
      'Dray Nur is a wide waterfall on the Serepok river.'),

  // ---------------- MIỀN NAM ----------------
  Landmark('Dinh Độc Lập', 'Independence Palace', ['dinh doc lap', 'hoi truong thong nhat', 'independence palace'], 'TP. Hồ Chí Minh', 'nam', 10.777, 106.695,
      'Dinh Độc Lập, còn gọi là Hội trường Thống Nhất, ở trung tâm Thành phố Hồ Chí Minh. '
          'Trưa ngày 30 tháng 4 năm 1975, xe tăng húc đổ cổng dinh, đánh dấu ngày thống nhất đất nước.',
      'The Independence Palace marks the reunification of Viet Nam on 30 April 1975.'),
  Landmark('Nhà thờ Đức Bà', 'Notre-Dame Cathedral Basilica of Saigon', ['nha tho duc ba', 'buu dien thanh pho', 'buu dien sai gon'],
      'TP. Hồ Chí Minh', 'nam', 10.7798, 106.699,
      'Nhà thờ Đức Bà Sài Gòn được người Pháp xây cuối thế kỷ 19 bằng gạch đỏ mang từ Pháp sang, có hai tháp chuông cao. '
          'Ngay bên cạnh là Bưu điện Thành phố với mái vòm và kiến trúc cổ.',
      'Saigon\'s red-brick Notre-Dame Cathedral stands beside the old Central Post Office.'),
  Landmark('Chợ Bến Thành', 'Ben Thanh Market', ['cho ben thanh', 'ben thanh'], 'TP. Hồ Chí Minh', 'nam', 10.7725, 106.698,
      'Chợ Bến Thành là ngôi chợ lâu đời, biểu tượng của Sài Gòn, với cổng có tháp đồng hồ ở cửa nam. '
          'Trong chợ bán đủ thứ, từ vải vóc, đồ lưu niệm đến các món ăn Nam Bộ.',
      'Ben Thanh Market is Saigon\'s iconic old market with a clock tower.'),
  Landmark('Địa đạo Củ Chi', 'Cu Chi Tunnels', ['dia dao cu chi', 'cu chi'], 'TP. Hồ Chí Minh', 'nam', 11.141, 106.462,
      'Địa đạo Củ Chi là hệ thống đường hầm dài hơn hai trăm ki-lô-mét được đào bằng tay trong thời kháng chiến. '
          'Dưới lòng đất có nơi ở, bếp, kho và hầm chỉ huy; du khách có thể chui thử một đoạn hầm.',
      'The Cu Chi Tunnels are over 200 km of hand-dug wartime tunnels.'),
  Landmark('Vũng Tàu', 'Vung Tau', ['vung tau', 'tuong chua kito', 'tuong chua kito vua', 'bai sau'], 'TP. Hồ Chí Minh', 'nam', 10.346, 107.084,
      'Vũng Tàu, thuộc Bà Rịa Vũng Tàu cũ, nay thuộc Thành phố Hồ Chí Minh, là thành phố biển gần Sài Gòn với Bãi Trước, Bãi Sau. '
          'Trên núi Nhỏ có tượng Chúa Kitô Vua dang tay nhìn ra biển, và ngọn hải đăng cổ.',
      'Vung Tau is a seaside city near Saigon with a giant statue of Christ on Small Mountain.'),
  Landmark('Côn Đảo', 'Con Dao', ['con dao', 'nha tu con dao'], 'TP. Hồ Chí Minh', 'nam', 8.68, 106.61,
      'Côn Đảo là quần đảo ngoài khơi phía nam, có vườn quốc gia với rừng, rạn san hô và bãi biển nơi rùa biển lên đẻ trứng. '
          'Nơi đây từng là nhà tù khắc nghiệt thời Pháp và Mỹ, nay là khu di tích lịch sử.',
      'Con Dao is an island group with a national park, nesting sea turtles and a former prison.'),
  Landmark('Núi Bà Đen', 'Ba Den Mountain', ['nui ba den', 'ba den'], 'Tây Ninh', 'nam', 11.38, 106.17,
      'Núi Bà Đen cao gần một nghìn mét, là ngọn núi cao nhất Nam Bộ. '
          'Trên núi có quần thể chùa Bà và tượng Phật Bà trên đỉnh, có cáp treo lên núi.',
      'Ba Den is the highest mountain in southern Viet Nam.'),
  Landmark('Chợ nổi Cái Răng', 'Cai Rang Floating Market', ['cho noi cai rang', 'cai rang', 'cho noi'], 'Cần Thơ', 'nam', 10.004, 105.782,
      'Chợ nổi Cái Răng họp trên sông từ sáng sớm, ghe thuyền chở đầy trái cây, rau củ của miền Tây. '
          'Mỗi ghe treo hàng mình bán lên một cây sào gọi là cây bẹo để khách nhìn từ xa.',
      'Cai Rang is a floating market on the river, busiest at dawn.'),
  Landmark('Rừng tràm Trà Sư', 'Tra Su Cajuput Forest', ['tra su', 'rung tram tra su'], 'An Giang', 'nam', 10.58, 105.06,
      'Rừng tràm Trà Sư là khu rừng ngập nước đặc trưng của miền Tây, mặt nước phủ bèo xanh. '
          'Khách đi xuồng len giữa hàng tràm, nghe tiếng chim và cò.',
      'Tra Su is a flooded cajuput forest explored by small boat.'),
  Landmark('Miếu Bà Chúa Xứ Núi Sam', 'Ba Chua Xu Temple', ['mieu ba chua xu', 'ba chua xu', 'nui sam'], 'An Giang', 'nam', 10.68, 105.08,
      'Miếu Bà Chúa Xứ ở chân núi Sam, gần Châu Đốc, là nơi hành hương rất đông người. '
          'Lễ vía Bà diễn ra vào khoảng cuối tháng Tư âm lịch hằng năm.',
      'Ba Chua Xu Temple near Chau Doc is a major pilgrimage site.'),
  Landmark('Đảo Phú Quốc', 'Phu Quoc Island', ['phu quoc', 'dao phu quoc'], 'An Giang', 'nam', 10.22, 103.96,
      'Phú Quốc là hòn đảo lớn nhất Việt Nam, thuộc Kiên Giang cũ, nay thuộc tỉnh An Giang. '
          'Đảo có những bãi biển đẹp như Bãi Sao, có rừng nguyên sinh, cáp treo vượt biển ra Hòn Thơm và nổi tiếng với nước mắm, hồ tiêu.',
      'Phu Quoc is Viet Nam\'s largest island, known for beaches and fish sauce.'),
  Landmark('Mũi Cà Mau', 'Ca Mau Cape', ['mui ca mau', 'dat mui'], 'Cà Mau', 'nam', 8.62, 104.72,
      'Mũi Cà Mau là điểm cực Nam trên đất liền của Việt Nam, nơi có cột mốc tọa độ và biểu tượng con thuyền. '
          'Xung quanh là rừng đước, rừng mắm ngập mặn; bãi bồi ở đây mỗi năm lấn ra biển thêm.',
      'Ca Mau Cape is the southernmost point of mainland Viet Nam.'),
];

// ---------------- tìm kiếm ----------------

/// Địa danh được nhắc trong câu (khớp nguyên cụm, ưu tiên cụm dài nhất).
Landmark? landmarkIn(String text) {
  final t = ' ${normVi(text)} ';
  Landmark? best;
  var len = 0;
  for (final l in vnLandmarks) {
    for (final a in l.aliases) {
      if (a.length > len && t.contains(' $a ')) {
        best = l;
        len = a.length;
      }
    }
  }
  return best;
}

/// Vùng được nhắc trong câu: 'bac' | 'trung' | 'taynguyen' | 'nam', hoặc null.
String? regionIn(String text) {
  final t = ' ${normVi(text)} ';
  if (RegExp(r' (tay nguyen|central highlands) ').hasMatch(t)) return 'taynguyen';
  if (RegExp(r' (mien bac|bac bo|tay bac|dong bac|dong bang song hong|northern|north) ').hasMatch(t)) return 'bac';
  if (RegExp(r' (mien trung|trung bo|bac trung bo|nam trung bo|duyen hai mien trung|central) ').hasMatch(t)) return 'trung';
  if (RegExp(r' (mien nam|nam bo|mien tay|dong nam bo|tay nam bo|dong bang song cuu long|southern|south|mekong) ').hasMatch(t)) return 'nam';
  return null;
}

const _cityToProvince = <String, String>{
  'da lat': 'Lâm Đồng',
  'lam dong': 'Lâm Đồng',
  'phan thiet': 'Lâm Đồng',
  'binh thuan': 'Lâm Đồng',
  'vung tau': 'TP. Hồ Chí Minh',
  'ba ria': 'TP. Hồ Chí Minh',
  'sai gon': 'TP. Hồ Chí Minh',
  'ho chi minh': 'TP. Hồ Chí Minh',
  'tphcm': 'TP. Hồ Chí Minh',
  'ha noi': 'Hà Nội',
  'sa pa': 'Lào Cai',
  'sapa': 'Lào Cai',
  'lao cai': 'Lào Cai',
  'yen bai': 'Lào Cai',
  'nha trang': 'Khánh Hòa',
  'khanh hoa': 'Khánh Hòa',
  'hoi an': 'Đà Nẵng',
  'quang nam': 'Đà Nẵng',
  'da nang': 'Đà Nẵng',
  'hue': 'Huế',
  'thua thien hue': 'Huế',
  'phu quoc': 'An Giang',
  'kien giang': 'An Giang',
  'can tho': 'Cần Thơ',
  'quy nhon': 'Gia Lai',
  'binh dinh': 'Gia Lai',
  'pleiku': 'Gia Lai',
  'gia lai': 'Gia Lai',
  'buon ma thuot': 'Đắk Lắk',
  'dak lak': 'Đắk Lắk',
  'phu yen': 'Đắk Lắk',
  'tuy hoa': 'Đắk Lắk',
  'quang binh': 'Quảng Trị',
  'dong hoi': 'Quảng Trị',
  'quang tri': 'Quảng Trị',
  'ha giang': 'Tuyên Quang',
  'tuyen quang': 'Tuyên Quang',
  'bac kan': 'Thái Nguyên',
  'thai nguyen': 'Thái Nguyên',
  'quang ninh': 'Quảng Ninh',
  'ha long': 'Quảng Ninh',
  'ninh binh': 'Ninh Bình',
  'tay ninh': 'Tây Ninh',
};

/// Các địa danh của một tỉnh nhắc trong câu ("ở Quảng Ninh có gì"), rỗng nếu không có.
List<Landmark> landmarksOfProvinceIn(String text) {
  final t = ' ${normVi(text)} ';
  final hits = <String, List<Landmark>>{};
  for (final l in vnLandmarks) {
    final p = normVi(l.province.replaceAll('TP. ', ''));
    if (t.contains(' $p ')) (hits[p] ??= []).add(l);
  }
  for (final e in _cityToProvince.entries) {
    if (t.contains(' ${e.key} ')) {
      final pNorm = normVi(e.value.replaceAll('TP. ', ''));
      final ls = [for (final l in vnLandmarks) if (l.province == e.value) l];
      if (ls.isNotEmpty) hits[pNorm] = ls;
    }
  }
  if (hits.isEmpty) return const [];
  // tên tỉnh dài nhất (vd "ho chi minh" thay vì "ho")
  final k = hits.keys.reduce((a, b) => a.length >= b.length ? a : b);
  return hits[k]!;
}

/// Các địa danh trong vòng [km] quanh điểm (lat, lon), gần trước — cho "quanh đây có gì".
List<(Landmark, double)> landmarksNear(double lat, double lon, {double km = 3}) {
  final k = math.cos(lat * math.pi / 180);
  final out = <(Landmark, double)>[];
  for (final l in vnLandmarks) {
    final dy = (l.lat - lat) * 111.2, dx = (l.lon - lon) * 111.2 * k;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d <= km) out.add((l, d));
  }
  out.sort((a, b) => a.$2.compareTo(b.$2));
  return out;
}

/// Câu "gần đây có …" kèm khoảng cách dễ nghe; rỗng nếu không có địa danh nào gần.
(String, String) nearbyLandmarksText(double lat, double lon, {double km = 3, int max = 5}) {
  final ls = landmarksNear(lat, lon, km: km).take(max).toList();
  if (ls.isEmpty) return ('', '');
  String dist(double d) => d < 0.15
      ? 'ngay đây'
      : d < 1
          ? 'cách khoảng ${((d * 1000) / 100).round() * 100} mét'
          : 'cách khoảng ${d.toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} cây số';
  return (
    'Địa danh gần đây: ${ls.map((x) => '${x.$1.name}, ${dist(x.$2)}').join('; ')}. Muốn nghe kể về nơi nào, nói ví dụ: kể về ${ls.first.$1.name}.',
    'Nearby: ${ls.map((x) => x.$1.en).join(', ')}.'
  );
}

List<Landmark> landmarksOfRegion(String region) => [for (final l in vnLandmarks) if (l.region == region) l];

/// "Vịnh Hạ Long, Quảng Ninh" — tên kèm tỉnh (không lặp nếu tên đã có tên tỉnh).
String landmarkPlaceVi(Landmark l) =>
    normVi(l.name).contains(normVi(l.province.replaceAll('TP. ', ''))) ? l.name : '${l.name}, ${l.province}';

/// Câu kể tên các địa danh nổi bật của một vùng / tỉnh.
(String, String) landmarkListText(String titleVi, String titleEn, List<Landmark> ls) {
  final names = ls.map((l) => l.name).toList();
  final namesEn = ls.map((l) => l.en).toList();
  String join(List<String> xs, String and) =>
      xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} $and ${xs.last}';
  return (
    '$titleVi có các địa danh nổi bật: ${join(names, 'và')}. Bạn muốn nghe về nơi nào? Ví dụ nói: kể về ${names.first}.',
    'Notable places in $titleEn: ${join(namesEn, 'and')}. Which one would you like to hear about?'
  );
}

/// Tổng quan khi hỏi chung "Việt Nam có địa danh gì nổi tiếng".
(String, String) landmarkOverviewText() {
  String pick(String r) => landmarksOfRegion(r).take(3).map((l) => l.name).join(', ');
  return (
    'Mình có giới thiệu về ${vnLandmarks.length} địa danh nổi bật khắp Việt Nam. '
        'Miền Bắc có ${pick('bac')}. Miền Trung có ${pick('trung')}. Tây Nguyên có ${pick('taynguyen')}. Miền Nam có ${pick('nam')}. '
        'Bạn hỏi theo vùng, ví dụ: miền Trung có địa danh gì nổi tiếng, hoặc hỏi thẳng: kể về Vịnh Hạ Long.',
    'I know ${vnLandmarks.length} notable places across Viet Nam. Ask by region, for example: famous places in Central Viet Nam, '
        'or ask directly: tell me about Ha Long Bay.'
  );
}

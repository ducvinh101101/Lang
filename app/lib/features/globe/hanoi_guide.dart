// CẨM NANG ĐỊA ĐIỂM ĂN UỐNG, VUI CHƠI, DU LỊCH QUANH HÀ NỘI (theo từng xã, phường, khu vực).
// Phục vụ phần "Địa lý quanh bạn" và các câu hỏi tự nhiên:
//  • "quanh đây có gì", "quanh phường Hoàn Kiếm có gì"
//  • "ở phường Tây Hồ có địa điểm ăn uống vui chơi gì không"
//  • "xã Gia Lâm có gì chơi", "phường Bách Khoa ăn gì ngon", "xã Bát Tràng có địa điểm du lịch gì"
// Hoạt động hoàn toàn offline cho toàn bộ xã, phường thuộc Hà Nội (khớp theo tên xã/phường hoặc toạ độ gần nhất).
import 'dart:math' as math;

import '../voice/commands.dart' show normVi;

/// BẬT / TẮT phần QUÁN ĂN – CHỖ Ở tại Hà Nội (dữ liệu assets/data/hanoi_places.json và mục ăn uống, lưu trú
/// trong cẩm nang theo khu). Đang TẮT (ẩn): app chỉ kể chỗ tham quan, vui chơi; hỏi quán ăn / khách sạn thì nói
/// ngắn là phần này tạm ẩn. Đổi thành true để bật lại — dữ liệu và mã vẫn giữ nguyên.
const bool kHanoiFoodStayEnabled = false;

class HanoiZone {
  final String id;
  final String titleVi;
  final String titleEn;
  final double lat, lon;
  final List<String> keywords; // tên xã, phường, quận/huyện, địa danh đã bỏ dấu
  final String tourVi, tourEn; // địa điểm tham quan, du lịch
  final String funVi, funEn; // địa điểm vui chơi, giải trí, dạo mát
  final String foodVi, foodEn; // địa điểm ăn uống, ẩm thực, đặc sản
  final String stayVi, stayEn; // địa điểm lưu trú, khách sạn, homestay, resort

  String get nameVi => titleVi;
  String get nameEn => titleEn;

  const HanoiZone({
    required this.id,
    required this.titleVi,
    required this.titleEn,
    required this.lat,
    required this.lon,
    required this.keywords,
    required this.tourVi,
    required this.tourEn,
    required this.funVi,
    required this.funEn,
    required this.foodVi,
    required this.foodEn,
    required this.stayVi,
    required this.stayEn,
  });
}

const hanoiZones = <HanoiZone>[
  HanoiZone(
    id: 'hoan_kiem',
    titleVi: 'khu vực Hoàn Kiếm – Phố Cổ',
    titleEn: 'Hoan Kiem and Old Quarter area',
    lat: 21.0288,
    lon: 105.8525,
    keywords: [
      'hoan kiem', 'cua nam', 'hang bac', 'hang dao', 'hang gai', 'hang buom', 'hang bo',
      'hang ma', 'hang bong', 'hang trong', 'trang tien', 'ly thai to', 'phan chu trinh',
      'tran hung dao', 'cua dong', 'dong xuan', 'chuong duong', 'phuc tan', 'ho guom', 'pho co',
    ],
    tourVi: 'Về du lịch tham quan: có Hồ Hoàn Kiếm, đền Ngọc Sơn, cầu Thê Húc, khu Phố cổ 36 phố phường, Nhà hát Lớn Hà Nội, di tích Nhà tù Hỏa Lò và chợ Đồng Xuân.',
    tourEn: 'For sightseeing: Hoan Kiem Lake, Ngoc Son Temple, the 36 streets of the Old Quarter, Hanoi Opera House, Hoa Lo Prison, and Dong Xuan Market.',
    funVi: 'Về vui chơi giải trí: cuối tuần có không gian phố đi bộ quanh Hồ Gươm rất nhộn nhịp, phố đêm Tạ Hiện – Lương Ngọc Quyến, phố sách Đinh Lễ và xem múa rối nước Thăng Long.',
    funEn: 'For entertainment: the weekend walking street around Hoan Kiem Lake, Ta Hien night street, Dinh Le book street, and Thang Long water puppet theatre.',
    foodVi: 'Về ăn uống: nổi tiếng với phở Bát Đàn, phở Thìn Bờ Hồ, bún chả Hàng Mành, chả cá Lã Vọng, bún thang Cầu Gỗ, cà phê trứng Giảng, kem Tràng Tiền và nộm bò khô Hồ Hoàn Kiếm.',
    foodEn: 'For food and dining: Bat Dan pho, Hang Manh bun cha, La Vong grilled fish, Giang egg coffee, and Trang Tien ice cream.',
    stayVi: 'Về lưu trú: đa dạng từ khách sạn lịch sử 5 sao đẳng cấp thế giới như Sofitel Legend Metropole, Apricot Hotel view Hồ Gươm, đến các khách sạn boutique phố cổ như La Siesta, Silk Path và hệ thống hostel tiện lợi.',
    stayEn: 'For accommodation: ranging from historic 5-star icons like Sofitel Legend Metropole and Apricot Hotel overlooking the lake, to charming boutique hotels like La Siesta and cozy hostels.',
  ),
  HanoiZone(
    id: 'ba_dinh',
    titleVi: 'khu vực Ba Đình – Lăng Bác',
    titleEn: 'Ba Dinh area',
    lat: 21.0353,
    lon: 105.8360,
    keywords: [
      'ba dinh', 'ngoc ha', 'giang vo', 'doi can', 'dien bien', 'quan thanh', 'truc bach',
      'kim ma', 'lieu giai', 'cong vi', 'vinh phuc', 'thanh cong', 'nguyen trung truc', 'lang bac',
    ],
    tourVi: 'Về du lịch tham quan: có Lăng Chủ tịch Hồ Chí Minh, Quảng trường Ba Đình, Chùa Một Cột, Hoàng thành Thăng Long, đền Quán Thánh và Cột cờ Hà Nội.',
    tourEn: 'For sightseeing: Ho Chi Minh Mausoleum, Ba Dinh Square, One Pillar Pagoda, Imperial Citadel of Thang Long, and Quan Thanh Temple.',
    funVi: 'Về vui chơi dạo mát: tản bộ dưới hàng sấu cổ thụ trên đường Phan Đình Phùng, dạo công viên Bách Thảo, hoặc hóng gió quanh hồ Trúc Bạch và hồ Giảng Võ.',
    funEn: 'For leisure: strolling along tree-lined Phan Dinh Phung street, Bach Thao Park, and Truc Bach Lake.',
    foodVi: 'Về ăn uống: có phở cuốn và phở chiên phồng Ngũ Xã bên hồ Trúc Bạch, bánh tôm Hồ Tây, bún ốc Đội Cấn, cháo sườn Phan Đình Phùng và các quán ẩm thực quanh hồ Giảng Võ.',
    foodEn: 'For dining: Ngu Xa fresh pho rolls by Truc Bach Lake, West Lake shrimp cakes, and Doi Can snail noodles.',
    stayVi: 'Về lưu trú: nổi bật với khách sạn 5 sao Lotte Hotel Hanoi trên đường Liễu Giai có đài quan sát ngắm toàn thành phố, khách sạn Hà Nội bên hồ Giảng Võ, cùng nhiều căn hộ dịch vụ cao cấp quanh khu Ngoại giao đoàn.',
    stayEn: 'For accommodation: prominent 5-star Lotte Hotel Hanoi on Lieu Giai with sky observation deck, Hanoi Hotel by Giang Vo lake, and peaceful serviced residences.',
  ),
  HanoiZone(
    id: 'tay_ho',
    titleVi: 'khu vực Tây Hồ',
    titleEn: 'West Lake (Tay Ho) area',
    lat: 21.0620,
    lon: 105.8220,
    keywords: [
      'tay ho', 'phu thuong', 'nhat tan', 'quang an', 'tu lien', 'yen phu', 'thuy khue',
      'phuong buoi', 'cho buoi', 'xuan la', 'ho tay', 'trich sai', 'nguyen dinh thi', 'thanh nien',
    ],
    tourVi: 'Về du lịch tham quan: có Hồ Tây rộng lớn, chùa Trấn Quốc cổ kính, phủ Tây Hồ, làng hoa Nhật Tân và làng đào cổ Phú Thượng.',
    tourEn: 'For sightseeing: West Lake, ancient Tran Quoc Pagoda, Tay Ho Palace, Nhat Tan flower village, and Phu Thuong peach village.',
    funVi: 'Về vui chơi giải trí: đạp xe và ngắm hoàng hôn dọc đường Thanh Niên – Trích Sài, chèo thuyền SUP trên Hồ Tây, vui chơi ở công viên nước Hồ Tây và thung lũng hoa Hồ Tây.',
    funEn: 'For leisure: cycling and watching the sunset along West Lake, paddleboarding, West Lake Water Park, and West Lake Flower Valley.',
    foodVi: 'Về ăn uống: nổi tiếng với bánh tôm Hồ Tây, bún ốc phủ Tây Hồ, xôi Phú Thượng dẻo thơm, trà ướp sen Quảng An và dãy quán cà phê lộng gió ven hồ đường Nguyễn Đình Thi.',
    foodEn: 'For food: West Lake crispy shrimp cakes, Tay Ho snail noodles, Phu Thuong sticky rice, lotus tea, and lakeside cafes.',
    stayVi: 'Về lưu trú: tập trung các khách sạn 5 sao sang trọng bậc nhất ngắm hoàng hôn Hồ Tây như InterContinental Hanoi Westlake (khách sạn nổi trên mặt nước), Sheraton Hanoi, Pan Pacific (đường Thanh Niên), cùng hàng trăm homestay ven hồ view tuyệt đẹp.',
    stayEn: 'For accommodation: premium 5-star lakefront retreats such as InterContinental Westlake (overwater pavilion), Sheraton Hanoi, Pan Pacific, along with scenic serviced apartments.',
  ),
  HanoiZone(
    id: 'dong_da',
    titleVi: 'khu vực Đống Đa – Văn Miếu',
    titleEn: 'Dong Da and Temple of Literature area',
    lat: 21.0180,
    lon: 105.8310,
    keywords: [
      'dong da', 'van mieu', 'quoc tu giam', 'kim lien', 'phuong lang', 'chua lang', 'lang thuong', 'lang ha',
      'o cho dua', 'kham thien', 'trung tu', 'quang trung', 'nam dong', 'phuong mai',
      'trung liet', 'thinh quang', 'cat linh', 'hang bot', 'van chuong', 'nga tu so',
    ],
    tourVi: 'Về du lịch tham quan: có Văn Miếu – Quốc Tử Giám (trường đại học đầu tiên của Việt Nam), di tích Gò Đống Đa với tượng đài vua Quang Trung, chùa Láng và chùa Phúc Khánh.',
    tourEn: 'For sightseeing: the Temple of Literature, Dong Da Mound (King Quang Trung monument), and Lang Pagoda.',
    funVi: 'Về vui chơi giải trí: trải nghiệm tour đêm Văn Miếu "Tinh hoa đạo học", đi dạo quanh hồ Hoàng Cầu – hồ Xã Đàn, hoặc mua sắm nhộn nhịp tại phố Chùa Bộc – Phạm Ngọc Thạch.',
    funEn: 'For entertainment: the Temple of Literature night tour, walking around Hoang Cau and Xa Dan lakes, and shopping along Chua Boc street.',
    foodVi: 'Về ăn uống: rất phong phú với bún chả Sinh Từ, miến lươn Đông Thịnh, cháo trai và ốc luộc khu tập thể Kim Liên – Trung Tự, cùng phố ẩm thực sinh viên Chùa Láng và ngõ Tự Do.',
    foodEn: 'For food: Sinh Tu bun cha, eel glass noodles, Kim Lien street snacks, and vibrant student food alleys along Chua Lang.',
    stayVi: 'Về lưu trú: có khách sạn 4 sao Mercure Hanoi La Gare gần ga Hà Nội, khách sạn Pullman Hanoi trên đường Cát Linh, khách sạn Bảo Sơn trên đường Nguyễn Chí Thanh và nhiều homestay xinh xắn quanh khu Chùa Láng, Đặng Văn Ngữ.',
    stayEn: 'For accommodation: 4-star Mercure Hanoi La Gare near the railway station, Pullman Hanoi on Cat Linh, Bao Son Hotel, and vibrant boutique homestays.',
  ),
  HanoiZone(
    id: 'hai_ba_trung',
    titleVi: 'khu vực Hai Bà Trưng – Bách Khoa',
    titleEn: 'Hai Ba Trung and Bach Khoa area',
    lat: 21.0065,
    lon: 105.8475,
    keywords: [
      'hai ba trung', 'bach mai', 'vinh tuy', 'bach khoa', 'pho hue', 'nguyen du', 'le dai hanh',
      'bui thi xuan', 'ngo thi nham', 'dong nhan', 'bach dang', 'thanh nhan', 'quynh mai',
      'quynh loi', 'minh khai', 'truong dinh', 'dong tam', 'cau den', 'thien quang', 'times city',
    ],
    tourVi: 'Về du lịch tham quan: có công viên Thống Nhất bên hồ Bảy Mẫu, hồ Thiền Quang, cụm di tích đền Hai Bà Trưng (hồ Đồng Nhân) và chợ Hôm – Đức Viên.',
    tourEn: 'For sightseeing: Thong Nhat Park, Thien Quang Lake, Hai Ba Trung Temple, and Hom Market.',
    funVi: 'Về vui chơi giải trí: dạo phố đi bộ Trần Nhân Tông quanh công viên Thống Nhất, công viên Tuổi Trẻ (Thanh Nhàn), hoặc tham quan thủy cung VinKE & Aquarium tại khu đô thị Times City (Vĩnh Tuy).',
    funEn: 'For entertainment: Tran Nhan Tong walking street by Thong Nhat Park, and the aquarium and shopping mall at Times City (Vinh Tuy).',
    foodVi: 'Về ăn uống: nổi tiếng với thiên đường quà vặt khu Bách Khoa – Tạ Quang Bửu (bánh mì chảo, chè, bún đậu), bánh đúc nóng Lê Ngọc Hân, phở Bạch Mai, bún riêu Tô Hiến Thành và bánh cuốn Hòa Mã.',
    foodEn: 'For food: Bach Khoa street food paradise (pan bread, sweet soups, bun dau), hot rice pudding on Le Ngoc Han, and Hoa Ma steamed rice rolls.',
    stayVi: 'Về lưu trú: có khách sạn 5 sao Hotel du Parc Hanoi view công viên Thống Nhất xanh ngát, Sunway Hotel, cùng các căn hộ nghỉ dưỡng cao cấp tại Times City với tiện ích thủy cung và trung tâm thương mại ngầm.',
    stayEn: 'For accommodation: 5-star Hotel du Parc Hanoi overlooking Thong Nhat Park, Sunway Hotel, and modern serviced suites in Times City.',
  ),
  HanoiZone(
    id: 'cau_giay',
    titleVi: 'khu vực Cầu Giấy – Nghĩa Đô',
    titleEn: 'Cau Giay and Nghia Do area',
    lat: 21.0365,
    lon: 105.7950,
    keywords: [
      'cau giay', 'nghia do', 'yen hoa', 'dich vong', 'dich vong hau', 'mai dich', 'quan hoa',
      'trung hoa', 'nghia tan', 'lang vong', 'tran thai tong', 'to hieu',
    ],
    tourVi: 'Về du lịch tham quan: có Bảo tàng Dân tộc học Việt Nam (nơi tái hiện nhà rông, nhà sàn của 54 dân tộc), chùa Hà nổi tiếng linh thiêng và đình làng Vòng.',
    tourEn: 'For sightseeing: Vietnam Museum of Ethnology, Ha Pagoda, and Vong Village communal house.',
    funVi: 'Về vui chơi giải trí: dạo mát và tập thể dục tại công viên Cầu Giấy, công viên hồ Nghĩa Đô nhiều cây xanh, hoặc mua sắm ăn chơi tại khu phố Tô Hiệu, Trần Thái Tông và chợ Nhà Xanh.',
    funEn: 'For leisure: Cau Giay Park, Nghia Do Lake Park, and lively streets around To Hieu and Nha Xanh Market.',
    foodVi: 'Về ăn uống: có đặc sản cốm làng Vòng thơm dẻo, bún đậu mắm tôm và tào phớ khu tập thể Nghĩa Tân, thiên đường ăn vặt chợ Nhà Xanh (Phan Văn Trường), cùng phố ẩm thực Hàn Quốc khu Trung Hòa.',
    foodEn: 'For food: famous Vong village green rice flakes (com lang Vong), Nghia Tan street food, Nha Xanh student market snacks, and Korean restaurants in Trung Hoa.',
    stayVi: 'Về lưu trú: có khách sạn 4 sao Novotel Suites Duy Tân, Grand Plaza Hanoi trên đường Trần Duy Hưng dát vàng lộng lẫy, Sen Grand Hotel Trần Thái Tông, cùng chuỗi khách sạn căn hộ cao cấp phục vụ khách công tác.',
    stayEn: 'For accommodation: 4-star Novotel Suites Hanoi on Duy Tan, opulent 5-star Grand Plaza Hanoi, and modern business aparthotels.',
  ),
  HanoiZone(
    id: 'thanh_xuan',
    titleVi: 'khu vực Thanh Xuân – Khương Đình',
    titleEn: 'Thanh Xuan area',
    lat: 20.9950,
    lon: 105.8080,
    keywords: [
      'thanh xuan', 'khuong dinh', 'phuong liet', 'nhan chinh', 'thuong dinh', 'thanh xuan bac',
      'thanh xuan nam', 'thanh xuan trung', 'ha dinh', 'khuong mai', 'khuong trung', 'kim giang', 'royal city',
    ],
    tourVi: 'Về du lịch tham quan: có Bảo tàng Phòng không – Không quân (trưng bày nhiều máy bay, tên lửa lịch sử), đình Cự Chính và công viên hồ điều hòa Nhân Chính.',
    tourEn: 'For sightseeing: Air Force and Air Defence Museum and Nhan Chinh Lake Park.',
    funVi: 'Về vui chơi giải trí: trượt băng nghệ thuật, xem phim và dạo khu trung tâm thương mại ngầm tại Royal City (Ngã Tư Sở), hoặc đi dạo quanh hồ điều hòa Nhân Chính và hồ Khương Trung.',
    funEn: 'For entertainment: ice skating and shopping at Royal City megamall, or walking around Nhan Chinh Lake.',
    foodVi: 'Về ăn uống: nổi tiếng với khu ăn vặt tập thể Thanh Xuân Bắc (bánh giò nóng, chè, nem chua rán), bún ốc và phở bò khu Khương Trung – Vương Thừa Vũ, cùng nhiều quán lẩu nướng dọc đường Nguyễn Trãi.',
    foodEn: 'For food: Thanh Xuan Bac hot pyramidal rice dumplings (banh gio) and sweet soups, plus hotpot and grill spots along Nguyen Trai.',
    stayVi: 'Về lưu trú: có khách sạn quốc tế Wyndham Garden Hanoi, tổ hợp căn hộ dịch vụ và homestay cao cấp Royal City với đầy đủ tiện ích mua sắm giải trí, cùng nhiều khách sạn tiện nghi dọc trục Nguyễn Trãi.',
    stayEn: 'For accommodation: international Wyndham Garden Hanoi, upscale serviced apartments in Royal City mega-complex, and comfortable transit hotels.',
  ),
  HanoiZone(
    id: 'hoang_mai',
    titleVi: 'khu vực Hoàng Mai – Linh Đàm',
    titleEn: 'Hoang Mai and Linh Dam area',
    lat: 20.9710,
    lon: 105.8440,
    keywords: [
      'hoang mai', 'dinh cong', 'hoang liet', 'yen so', 'linh nam', 'vinh hung', 'tan mai',
      'giap bat', 'mai dong', 'thinh liet', 'tran phu', 'tuong mai', 'dai kim', 'linh dam',
    ],
    tourVi: 'Về du lịch tham quan: có làng nghề kim hoàn Định Công truyền thống, đình Lủ (Kim Giang), đền Lừ và không gian hồ Linh Đàm xanh mát.',
    tourEn: 'For sightseeing: Dinh Cong traditional goldsmith village, Lu communal house, and scenic Linh Dam Lake.',
    funVi: 'Về vui chơi giải trí: công viên Yên Sở (công viên xanh lớn nhất Hà Nội, rất hợp cắm trại, dã ngoại cuối tuần) và đi bộ hóng gió quanh bán đảo Linh Đàm, hồ Định Công.',
    funEn: 'For leisure: camping and picnicking on the vast lawns of Yen So Park, or strolling around Linh Dam Peninsula.',
    foodVi: 'Về ăn uống: có đặc sản đậu phụ Mơ (Mai Động), bánh cuốn Thanh Trì – Lĩnh Nam, rượu Hoàng Mai, bún cá rô đồng và dãy quán ẩm thực ven hồ Linh Đàm.',
    foodEn: 'For food: famous Mo tofu, Thanh Tri steamed rice rolls, fried perch noodle soup, and lakeside dining in Linh Dam.',
    stayVi: 'Về lưu trú: có khách sạn 4 sao Mường Thanh Grand Hà Nội tọa lạc giữa bán đảo Linh Đàm xanh mát, Nam Hải Hotel, cùng chuỗi homestay căn hộ chung cư cao cấp quanh hồ Linh Đàm và đường Vành đai 3.',
    stayEn: 'For accommodation: 4-star Muong Thanh Grand Hanoi on scenic Linh Dam peninsula and modern lakeside apartment rentals.',
  ),
  HanoiZone(
    id: 'long_bien',
    titleVi: 'khu vực Long Biên – Việt Hưng',
    titleEn: 'Long Bien area',
    lat: 21.0450,
    lon: 105.8850,
    keywords: [
      'long bien', 'bo de', 'ngoc thuy', 'viet hung', 'phuc loi', 'sai dong', 'gia thuy',
      'ngoc lam', 'thuong thanh', 'duc giang', 'cu khoi', 'thach ban', 'phuc dong', 'giang bien', 'hong ha',
    ],
    tourVi: 'Về du lịch tham quan: có cầu Long Biên lịch sử bắc qua sông Hồng, chùa Bồ Đề cổ kính, và đình làng cổ Lệ Mật (phường Việt Hưng).',
    tourEn: 'For sightseeing: historic Long Bien Bridge over the Red River, Bo De Pagoda, and Le Mat ancient village communal house.',
    funVi: 'Về vui chơi giải trí: ngắm hoàng hôn trên cầu Long Biên, cắm trại bãi cỏ chân cầu Vĩnh Tuy – thảo nguyên hoa Long Biên, hoặc mua sắm vui chơi tại trung tâm thương mại Aeon Mall Long Biên.',
    funEn: 'For entertainment: sunset views from Long Bien Bridge, riverside camping near Vinh Tuy Bridge, and Aeon Mall Long Bien.',
    foodVi: 'Về ăn uống: nổi tiếng với làng ẩm thực đặc sản Lệ Mật (Việt Hưng), phố ẩm thực Ngọc Lâm – Ái Mộ ngay bên kia cầu Chương Dương với bún chả, ốc nóng, chè và bánh mì sốt vang.',
    foodEn: 'For food: Le Mat specialty village in Viet Hung, and Ngoc Lam food street with grilled pork noodles, hot snails, and sweet soups.',
    stayVi: 'Về lưu trú: có Alisa Hotel Long Biên, New Era Hotel, chuỗi biệt thự và căn hộ nghỉ dưỡng sinh thái cao cấp tại Vinhomes Riverside, cùng nhiều khách sạn tiện lợi gần cầu Chương Dương và cầu Long Biên.',
    stayEn: 'For accommodation: Alisa Hotel Long Bien, New Era Hotel, luxury ecological villas in Vinhomes Riverside, and boutique hotels near the historic bridges.',
  ),
  HanoiZone(
    id: 'ha_dong',
    titleVi: 'khu vực Hà Đông – Vạn Phúc',
    titleEn: 'Ha Dong and Van Phuc area',
    lat: 20.9715,
    lon: 105.7785,
    keywords: [
      'ha dong', 'van phuc', 'duong noi', 'kien hung', 'phu luong', 'phu la', 'mo lao',
      'van quan', 'yet kieu', 'nguyen trai', 'phuc la', 'ha cau', 'la khe', 'yen nghia',
      'bien giang', 'dong mai', 'da sy',
    ],
    tourVi: 'Về du lịch tham quan: nổi bật nhất là Làng lụa Vạn Phúc hơn một nghìn năm tuổi với con đường ô rực rỡ, chùa Bia Bà (La Khê) và làng rèn truyền thống Đa Sỹ.',
    tourEn: 'For sightseeing: the thousand-year-old Van Phuc Silk Village with its colorful umbrella street, Bia Ba Pagoda, and Da Sy blacksmith village.',
    funVi: 'Về vui chơi giải trí: tham quan Công viên Thiên văn học ngoài trời ở Dương Nội, đi dạo mát quanh hồ Văn Quán, hoặc vui chơi mua sắm tại Aeon Mall Hà Đông.',
    funEn: 'For entertainment: Duong Noi Outdoor Astronomy Park, walking around Van Quan Lake, and Aeon Mall Ha Dong.',
    foodVi: 'Về ăn uống: có nem ốc, chả vịt và quà chiều chợ Hà Đông, các quán bún chả, lẩu nướng và cà phê nhộn nhịp quanh hồ Văn Quán và khu Mộ Lao.',
    foodEn: 'For food: traditional afternoon snacks at Ha Dong Market, and lively cafes and restaurants around Van Quan Lake and Mo Lao.',
    stayVi: 'Về lưu trú: có khách sạn 4 sao Mường Thanh Grand Hà Đông tại khu đô thị Xa La, The Light Hotel, chuỗi homestay căn hộ cao cấp phong cách Singapore tại Seasons Avenue và Mulberry Lane (Mỗ Lao).',
    stayEn: 'For accommodation: 4-star Muong Thanh Grand Ha Dong in Xa La, The Light Hotel, and resort-style Singaporean condominium homestays in Seasons Avenue.',
  ),
  HanoiZone(
    id: 'nam_tu_liem',
    titleVi: 'khu vực Từ Liêm – Mỹ Đình',
    titleEn: 'My Dinh and Tu Liem area',
    lat: 21.0200,
    lon: 105.7650,
    keywords: [
      'tu liem', 'nam tu liem', 'my dinh', 'tay mo', 'dai mo', 'me tri', 'cau dien',
      'xuan phuong', 'phuong canh', 'trung van', 'phu do', 'dinh thon',
    ],
    tourVi: 'Về du lịch tham quan: có Bảo tàng Hà Nội (kiến trúc kim tự tháp ngược độc đáo), Bảo tàng Lịch sử Quân sự Việt Nam mới trên đại lộ Thăng Long (Tây Mỗ – Đại Mỗ), Sân vận động Quốc gia Mỹ Đình và làng bún Phú Đô.',
    tourEn: 'For sightseeing: Hanoi Museum, the new Vietnam Military History Museum, My Dinh National Stadium, and Phu Do noodle village.',
    funVi: 'Về vui chơi giải trí: dạo Vườn Nhật tại Vinhomes Smart City (Tây Mỗ), công viên hồ Mễ Trì, hoặc ra quảng trường Mỹ Đình rộng thoáng hóng gió và thả diều chiều tối.',
    funEn: 'For leisure: the Japanese Garden at Smart City (Tay Mo), Me Tri Lake Park, and kite-flying at My Dinh Square.',
    foodVi: 'Về ăn uống: nổi tiếng với đặc sản cốm Mễ Trì thơm dẻo, bún tươi làng Phú Đô, cùng khu phố ẩm thực Hàn Quốc (Đình Thôn – Mỹ Đình) với nhiều quán thịt nướng, gà tần sâm.',
    foodEn: 'For food: Me Tri green rice flakes, Phu Do fresh rice vermicelli, and the Korean food quarter in Dinh Thon – My Dinh.',
    stayVi: 'Về lưu trú: tập trung các khách sạn 5 sao siêu sang trọng như JW Marriott Hotel Hanoi (cạnh Trung tâm Hội nghị Quốc gia), InterContinental Hanoi Landmark72 (khách sạn cao nhất Hà Nội), Hyatt Regency West Hanoi gần sân vận động Mỹ Đình.',
    stayEn: 'For accommodation: world-class luxury 5-star hotels including JW Marriott Hanoi, InterContinental Landmark72, and Hyatt Regency West Hanoi.',
  ),
  HanoiZone(
    id: 'bac_tu_liem',
    titleVi: 'khu vực Đông Ngạc – Xuân Đỉnh – Bắc Từ Liêm',
    titleEn: 'Bac Tu Liem and Xuan Dinh area',
    lat: 21.0720,
    lon: 105.7750,
    keywords: [
      'bac tu liem', 'dong ngac', 'xuan dinh', 'phu dien', 'co nhue', 'tay tuu', 'thuy phuong',
      'lien mac', 'thuong cat', 'minh khai bac tu liem', 'duc thang', 'xuan tao', 'ngoai giao doan', 'dinh chem', 'lang chem',
    ],
    tourVi: 'Về du lịch tham quan: có làng cổ Đông Ngạc (làng khoa bảng ven sông Hồng), đình Chèm cổ kính hàng nghìn năm tuổi (Thụy Phương) và làng hoa Tây Tựu rực rỡ.',
    tourEn: 'For sightseeing: Dong Ngac ancient scholar village, thousand-year-old Chem communal house, and Tay Tuu flower village.',
    funVi: 'Về vui chơi giải trí: dạo mát tại Công viên Hòa Bình (với biểu tượng đàn chim hạc lớn và hồ nước thoáng đãng), công viên khu Ngoại Giao Đoàn và hồ Thành phố Giao Lưu.',
    funEn: 'For leisure: Hoa Binh (Peace) Park with its iconic crane monument, Diplomatic Corps Park, and Giao Luu Lake.',
    foodVi: 'Về ăn uống: có đặc sản bánh mứt cổ truyền và hồng xiêm Xuân Đỉnh, giò chả Chèm, cùng phố ăn vặt sinh viên sầm uất quanh khu Cổ Nhuế – Học viện Tài chính.',
    foodEn: 'For food: Xuan Dinh traditional pastries and sapodilla, Chem pork sausage, and affordable student street food in Co Nhue.',
    stayVi: 'Về lưu trú: có khu căn hộ khách sạn 5 sao cao cấp Fraser Residence Hanoi cạnh công viên Hòa Bình, Ping Hotel Hanoi, cùng nhiều homestay hiện đại tại khu đô thị Ngoại Giao Đoàn và Tây Hồ Tây.',
    stayEn: 'For accommodation: 5-star Fraser Residence Hanoi by Peace Park, Ping Hotel, and contemporary apartments in Diplomatic Corps Urban Area.',
  ),
  HanoiZone(
    id: 'gia_lam',
    titleVi: 'khu vực Gia Lâm – Bát Tràng',
    titleEn: 'Gia Lam and Bat Trang area',
    lat: 21.0020,
    lon: 105.9320,
    keywords: [
      'gia lam', 'bat trang', 'phu dong', 'da ton', 'kieu ky', 'ninh hiep', 'trau quy',
      'duong xa', 'dang xa', 'co bi', 'dong du', 'yen vien', 'duong quang', 'kim son gia lam', 'ocean park',
    ],
    tourVi: 'Về du lịch tham quan: có Làng gốm Bát Tràng trăm năm tuổi bên sông Hồng, Bảo tàng Gốm Bát Tràng hình bàn xoay độc đáo, đền Gióng Phù Đổng (di sản UNESCO), chùa Keo Gia Lâm và chợ vải Ninh Hiệp.',
    tourEn: 'For sightseeing: centuries-old Bat Trang Ceramic Village, Bat Trang Pottery Museum, Phu Dong Giong Temple (UNESCO heritage), and Ninh Hiep fabric market.',
    funVi: 'Về vui chơi giải trí: trải nghiệm tự tay vuốt nặn gốm trên bàn xoay ở Bát Tràng, tắm biển hồ nước mặn và dạo hồ Ngọc Trai tại Vinhomes Ocean Park (Đa Tốn – Kiêu Kỵ).',
    funEn: 'For entertainment: hands-on pottery making in Bat Trang, and the saltwater lagoon and Pearl Lake at Ocean Park.',
    foodVi: 'Về ăn uống: đặc sắc nhất là mâm cỗ truyền thống Bát Tràng (canh măng mực, su hào xào mực, chè kho), bánh tẻ Phù Đổng, ổi Đông Dư giòn ngọt và phố ẩm thực sinh viên Trâu Quỳ.',
    foodEn: 'For food: Bat Trang traditional bamboo shoot and squid soup, Phu Dong rice cakes, Dong Du crispy guavas, and Trau Quy food street.',
    stayVi: 'Về lưu trú: nổi tiếng nhất là tổ hợp hàng trăm homestay nghỉ dưỡng biển hồ tại Vinhomes Ocean Park 1 (view biển hồ nước mặn), cùng các homestay trải nghiệm văn hóa vuốt gốm độc đáo tại làng cổ Bát Tràng.',
    stayEn: 'For accommodation: hundreds of vacation homestays overlooking the artificial saltwater lagoon at Vinhomes Ocean Park, and authentic pottery craft homestays in Bat Trang.',
  ),
  HanoiZone(
    id: 'dong_anh',
    titleVi: 'khu vực Đông Anh – Cổ Loa',
    titleEn: 'Dong Anh and Co Loa area',
    lat: 21.1350,
    lon: 105.8550,
    keywords: [
      'dong anh', 'co loa', 'vinh ngoc', 'bac hong', 'thien loc', 'phuc thinh', 'thu lam',
      'uy no', 'hai boi', 'kim chung', 'nam hong', 'nguyen khe', 'tien duong', 'van noi',
      'xuan canh', 'viet hung dong anh', 'mach trang',
    ],
    tourVi: 'Về du lịch tham quan: nổi tiếng với Khu di tích Thành Cổ Loa của vua An Dương Vương (đền Thượng, giếng Ngọc, đình Ngự Triều Quy, am Mỵ Châu) và đền Sái (Thụy Lâm).',
    tourEn: 'For sightseeing: Co Loa Ancient Citadel of King An Duong Vuong (Thuong Temple, Ngoc Well, My Chau shrine) and Sai Temple.',
    funVi: 'Về vui chơi giải trí: cắm trại, dã ngoại trên bãi bồi sông Hồng dưới chân cầu Nhật Tân – Vĩnh Ngọc, ngắm cầu Nhật Tân rực sáng về đêm và tham quan Trung tâm Triển lãm Quốc gia mới.',
    funEn: 'For leisure: riverside camping along the Red River banks near Nhat Tan Bridge and visiting the National Exhibition Center.',
    foodVi: 'Về ăn uống: có đặc sản bún Mạch Tràng cổ truyền ở Cổ Loa, đậu phụ làng Kênh, bỏng Chủ và các món cá lăng, cá chép sông Hồng tươi ngon.',
    foodEn: 'For food: Co Loa traditional Mach Trang rice noodles, Kenh village tofu, and fresh Red River fish dishes.',
    stayVi: 'Về lưu trú: có khách sạn Dragon Airport Hotel, Chio Hotel & Apartment Đông Anh, chuỗi khách sạn tiện nghi phục vụ khách quá cảnh sân bay Nội Bài và khách tham quan khu di tích thành Cổ Loa.',
    stayEn: 'For accommodation: Dragon Airport Hotel, Chio Hotel & Apartment Dong Anh, transit airport hotels, and heritage stays near Co Loa Citadel.',
  ),
  HanoiZone(
    id: 'soc_son',
    titleVi: 'khu vực Sóc Sơn – Nội Bài',
    titleEn: 'Soc Son area',
    lat: 21.2580,
    lon: 105.8420,
    keywords: [
      'soc son', 'noi bai', 'phu linh', 'minh phu', 'minh tri', 'nam son', 'trung gia',
      'da phuc', 'kim anh', 'quang tien', 'tien duoc', 'mai dinh', 'dong do', 'ham lon',
    ],
    tourVi: 'Về du lịch tham quan: có Quần thể Khu di tích Đền Gióng Sóc Sơn trên núi Vệ Linh, chùa Non Nước, và Việt Phủ Thành Chương mang đậm kiến trúc cổ Việt Nam.',
    tourEn: 'For sightseeing: Soc Son Giong Temple complex on Ve Linh Mountain, Non Nuoc Pagoda, and Thanh Chuong Viet Palace.',
    funVi: 'Về vui chơi giải trí: cắm trại, chèo thuyền kayak và đi bộ xuyên rừng thông mát lành tại hồ Đồng Đò (xã Minh Trí), núi Hàm Lợn (Nam Sơn) và khu sinh thái Bản Rõm.',
    funEn: 'For leisure: pine forest trekking, camping, and kayaking at Dong Do Lake, Ham Lon Mountain, and Ban Rom eco-park.',
    foodVi: 'Về ăn uống: nổi tiếng với gà đồi Sóc Sơn nướng mật ong thơm lừng, cá nướng hồ Đồng Đò, thịt lợn bản và bánh đúc sốt xanh Phù Linh.',
    foodEn: 'For food: honey-roasted Soc Son hill chicken, grilled lake fish, and Phu Linh hot green rice cake.',
    stayVi: 'Về lưu trú: thiên đường nghỉ dưỡng sinh thái ngoại ô với Amaya Home Lodge & Spa phong cách Bắc Âu, Nhà Bên Rừng U Lesa Retreat giữa đồi thông, Shoji Home và The Chipmunk view hồ Đồng Đò thơ mộng.',
    stayEn: 'For accommodation: premier eco-retreats including Nordic-style Amaya Home Lodge & Spa, U Lesa forest cabins, and scenic lakeside villas around Dong Do Lake.',
  ),
  HanoiZone(
    id: 'thanh_tri',
    titleVi: 'khu vực Thanh Trì – Ngọc Hồi',
    titleEn: 'Thanh Tri area',
    lat: 20.9420,
    lon: 105.8450,
    keywords: [
      'thanh tri', 'ngoc hoi', 'dai thanh', 'tu hiep', 'tan trieu', 'dong my', 'nam phu',
      'van dien', 'thanh liet', 'ta thanh oai', 'huu hoa', 'yen my', 'ninh so', 'trieu khuc',
    ],
    tourVi: 'Về du lịch tham quan: có làng nghề cổ Triều Khúc (Tân Triều), đình Nội, chùa Quang Ân (Thanh Liệt – quê hương danh nhân Chu Văn An) và đầm sen Ninh Sở ven sông Hồng.',
    tourEn: 'For sightseeing: Trieu Khuc traditional craft village, Quang An Pagoda (hometown of teacher Chu Van An), and Ninh So lotus pond.',
    funVi: 'Về vui chơi giải trí: dạo mát tại công viên Chu Văn An rộng lớn, câu cá giải trí và chụp ảnh mùa sen nở tại vùng ven sông Đông Mỹ – Ninh Sở.',
    funEn: 'For leisure: walking in Chu Van An Park, recreational fishing, and visiting lotus ponds in Dong My – Ninh So.',
    foodVi: 'Về ăn uống: lừng danh với bánh cuốn Thanh Trì tráng mỏng chấm nước mắm cà cuống, rượu hoa cúc làng Ngâu (Tam Hiệp) và các món lẩu lông, cháo lòng Triều Khúc.',
    foodEn: 'For food: famous paper-thin Thanh Tri steamed rice rolls, Ngau village chrysanthemum wine, and Trieu Khuc local delicacies.',
    stayVi: 'Về lưu trú: có khách sạn Hồng Kông Ngọc Hồi trên trục Quốc lộ 1A, các nhà nghỉ sinh thái ven sông Hồng, thuận tiện cho khách công tác và du lịch làng nghề truyền thống.',
    stayEn: 'For accommodation: Hong Kong Ngoc Hoi Hotel on Highway 1A, riverside eco-lodges, and transit motels near craft villages.',
  ),
  HanoiZone(
    id: 'son_tay',
    titleVi: 'khu vực Sơn Tây – Đường Lâm',
    titleEn: 'Son Tay and Duong Lam area',
    lat: 21.1380,
    lon: 105.5020,
    keywords: [
      'son tay', 'duong lam', 'trung hung', 'tung thien', 'co dong', 'kim son', 'xuan khanh',
      'vien son', 'phu thinh', 'le loi son tay', 'ngo quyen son tay', 'dong mo',
    ],
    tourVi: 'Về du lịch tham quan: có Làng cổ Đường Lâm xây bằng đá ong (cổng làng Mông Phụ, chùa Mía, đền Ngô Quyền, đền Phùng Hưng), Thành cổ Sơn Tây với hào nước cổ kính và đền Và.',
    tourEn: 'For sightseeing: Duong Lam Ancient Village built of laterite stone, Mia Pagoda, Son Tay Ancient Citadel, and Va Temple.',
    funVi: 'Về vui chơi giải trí: đạp xe giữa đường làng đá ong Đường Lâm, dạo phố đi bộ quanh hào Thành cổ Sơn Tây, hoặc nghỉ dưỡng, chèo thuyền ở hồ Đồng Mô và Làng Văn hóa các dân tộc Việt Nam.',
    funEn: 'For entertainment: cycling through Duong Lam ancient village, Son Tay Citadel walking street, Dong Mo Lake, and the Vietnam National Village for Ethnic Culture and Tourism.',
    foodVi: 'Về ăn uống: nổi tiếng với gà mía Sơn Tây da giòn thịt săn chắc, thịt quay đòn Đường Lâm ướp lá ổi, tương nếp Mông Phụ, chè lam, kẹo lạc và bánh tẻ Phú Nhi.',
    foodEn: 'For food: Son Tay Mia free-range chicken, Duong Lam roasted pork belly with guava leaves, Mong Phu soy sauce, and Phu Nhi rice cakes.',
    stayVi: 'Về lưu trú: nổi tiếng với resort nghỉ dưỡng xanh Tomodachi Retreat Làng Mít (đoạt giải kiến trúc quốc tế), Glory Resort 5 sao có nông trại và spa, cùng các homestay trải nghiệm ngủ nhà cổ trăm năm tại Làng cổ Đường Lâm.',
    stayEn: 'For accommodation: award-winning eco-resort Tomodachi Retreat Lang Mit, 5-star Glory Resort, and heritage homestays inside hundred-year-old stone houses in Duong Lam.',
  ),
  HanoiZone(
    id: 'ba_vi',
    titleVi: 'khu vực Ba Vì – Tản Lĩnh',
    titleEn: 'Ba Vi Mountain area',
    lat: 21.0950,
    lon: 105.3850,
    keywords: [
      'ba vi', 'tan linh', 'van hoa', 'yen bai', 'minh quang', 'suoi hai', 'co do',
      'vat lai', 'bat bat', 'quang oai', 'tay dang', 'khoang xanh', 'thien son',
    ],
    tourVi: 'Về du lịch tham quan: có Vườn quốc gia Ba Vì hùng vĩ với đỉnh Vua, đền Thượng thờ Tản Viên Sơn Thánh, đền thờ Bác Hồ, nhà thờ cổ Ba Vì giữa rừng và làng họa sĩ Cổ Đô.',
    tourEn: 'For sightseeing: Ba Vi National Park, Thuong Temple dedicated to the Mountain God Tan Vien, the old forest church ruins, and Co Do painter village.',
    funVi: 'Về vui chơi giải trí: săn mây và cắm trại dưới rừng thông Ba Vì, tắm khoáng nóng và vui chơi thác nước tại Khoang Xanh – Suối Tiên, Thiên Sơn – Suối Ngà, Ao Vua và hồ Suối Hai.',
    funEn: 'For leisure: cloud-hunting and pine forest camping in Ba Vi National Park, hot springs at Khoang Xanh – Suoi Tien, Ao Vua, and Suoi Hai Lake.',
    foodVi: 'Về ăn uống: đặc sản sữa tươi, sữa chua nếp cẩm và bánh sữa Ba Vì, cùng các món bê non nướng, gà đồi Ba Vì, lợn mán và cá lăng sông Đà.',
    foodEn: 'For food: Ba Vi fresh milk, purple sticky rice yogurt, milk candies, roasted hill chicken, and Da River fish.',
    stayVi: 'Về lưu trú: có resort 5 sao Melia Ba Vi Mountain Retreat ẩn mình giữa rừng nguyên sinh mây phủ, Tản Đà Spa Resort tắm khoáng nóng tự nhiên bên hồ Suối Bơn, cùng Family Resort và chuỗi villa sinh thái chân núi Ba Vì.',
    stayEn: 'For accommodation: 5-star Melia Ba Vi Mountain Retreat in primeval cloud forest, Tan Da Mineral Spring Spa Resort by Suoi Bon Lake, and eco-villas.',
  ),
  HanoiZone(
    id: 'hoai_duc_dan_phuong',
    titleVi: 'khu vực Hoài Đức – Đan Phượng – Phúc Thọ',
    titleEn: 'Hoai Duc, Dan Phuong and Phuc Tho area',
    lat: 21.0550,
    lon: 105.6850,
    keywords: [
      'hoai duc', 'dan phuong', 'phuc tho', 'an khanh', 'duong lieu', 'son dong', 'thi tran troi',
      'thi tran phung', 'nem phung', 'lien minh', 'o dien', 'hat mon', 'kieu phu', 'bao son', 'van canh', 'lai yen',
    ],
    tourVi: 'Về du lịch tham quan: có làng nghề điêu khắc tượng gỗ Sơn Đồng (Hoài Đức), đền Hát Môn thờ Hai Bà Trưng (Phúc Thọ) và làng nghề truyền thống Dương Liễu.',
    tourEn: 'For sightseeing: Son Dong traditional wood-carving village, Hat Mon Temple of the Trung Sisters, and Duong Lieu craft village.',
    funVi: 'Về vui chơi giải trí: công viên giải trí Thiên Đường Bảo Sơn (xã An Khánh, Hoài Đức) với thủy cung, safari, phim trường và các trò chơi cảm giác mạnh.',
    funEn: 'For entertainment: Bao Son Paradise theme park in An Khanh with its aquarium, safari, and amusement rides.',
    foodVi: 'Về ăn uống: nổi tiếng với đặc sản nem Phùng (Đan Phượng) trộn thính thơm bùi cuốn lá sung, miến dong Dương Liễu, bánh tẻ Cát Quế, thịt dê Phúc Thọ và bưởi Đường Quế Dương.',
    foodEn: 'For food: Phung fermented pork rolls wrapped in fig leaves (nem Phung), Duong Lieu arrowroot vermicelli, and Que Duong sweet pomelo.',
    stayVi: 'Về lưu trú: có Sunny Hotel & Apartment trên Quốc lộ 32 gần tuyến metro Nhổn, các homestay sinh thái ven sông Đáy và khu nghỉ ngơi miệt vườn Đan Phượng.',
    stayEn: 'For accommodation: Sunny Hotel & Apartment on Highway 32 near Nhon metro station, riverside eco-homestays, and rustic orchard farmstays.',
  ),
  HanoiZone(
    id: 'quoc_oai_thach_that_chuong_my',
    titleVi: 'khu vực Quốc Oai – Thạch Thất – Chương Mỹ',
    titleEn: 'Quoc Oai, Thach That and Chuong My area',
    lat: 20.9950,
    lon: 105.6150,
    keywords: [
      'quoc oai', 'thach that', 'chuong my', 'sai son', 'tay phuong', 'phu nghia', 'chuc son',
      'hoa lac', 'ha bang', 'yen xuan', 'phu cat', 'hung dao', 'tran phu chuong my', 'quang bi',
      'chua thay', 'chua tram gian', 'nui tram',
    ],
    tourVi: 'Về du lịch tham quan: có danh thắng Chùa Thầy và núi Sài Sơn (Quốc Oai) với thủy đình múa rối nước cổ nhất Việt Nam, chùa Tây Phương (Thạch Thất) nổi tiếng với các pho tượng La Hán gỗ mít, chùa Trăm Gian và làng mây tre đan Phú Vinh (Chương Mỹ).',
    tourEn: 'For sightseeing: Thay Pagoda at Sai Son Mountain, Tay Phuong Pagoda famous for its jackfruit-wood Arhat statues, Tram Gian Pagoda, and Phu Vinh bamboo weaving village.',
    funVi: 'Về vui chơi giải trí: xem vở diễn thực cảnh "Tinh hoa Bắc Bộ" dưới chân núi Sài Sơn, leo núi và cắm trại cuối tuần tại núi Trầm (Chương Mỹ) hoặc dã ngoại quanh hồ Tân Xã (Hòa Lạc).',
    funEn: 'For entertainment: the "Quintessence of Tonkin" open-air water show near Thay Pagoda, and camping at Tram Mountain.',
    foodVi: 'Về ăn uống: có đặc sản chè lam Thạch Thất dẻo thơm vị gừng, rau sắng chùa Thầy, gà đồi Chương Mỹ và cá nướng hồ Đồng Sương.',
    foodEn: 'For food: Thach That ginger sticky rice cake (che lam), Thay Pagoda melientha greens, and Chuong My hill chicken.',
    stayVi: 'Về lưu trú: nổi bật với Asean Resort & Spa (Thạch Thất) 4 sao với đồi trượt cỏ và bể sục khoáng nóng thảo dược, Hoàng Long Resort, cùng các khu cắm trại glamping bên hồ Đồng Mô và núi Trầm.',
    stayEn: 'For accommodation: prominent 4-star Asean Resort & Spa with grass skiing and herbal mineral hot tubs, Hoang Long Resort, and glamping sites by Dong Mo Lake.',
  ),
  HanoiZone(
    id: 'thanh_oai_thuong_tin_phu_xuyen',
    titleVi: 'khu vực Thanh Oai – Thường Tín – Phú Xuyên',
    titleEn: 'Thanh Oai, Thuong Tin and Phu Xuyen area',
    lat: 20.8450,
    lon: 105.8450,
    keywords: [
      'thanh oai', 'thuong tin', 'phu xuyen', 'binh minh', 'bich hoa', 'nhi khe', 'chuyen my',
      'van diem', 'phuong duc', 'dan hoa', 'tam hung', 'hong van', 'chuong duong thuong tin',
      'thuong phuc', 'dai xuyen', 'lang chuong', 'uoc le', 'quan ganh',
    ],
    tourVi: 'Về du lịch tham quan: là vùng đất "trăm nghề" phía nam Hà Nội với làng nón Chuông, làng quạt Chàng Sơn, làng giò chả Ước Lễ (Thanh Oai), chùa Đậu (Thường Tín), làng khảm trai Chuyên Mỹ và làng nặn tò he Xuân La (Phú Xuyên).',
    tourEn: 'For sightseeing: famous craft villages including Chuong conical hat village, Uoc Le ancient gate, Dau Pagoda, Chuyen My mother-of-pearl inlay village, and Xuan La toy figurine village.',
    funVi: 'Về vui chơi trải nghiệm: tự tay làm nón lá ở làng Chuông, nặn tò he ở Xuân La, chụp ảnh cổng làng cổ Ước Lễ và tham quan khu sinh thái ven sông Hồng ở Hồng Vân (Thường Tín).',
    funEn: 'For experiences: making conical hats in Chuong village, molding colorful rice figurines in Xuan La, and visiting Hong Van riverside eco-village.',
    foodVi: 'Về ăn uống: nổi tiếng khắp cả nước với giò chả Ước Lễ (Thanh Oai) giòn thơm, bánh dày Quán Gánh (Thường Tín) dẻo mịn nhân đậu xanh và đặc sản chim ngói Phú Xuyên.',
    foodEn: 'For food: renowned Uoc Le pork sausage (gio cha Uoc Le), Quan Ganh sticky rice cakes (banh day Quan Ganh), and Phu Xuyen delicacies.',
    stayVi: 'Về lưu trú: có các khách sạn trung tâm thị trấn Thường Tín, nhà nghỉ sinh thái ven đê sông Hồng ở làng sinh thái Hồng Vân, cùng các điểm lưu trú tiện lợi khi về thăm làng nghề giò chả Ước Lễ và nón Chuông.',
    stayEn: 'For accommodation: central hotels in Thuong Tin town, riverside ecological farmstays in Hong Van eco-village, and convenient lodgings near traditional craft villages.',
  ),
  HanoiZone(
    id: 'ung_hoa_my_duc',
    titleVi: 'khu vực Mỹ Đức – Ứng Hòa – Chùa Hương',
    titleEn: 'My Duc, Ung Hoa and Perfume Pagoda area',
    lat: 20.6800,
    lon: 105.7600,
    keywords: [
      'my duc', 'ung hoa', 'huong son', 'van dinh', 'quang phu cau', 'tuy lai', 'dai nghia',
      'phuc son', 'hong son', 'ung thien', 'hoa xa', 'chua huong', 'quan son',
    ],
    tourVi: 'Về du lịch tham quan: nổi tiếng nhất là quần thể danh thắng Chùa Hương – động Hương Tích (xã Hương Sơn, Mỹ Đức), hồ Quan Sơn – Tuy Lai ("Hạ Long trên cạn" của Hà Nội) và làng tăm hương Quảng Phú Cầu rực rỡ sắc màu (Ứng Hòa).',
    tourEn: 'For sightseeing: the Perfume Pagoda (Chua Huong) complex and Huong Tich Cave, Quan Son Lake, and the colorful Quang Phu Cau incense village.',
    funVi: 'Về vui chơi trải nghiệm: ngồi đò dọc suối Yến ngắm núi non và hoa súng mùa thu, đi cáp treo lên động Hương Tích, chèo thuyền giữa núi đá vôi hồ Quan Sơn và chụp ảnh tại làng hương Quảng Phú Cầu.',
    funEn: 'For leisure: boat rides along the Yen Stream to Perfume Pagoda, rowing on Quan Son Lake, and visiting Quang Phu Cau incense village.',
    foodVi: 'Về ăn uống: lừng danh với đặc sản vịt cỏ Vân Đình (vịt nướng chao, vịt luộc, cháo vịt), rau sắng và mơ rừng Chùa Hương, củ mài và bánh khảo Hương Sơn.',
    foodEn: 'For food: famous Van Dinh grass duck (grilled or boiled), Perfume Pagoda forest apricots and melientha greens, and Huong Son wild yam.',
    stayVi: 'Về lưu trú: có Khách sạn Công Đoàn Chùa Hương ngay bến đò suối Yến, chuỗi nhà nghỉ phục vụ khách hành hương trẩy hội, cùng các khu nghỉ dưỡng sinh thái ven hồ Quan Sơn và Tuy Lai non nước hữu tình.',
    stayEn: 'For accommodation: Cong Doan Hotel right by the Yen Stream boat dock, pilgrimage lodgings, and rustic lakeside eco-retreats around scenic Quan Son Lake.',
  ),
];

/// Kiểm tra toạ độ (lat, lon) có nằm trong địa phận Hà Nội không.
bool isHanoiCoord(double lat, double lon) =>
    lat >= 20.53 && lat <= 21.39 && lon >= 105.28 && lon <= 106.03;

/// Phát hiện người dùng đang hỏi trọng tâm về mảng nào:
/// 'food' (ăn uống/đặc sản) | 'fun' (vui chơi/giải trí) | 'tour' (du lịch/tham quan) | 'all' (tổng hợp).
String detectLocalAspect(String raw) {
  final t = normVi(raw);
  final askFood = RegExp(r'\b(an uong|an gi|mon gi|mon ngon|dac san|am thuc|quan an|nha hang|ca phe|cafe|coffee|qua vat|an vat|do an|co gi ngon|an o dau)\b').hasMatch(t);
  final askFun = RegExp(r'\b(vui choi|choi gi|di choi|giai tri|dao mat|hong gio|di dao|choi o dau|di dau choi|co gi vui|co gi choi)\b').hasMatch(t);
  final askTour = RegExp(r'\b(du lich|tham quan|di tich|danh thang|canh dep|check in|diem den)\b').hasMatch(t);
  final askStay = RegExp(r'\b(khach san|nha nghi|homestay|resort|luu tru|cho o|nghi ngoi|cho nghi|o dau|hotel|motel|stay|hostel|villa|bungalow|dat phong)\b').hasMatch(t);
  final count = (askFood ? 1 : 0) + (askFun ? 1 : 0) + (askTour ? 1 : 0) + (askStay ? 1 : 0);
  if (count != 1) return 'all';
  if (askStay) return 'stay';
  if (askFood) return 'food';
  if (askFun) return 'fun';
  return 'tour';
}

/// Tìm khu vực Hà Nội khớp với tên xã/phường/địa danh hoặc toạ độ gần nhất.
HanoiZone? findHanoiZone({String? name, String? raw, double? lat, double? lon, bool matchKeywordOnly = false}) {
  final search = normVi('${name ?? ''} ${raw ?? ''}').trim();
  HanoiZone? kwBest;
  if (search.isNotEmpty) {
    final padded = ' $search ';
    var bestLen = 0;
    for (final z in hanoiZones) {
      for (final kw in z.keywords) {
        if (kw.length > bestLen && padded.contains(' $kw ')) {
          kwBest = z;
          bestLen = kw.length;
        }
      }
    }
  }
  if (matchKeywordOnly) return kwBest;
  final inHanoiByName = search.contains('ha noi');
  if (lat != null && lon != null && (isHanoiCoord(lat, lon) || inHanoiByName)) {
    final k = math.cos(lat * math.pi / 180);
    double distTo(HanoiZone z) {
      final dy = (z.lat - lat) * 111.2;
      final dx = (z.lon - lon) * 111.2 * k;
      return math.sqrt(dx * dx + dy * dy);
    }

    if (kwBest != null && distTo(kwBest) <= 12) return kwBest;
    HanoiZone best = hanoiZones.first;
    var bestDist = double.infinity;
    for (final z in hanoiZones) {
      final d = distTo(z);
      if (d < bestDist) {
        bestDist = d;
        best = z;
      }
    }
    if (bestDist <= 35) return best;
  }
  if (kwBest != null) return kwBest;
  if (inHanoiByName) return hanoiZones.first;
  return null;
}

/// Tạo lời giới thiệu tự nhiên về địa điểm ăn uống, vui chơi, du lịch cho một xã/phường/khu vực thuộc Hà Nội.
/// Trả về null nếu địa điểm không thuộc Hà Nội.
(String, String)? buildHanoiGuide(String placeVi, String placeEn, {double? lat, double? lon, String raw = ''}) {
  final z = findHanoiZone(name: placeVi, raw: raw, lat: lat, lon: lon);
  if (z == null) return null;
  final aspect = detectLocalAspect(raw);
  final cleanPlace = placeVi.trim().isEmpty ? z.titleVi : placeVi.trim();
  final normPlace = normVi(cleanPlace);
  final titleParts = z.titleVi
      .replaceAll('khu vực ', '')
      .split(RegExp(r'\s*[–-]\s*'))
      .map((s) => normVi(s))
      .where((s) => s.isNotEmpty);
  final sameTitle = titleParts.any((p) => ' $normPlace '.contains(' $p '));
  final String headVi;
  if (normPlace == 'ha noi' || normPlace == 'thanh pho ha noi') {
    headVi = 'Tại trung tâm Hà Nội (${z.titleVi})';
  } else if (cleanPlace.startsWith('chỗ bạn đứng') || cleanPlace.startsWith('nơi bạn đang đứng')) {
    headVi = 'Quanh $cleanPlace (thuộc ${z.titleVi})';
  } else {
    headVi = sameTitle ? 'Tại $cleanPlace' : 'Tại $cleanPlace (thuộc ${z.titleVi})';
  }
  final headEn = 'Around ${placeEn.trim().isEmpty ? z.titleEn : placeEn.trim()} (${z.titleEn})';

  final String bodyVi;
  final String bodyEn;
  if (!kHanoiFoodStayEnabled) {
    // phần quán ăn, chỗ ở đang ẩn: chỉ kể tham quan, vui chơi
    final asked = aspect == 'food' ||
        aspect == 'stay' ||
        RegExp(r'\b(an uong|an gi|mon gi|mon ngon|dac san|am thuc|quan an|nha hang|khach san|nha nghi|homestay|luu tru|cho o)\b')
            .hasMatch(normVi(raw));
    final noteVi = asked ? 'Phần quán ăn và chỗ ở đang tạm ẩn. Mình kể chỗ tham quan, vui chơi nhé. ' : '';
    final noteEn = asked ? 'Food and accommodation are hidden for now. Here are places to visit instead. ' : '';
    return ('$noteVi$headVi: ${aspect == 'fun' ? '${z.funVi} ${z.tourVi}' : '${z.tourVi} ${z.funVi}'}',
        '$noteEn$headEn: ${aspect == 'fun' ? '${z.funEn} ${z.tourEn}' : '${z.tourEn} ${z.funEn}'}');
  }
  switch (aspect) {
    case 'stay':
      bodyVi = '$headVi: ${z.stayVi} Ngoài ra quanh đây còn có các món ngon nổi tiếng như: ${z.foodVi.replaceFirst('Về ăn uống: ', '')}';
      bodyEn = '$headEn: ${z.stayEn} Nearby dining recommendations: ${z.foodEn}';
    case 'food':
      bodyVi = '$headVi: ${z.foodVi} Về chỗ nghỉ: ${z.stayVi.replaceFirst('Về lưu trú: ', '')}';
      bodyEn = '$headEn: ${z.foodEn} Accommodation: ${z.stayEn}';
    case 'fun':
      bodyVi = '$headVi: ${z.funVi} ${z.tourVi} ${z.foodVi}';
      bodyEn = '$headEn: ${z.funEn} ${z.tourEn} ${z.foodEn}';
    case 'tour':
      bodyVi = '$headVi: ${z.tourVi} ${z.funVi} ${z.foodVi}';
      bodyEn = '$headEn: ${z.tourEn} ${z.funEn} ${z.foodEn}';
    default:
      bodyVi = '$headVi: ${z.tourVi} ${z.funVi} ${z.foodVi} ${z.stayVi}';
      bodyEn = '$headEn: ${z.tourEn} ${z.funEn} ${z.foodEn} ${z.stayEn}';
  }
  return (bodyVi, bodyEn);
}

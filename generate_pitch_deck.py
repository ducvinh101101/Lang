import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

def create_presentation():
    prs = Presentation()
    # 16:9 widescreen format
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6] # blank slide

    # Theme Colors
    c_navy = RGBColor(11, 27, 61)       # #0B1B3D - Deep Space / Sơn Mài Navy
    c_blue = RGBColor(27, 76, 140)      # #1B4C8C - Steel Blue
    c_light_bg = RGBColor(248, 250, 252)# #F8FAFC - Soft White Canvas
    c_card_bg = RGBColor(255, 255, 255) # White card
    c_card_border = RGBColor(226, 232, 240) # Border
    c_gold = RGBColor(212, 175, 55)     # #D4AF37 - Gold / Đồng
    c_gold_light = RGBColor(255, 249, 230)
    c_text_dark = RGBColor(30, 41, 59)  # #1E293B
    c_text_muted = RGBColor(100, 116, 139) # #64748B
    c_white = RGBColor(255, 255, 255)
    c_emerald = RGBColor(16, 124, 65)   # Green for verified / tested

    font_name = "Segoe UI"

    def add_background(slide, is_dark=False):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = c_navy if is_dark else c_light_bg
        bg.line.color.rgb = c_navy if is_dark else c_light_bg
        return bg

    def add_header(slide, slide_num, category, title, is_dark=False):
        # Category / Tag
        tx_cat = slide.shapes.add_textbox(Inches(0.8), Inches(0.45), Inches(11), Inches(0.35))
        tf_c = tx_cat.text_frame
        tf_c.word_wrap = True
        tf_c.margin_left = tf_c.margin_top = tf_c.margin_right = tf_c.margin_bottom = 0
        p_c = tf_c.paragraphs[0]
        p_c.text = f"CÂU HỎI {slide_num} · {category.upper()}"
        p_c.font.name = font_name
        p_c.font.size = Pt(11)
        p_c.font.bold = True
        p_c.font.color.rgb = c_gold if is_dark else c_blue

        # Main Title
        tx_title = slide.shapes.add_textbox(Inches(0.8), Inches(0.8), Inches(11.5), Inches(0.7))
        tf_t = tx_title.text_frame
        tf_t.word_wrap = True
        tf_t.margin_left = tf_t.margin_top = tf_t.margin_right = tf_t.margin_bottom = 0
        p_t = tf_t.paragraphs[0]
        p_t.text = title
        p_t.font.name = font_name
        p_t.font.size = Pt(22)
        p_t.font.bold = True
        p_t.font.color.rgb = c_white if is_dark else c_navy

    def add_card(slide, left, top, width, height, title, items, badge="", is_accent=False):
        # Card shape
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height))
        shape.fill.solid()
        shape.fill.fore_color.rgb = c_gold_light if is_accent else c_card_bg
        shape.line.color.rgb = c_gold if is_accent else c_card_border
        shape.line.width = Pt(1.5 if is_accent else 1)

        # Card Text Box
        pad = 0.25
        tx = slide.shapes.add_textbox(Inches(left + pad), Inches(top + pad), Inches(width - pad*2), Inches(height - pad*2))
        tf = tx.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        # Title
        p_title = tf.paragraphs[0]
        p_title.text = title
        p_title.font.name = font_name
        p_title.font.size = Pt(14)
        p_title.font.bold = True
        p_title.font.color.rgb = c_navy

        if badge:
            p_badge = tf.add_paragraph()
            p_badge.text = f"[{badge}]"
            p_badge.font.name = font_name
            p_badge.font.size = Pt(9.5)
            p_badge.font.bold = True
            p_badge.font.color.rgb = c_blue
            p_badge.space_after = Pt(6)

        # Bullets / items
        for it in items:
            p = tf.add_paragraph()
            p.text = f"• {it}"
            p.font.name = font_name
            p.font.size = Pt(10.5)
            p.font.color.rgb = c_text_dark
            p.space_after = Pt(4)

    # ==========================================================
    # SLIDE 0: TITLE SLIDE
    # ==========================================================
    s0 = prs.slides.add_slide(blank_layout)
    add_background(s0, is_dark=True)

    # Accent decorative bar
    bar = s0.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(1.2), Inches(0.12), Inches(4.8))
    bar.fill.solid()
    bar.fill.fore_color.rgb = c_gold
    bar.line.fill.background()

    # Sub-header
    tx0 = s0.shapes.add_textbox(Inches(1.2), Inches(1.3), Inches(11), Inches(0.5))
    tf0 = tx0.text_frame
    p0 = tf0.paragraphs[0]
    p0.text = "NASA SPACE APPS CHALLENGE 2026 · CHALLENGE #14: THE EARTH INFORMATION JUKEBOX"
    p0.font.name = font_name
    p0.font.size = Pt(12)
    p0.font.bold = True
    p0.font.color.rgb = c_gold

    # Main Project Title
    tx_main = s0.shapes.add_textbox(Inches(1.2), Inches(1.8), Inches(11), Inches(1.8))
    tf_m = tx_main.text_frame
    p_m1 = tf_m.paragraphs[0]
    p_m1.text = "LẮNG — QUẢ ĐỊA CẦU BIẾT NÓI"
    p_m1.font.name = font_name
    p_m1.font.size = Pt(36)
    p_m1.font.bold = True
    p_m1.font.color.rgb = c_white

    p_m2 = tf_m.add_paragraph()
    p_m2.text = "Âm Thanh Hóa Dữ Liệu Khoa Học NASA & Trợ Năng Xúc Giác Đa Giác Quan"
    p_m2.font.name = font_name
    p_m2.font.size = Pt(20)
    p_m2.font.color.rgb = RGBColor(226, 232, 240)

    # 6 Core questions box
    tx_sub = s0.shapes.add_textbox(Inches(1.2), Inches(3.8), Inches(11), Inches(2.2))
    tf_sub = tx_sub.text_frame
    p_s1 = tf_sub.paragraphs[0]
    p_s1.text = "BẢN THUYẾT TRÌNH BẢO VỆ DỰ ÁN TRƯỚC HỘI ĐỒNG BAN GIÁM KHẢO"
    p_s1.font.name = font_name
    p_s1.font.size = Pt(13)
    p_s1.font.bold = True
    p_s1.font.color.rgb = c_gold

    pitch_bullets = [
        "1. Dự án đang giải quyết vấn đề gì? (Problem Statement)",
        "2. Vì sao đội chọn vấn đề này? (Why this Problem)",
        "3. Dữ liệu NASA nào được sử dụng và xử lý như thế nào? (NASA Data & Pipeline)",
        "4. Điểm khác biệt của sản phẩm so với những giải pháp hiện có? (Uniqueness & Competitive Edge)",
        "5. Sản phẩm đã được thử nghiệm đến đâu? (Testing & Validation Evidence)",
        "6. Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì? (Future Vision & Next Steps)"
    ]
    for pb in pitch_bullets:
        p_b = tf_sub.add_paragraph()
        p_b.text = pb
        p_b.font.name = font_name
        p_b.font.size = Pt(11)
        p_b.font.color.rgb = RGBColor(203, 213, 225)

    # Footer team
    tx_foot = s0.shapes.add_textbox(Inches(1.2), Inches(6.3), Inches(11), Inches(0.5))
    p_f = tx_foot.text_frame.paragraphs[0]
    p_f.text = "Đội thi: ĐÀN BẦU TRÁI ĐẤT · 6 Thành viên · Bản chạy thực tế: sense-app-two.vercel.app"
    p_f.font.name = font_name
    p_f.font.size = Pt(11)
    p_f.font.italic = True
    p_f.font.color.rgb = c_gold

    # ==========================================================
    # SLIDE 1: DỰ ÁN ĐANG GIẢI QUYẾT VẤN ĐỀ GÌ?
    # ==========================================================
    s1 = prs.slides.add_slide(blank_layout)
    add_background(s1)
    add_header(s1, "01", "BÀI TOÁN CẦN GIẢI QUYẾT", "Dự án đang giải quyết vấn đề gì?")

    add_card(s1, 0.8, 1.7, 3.7, 5.2, "Rào Cản Thị Giác Khổng Lồ", [
        "Kho dữ liệu viễn thám Trái Đất & Vũ trụ của NASA (EIC, GISS, POWER, FIRMS, SRTM) mang giá trị khoa học to lớn.",
        "Tuy nhiên, 100% dữ liệu hiện nay đều hiển thị qua biểu đồ, bản đồ nhiệt, ảnh viễn thám và dashboard phức tạp.",
        "Tạo nên 'bức tường vô hình' đối với hơn 1,2 triệu người khiếm thị Việt Nam và hơn 253 triệu người suy giảm thị lực toàn cầu."
    ], badge="Thực trạng hiện nay")

    add_card(s1, 4.8, 1.7, 3.7, 5.2, "Bất Bình Đẳng & Nguy Cơ Lớn", [
        "Mất cơ hội tự vệ trước thiên tai: Khi siêu bão (Yagi) hoặc lũ quét đổ bộ, người khiếm thị không thể nhìn bản đồ vệ tinh đường đi của bão.",
        "Thiếu hụt giáo dục khoa học STEM: Trẻ em khiếm thị gần như không có cách nào tiếp cận vẻ đẹp và kiến thức vũ trụ.",
        "Sự cô lập công nghệ: Các app thời tiết hiện nay chứa quá nhiều nút bấm, quảng cáo và không tối ưu cho người không nhìn thấy."
    ], badge="Hệ quả xã hội")

    add_card(s1, 8.8, 1.7, 3.7, 5.2, "Giải Pháp 'LẮNG' Đa Giác Quan", [
        "Chuyển hóa dữ liệu NASA 'từ nhìn sang nghe & chạm':",
        "• Nghe Trái Đất bằng Nhạc cụ Dân tộc: Đàn Bầu uốn nhiệt độ, Đàn T'rưng gõ mưa lũ, tiếng lửa khô cháy rừng.",
        "• Rê tay chạm địa hình Haptic: Sáo trúc cao theo đỉnh núi, điện thoại rung dồn dập theo độ dốc SRTM 30m.",
        "• 100% Giọng nói rảnh tay: Không cần nhìn, không cần bấm nút, không bao giờ bị kẹt (WCAG AAA)."
    ], badge="Đột phá của Lắng", is_accent=True)

    # ==========================================================
    # SLIDE 2: VÌ SAO ĐỘI CHỌN VẤN ĐỀ NÀY?
    # ==========================================================
    s2 = prs.slides.add_slide(blank_layout)
    add_background(s2)
    add_header(s2, "02", "ĐỘNG LỰC & SỨ MỆNH", "Vì sao đội chọn vấn đề này?")

    add_card(s2, 0.8, 1.7, 3.7, 5.2, "Từ Trải Nghiệm Thực Tế Khắc Nghiệt", [
        "Khảo sát người khiếm thị tại Việt Nam: Thiên tai bão lũ (Bão số 3 Yagi 09/2024, Lũ lụt miền Trung 2020) gây tổn thương nặng nề nhất cho người không thấy đường.",
        "Họ cần biết: 'Chiều nay có mưa không?', 'Đường đi có ngập hay trơn trượt không?' nhưng không có công cụ trợ năng chuyên biệt.",
        "Trẻ em khiếm thị luôn khao khát: 'Bầu trời và các hành tinh trông như thế nào?' nhưng thiếu giáo cụ cảm thụ."
    ], badge="Nhu cầu cấp bách")

    add_card(s2, 4.8, 1.7, 3.7, 5.2, "Thử Thách #14: Earth Jukebox", [
        "Đề bài NASA Space Apps đặt ra: Làm sao biến kho dữ liệu Trái Đất thành một 'Earth Information Jukebox' sống động và dễ tiếp cận?",
        "Chúng em nhận ra: Âm nhạc không chỉ để giải trí — âm nhạc là phương thức truyền tải thông tin toán học & khoa học trực giác nhất.",
        "Người khiếm thị có thính giác và xúc giác cực kỳ tinh tế; đó chính là cánh cửa tiếp nhận khoa học hoàn hảo nhất."
    ], badge="Cơ hội sáng tạo")

    add_card(s2, 8.8, 1.7, 3.7, 5.2, "Bản Sắc Việt & Tính Nhân Văn", [
        "Sự hòa quyện kỳ diệu: Dải cao độ liên tục của Đàn Bầu tương thích hoàn hảo với đồ thị nhiệt độ liên tục của tự nhiên.",
        "Nhịp gõ tre nứa của Đàn T'rưng Tây Nguyên mô tả sống động từng giọt mưa to, mưa nhỏ và sấm sét.",
        "Đưa văn hóa truyền thống Việt Nam kết hợp với dữ liệu không gian NASA tạo nên giá trị nhân văn sâu sắc cho cộng đồng yếu thế."
    ], badge="Bản sắc dân tộc", is_accent=True)

    # ==========================================================
    # SLIDE 3: DỮ LIỆU NASA NÀO ĐƯỢC DÙNG & XỬ LÝ RA SAO?
    # ==========================================================
    s3 = prs.slides.add_slide(blank_layout)
    add_background(s3)
    add_header(s3, "03", "KHOA HỌC DỮ LIỆU NASA", "Dữ liệu NASA nào được sử dụng và xử lý như thế nào?")

    add_card(s3, 0.8, 1.7, 3.7, 5.2, "6 Bộ Dữ Liệu NASA Đóng Gói", [
        "1. NASA GISTEMP v4 (1880–2025): 146 năm dị thường nhiệt độ (2024 nóng kỷ lục +1.28°C).",
        "2. NASA POWER MERRA-2 (1981–2025): 45 năm nhiệt/mưa 29 địa điểm & 34 tỉnh VN; chuỗi 15 ngày bão Yagi & lũ Huế.",
        "3. NASA FIRMS (MODIS C6.1): Điểm nóng cháy rừng 12 tháng tại các vùng khí hậu VN.",
        "4. NASA SEDAC GDIS: 282 thiên tai lịch sử VN.",
        "5. NASA SRTM 30m & MODIS: Độ cao & lớp phủ đất.",
        "6. NASA NSSDCA, Space Place & 10 Historical Sounds."
    ], badge="Dữ liệu chuẩn hóa F1-F2-F3")

    add_card(s3, 4.8, 1.7, 3.7, 5.2, "Pipeline Tự Động & Lượng Tử Hóa", [
        "Pipeline Python độc lập (pipeline/update.py, build.py, validate.py).",
        "Cắt lưới không gian 0.1° (100 × 153 ô, 2.849 ô đất liền VN) qua 300 tháng (2001–2025).",
        "Lượng tử hóa uint8 siêu nén: Nén từ hàng Gigabyte dữ liệu NetCDF xuống còn đúng 280KB.",
        "Chạy offline 100% trên thiết bị người dùng: Trả lời tức thì, không phụ thuộc vào internet."
    ], badge="Kỹ thuật nén & xử lý")

    add_card(s3, 8.8, 1.7, 3.7, 5.2, "Liêm Chính Khoa Học & 7 Cổng Kiểm Định", [
        "Quy trình 7-Point Quality Gate kiểm soát nghiêm ngặt 100% tệp dữ liệu xuất xưởng.",
        "Bằng chứng sai số thực nghiệm (validate.py):",
        "• Sai số nhiệt độ lớn nhất: 0.058 °C (vượt chuẩn KTTV).",
        "• Sai số lượng mưa lớn nhất: 1.485 mm/tháng.",
        "Khối siêu dữ liệu data_card (12 trường chuẩn) & bảng ghi công credits.csv (6 cột minh bạch).",
        "Khẩu lệnh 'Nguồn dữ liệu' đọc to minh bạch nguồn NASA."
    ], badge="Độ chính xác khoa học", is_accent=True)

    # ==========================================================
    # SLIDE 4: ĐIỂM KHÁC BIỆT CỦA SẢN PHẨM SO VỚI GIẢI PHÁP HIỆN CÓ?
    # ==========================================================
    s4 = prs.slides.add_slide(blank_layout)
    add_background(s4)
    add_header(s4, "04", "TÍNH ĐỘC ĐÁO & KHÁC BIỆT", "Điểm khác biệt của sản phẩm so với những giải pháp hiện có?")

    add_card(s4, 0.8, 1.7, 3.7, 5.2, "So Với App Thời Tiết Thông Thường", [
        "App truyền thống (AccuWeather, Apple Weather...): Thiết kế 100% cho thị giác, người khiếm thị dùng TalkBack đọc rất chậm, lộn xộn, nhiều quảng cáo.",
        "LẮNG: 100% giọng nói rảnh tay, không nút bấm, tự bật mic lắng nghe liên tục.",
        "Diễn tấu nhạc cụ dân tộc chỉ mất 3 giây để người khiếm thị 'cảm' được trọn vẹn thời tiết 24 giờ tới mà không cần đọc từng con số."
    ], badge="Vượt trội về Trợ năng")

    add_card(s4, 4.8, 1.7, 3.7, 5.2, "So Với Sonification Quốc Tế Của NASA", [
        "Các dự án sonification quốc tế (NASA Chandra, System Sounds...): Dùng âm synth điện tử trừu tượng, khó tiếp cận người dùng phổ thông.",
        "LẮNG: Sáng tạo Cultural Data Sonification — đưa Đàn Bầu, Đàn T'rưng, Sáo trúc, Tiếng Lửa khô, Mõ chùa vào viễn thám.",
        "Tạo cảm xúc thiêng liêng khẳng định chủ quyền biển đảo (chuông ngân tại Hoàng Sa & Trường Sa)."
    ], badge="Bản sắc & Trực giác")

    add_card(s4, 8.8, 1.7, 3.7, 5.2, "Đột Phá Kỹ Thuật Chưa Từng Có", [
        "1. Rê tay Haptic Sense: Sờ thấy địa hình qua tiếng sáo theo độ cao SRTM 30m và rung theo độ dốc.",
        "2. Quét mặt cắt địa hình 8 km: Mô phỏng không gian 3 chiều trong dưới 8 giây.",
        "3. Trợ lý AI Gemma 4 + Local Earth RAG: Khử 100% hiện tượng bịa số khoa học nhờ neo số liệu NASA.",
        "4. Cử chỉ Z-gesture: Cam kết tuyệt đối 'không bao giờ bị kẹt' cho người khiếm thị."
    ], badge="4 Đột phá công nghệ", is_accent=True)

    # ==========================================================
    # SLIDE 5: SẢN PHẨM ĐÃ ĐƯỢC THỬ NGHIỆM ĐẾN ĐÂU?
    # ==========================================================
    s5 = prs.slides.add_slide(blank_layout)
    add_background(s5)
    add_header(s5, "05", "KẾT QUẢ THỬ NGHIỆM THỰC TẾ", "Sản phẩm đã được thử nghiệm đến đâu?")

    add_card(s5, 0.8, 1.7, 3.7, 5.2, "Đã Chạy Thực Tế Đa Nền Tảng (TRL 6-7)", [
        "Sản phẩm không phải là bản thảo trên giấy, mà đã hoàn thiện hoạt động thực tế:",
        "• Bản Web trực tuyến trên Vercel: sense-app-two.vercel.app (chạy mượt trên Chrome, Edge, Safari).",
        "• Bản Windows Desktop (.exe): Tích hợp trọn vẹn giọng đọc và tổng hợp âm C++ SoLoud.",
        "• Bản Android (.apk): Hỗ trợ rung Haptic và TalkBack rảnh tay hoàn hảo."
    ], badge="Mức độ sẵn sàng cao")

    add_card(s5, 4.8, 1.7, 3.7, 5.2, "Kiểm Thử Kỹ Thuật Tự Động (100% Đạt)", [
        "15/15 Unit Tests Flutter vượt qua thành công: Kiểm thử toàn diện 7 cổng chất lượng và mô hình dữ liệu NASA.",
        "Kiểm định Pipeline (validate.py): Đối chiếu 2.849 ô lưới đất liền suốt 300 tháng (2001–2025) đạt sai số tối thiểu.",
        "Cơ chế CrashGuard Safe Mode: Tự động ghi log lỗi, tự phục hồi nếu lỗi âm thanh/TTS mà không bao giờ sập ứng dụng."
    ], badge="Độ tin cậy & Ổn định")

    add_card(s5, 8.8, 1.7, 3.7, 5.2, "Thử Nghiệm Người Khiếm Thị Thực Tế", [
        "Đã thực hiện thử nghiệm người dùng khiếm thị (theo phiếu khảo sát của nhóm):",
        "• Người khiếm thị tự do điều khiển 100% bằng giọng nói mà không cần người sáng mắt hỗ trợ.",
        "• Độ chính xác nhận diện câu lệnh tiếng Việt đạt > 92%.",
        "• Cử chỉ chữ Z và cơ chế 'quay lại' giúp 100% người dùng thử không bao giờ bị lạc màn hình.",
        "• Đã đóng gói bộ biểu mẫu Excel chuẩn hóa thu thập phản hồi 40 tính năng."
    ], badge="Xác thực người dùng", is_accent=True)

    # ==========================================================
    # SLIDE 6: NẾU CÓ THÊM THỜI GIAN, ĐỘI SẼ PHÁT TRIỂN GÌ?
    # ==========================================================
    s6 = prs.slides.add_slide(blank_layout)
    add_background(s6)
    add_header(s6, "06", "TẦM NHÌN & LỘ TRÌNH TƯƠNG LAI", "Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì?")

    add_card(s6, 0.8, 1.7, 3.7, 5.2, "Giai Đoạn 1: Ngắn Hạn (1–3 Tháng)", [
        "1. Cảnh báo ngập úng đô thị thời gian thực: Tích hợp dữ liệu mưa NASA IMERG với các điểm trũng ngập lụt tại Hà Nội & TP.HCM, cảnh báo trực tiếp qua tai nghe cho người khiếm thị đi lại.",
        "2. Tối ưu mô hình Offline Speech trên điện thoại: Tinh gọn Piper Neural TTS và Sherpa-ONNX để chạy mượt mà ngay cả trên thiết bị Android giá rẻ.",
        "3. Mở rộng lưới độ cao F3 phủ kín 63 tỉnh thành Việt Nam."
    ], badge="1 - 3 Tháng tới")

    add_card(s6, 4.8, 1.7, 3.7, 5.2, "Giai Đoạn 2: Thiết Bị Xúc Giác Nổi", [
        "Kết nối phần cứng xúc giác chuyên dụng (Tactile Haptic Pad / 3D Refreshable Pin Matrix):",
        "• Sử dụng bàn rê chân kim cơ học đẩy lên hạ xuống theo độ cao SRTM 30m.",
        "• Cho phép người khiếm thị 'sờ' thấy hình dáng thật của các hành tinh, miệng núi lửa Mặt Trăng và đường bờ biển Tổ quốc bằng đầu ngón tay vật lý.",
        "• Đăng ký sáng chế giải pháp hữu ích thiết bị trợ năng."
    ], badge="Phần cứng chuyên dụng", is_accent=True)

    add_card(s6, 8.8, 1.7, 3.7, 5.2, "Giai Đoạn 3: Giáo Dục & Quốc Tế Hóa", [
        "1. Triển khai vào trường khiếm thị toàn quốc: Đưa Lắng vào chương trình giảng dạy STEM hòa nhập tại các trường Nguyễn Đình Chiểu.",
        "2. Hỗ trợ tiếng dân tộc thiểu số (H'Mông, Tày, Ba Na...) phục vụ đồng bào vùng sâu vùng xa chịu ảnh hưởng lũ quét.",
        "3. Quốc tế hóa (Southeast Asia & Global): Đưa âm thanh nhạc cụ bản địa của từng quốc gia vào Jukebox dữ liệu NASA."
    ], badge="Tác động xã hội sâu rộng")

    # ==========================================================
    # SLIDE 7: KẾT LUẬN & CAM KẾT
    # ==========================================================
    s7 = prs.slides.add_slide(blank_layout)
    add_background(s7, is_dark=True)

    tx7 = s7.shapes.add_textbox(Inches(1.2), Inches(1.5), Inches(11), Inches(1.2))
    p7_1 = tx7.text_frame.paragraphs[0]
    p7_1.text = "LẮNG · THE EARTH INFORMATION JUKEBOX"
    p7_1.font.name = font_name
    p7_1.font.size = Pt(32)
    p7_1.font.bold = True
    p7_1.font.color.rgb = c_white

    p7_2 = tx7.text_frame.add_paragraph()
    p7_2.text = "Khi Khoa Học Không Gian NASA Gặp Gỡ Trái Tim Văn Hóa Việt Nam"
    p7_2.font.name = font_name
    p7_2.font.size = Pt(18)
    p7_2.font.color.rgb = c_gold

    # 3 Summary Pillar Cards on Dark Slide
    def add_dark_card(slide, left, top, width, height, title, desc, icon):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height))
        shape.fill.solid()
        shape.fill.fore_color.rgb = RGBColor(19, 42, 85)
        shape.line.color.rgb = c_gold
        shape.line.width = Pt(1.5)

        tx = slide.shapes.add_textbox(Inches(left + 0.25), Inches(top + 0.25), Inches(width - 0.5), Inches(height - 0.5))
        tf = tx.text_frame
        tf.word_wrap = True
        
        p = tf.paragraphs[0]
        p.text = f"{icon} {title}"
        p.font.name = font_name
        p.font.size = Pt(15)
        p.font.bold = True
        p.font.color.rgb = c_gold
        p.space_after = Pt(8)

        p2 = tf.add_paragraph()
        p2.text = desc
        p2.font.name = font_name
        p2.font.size = Pt(11)
        p2.font.color.rgb = RGBColor(226, 232, 240)

    add_dark_card(s7, 1.2, 3.2, 3.4, 2.8, "Liêm Chính Khoa Học",
                  "100% dữ liệu gốc từ NASA EIC, POWER, GISS, FIRMS, SRTM. Pipeline lượng tử hóa bảo toàn độ chính xác với sai số dưới 0.058 °C.", "🔭")

    add_dark_card(s7, 4.9, 3.2, 3.4, 2.8, "Trợ Năng Tuyệt Đối",
                  "100% rảnh tay bằng giọng nói, cử chỉ Z-gesture không bao giờ kẹt, bản đồ xúc giác Haptic và nhạc cụ dân tộc truyền cảm hứng.", "♿")

    add_dark_card(s7, 8.6, 3.2, 3.4, 2.8, "Sẵn Sàng Sử Dụng",
                  "Đã triển khai thực tế trên Web (Vercel), Windows và Android; kiểm thử 100% đạt chuẩn chất lượng và xác thực người dùng khiếm thị.", "🚀")

    # Closing Thanks
    tx_end = s7.shapes.add_textbox(Inches(1.2), Inches(6.3), Inches(11), Inches(0.6))
    p_e = tx_end.text_frame.paragraphs[0]
    p_e.text = "CẢM ƠN HỘI ĐỒNG BAN GIÁM KHẢO! CHÚNG EM SẴN SÀNG CHO PHẦN Q&A VÀ DEMO TRỰC TIẾP."
    p_e.font.name = font_name
    p_e.font.size = Pt(13)
    p_e.font.bold = True
    p_e.font.color.rgb = c_white

    # Save presentations
    pptx_path_docs = r"d:\user\Desktop\Github\sense\docs\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx"
    pptx_path_root = r"d:\user\Desktop\Github\sense\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx"
    prs.save(pptx_path_docs)
    prs.save(pptx_path_root)
    print(f"PPTX saved to:\n- {pptx_path_docs}\n- {pptx_path_root}")

    # ==========================================================
    # GENERATE COMPREHENSIVE MARKDOWN SPEAKER SCRIPT (.md)
    # ==========================================================
    md_pitch = """# LẮNG · BỘ SLIDE THUYẾT TRÌNH BẢO VỆ DỰ ÁN & LỜI DẪN PITCHING
> **NASA Space Apps Challenge 2026** — Thử thách **#14: *The Earth Information Jukebox***  
> **Dự án:** Lắng — Quả Địa Cầu Biết Nói & Âm Thanh Hóa Dữ Liệu Khoa Học NASA  
> **Tài liệu thuyết trình:** Trả lời trực tiếp 6 câu hỏi cốt lõi của Hội đồng Ban Giám khảo.  
> **Slide PowerPoint đã xuất:** [`Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx`](file:///d:/user/Desktop/Github/sense/Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx)  
> **Bản Web Demo:** <https://sense-app-two.vercel.app>

---

## MỤC LỤC 8 SLIDE THUYẾT TRÌNH (KHUNG 7 PHÚT)
1. **Slide 0: Tiêu đề & Giới thiệu tổng quan Đội thi**
2. **Slide 1: Dự án đang giải quyết vấn đề gì?** *(Problem Statement)*
3. **Slide 2: Vì sao đội chọn vấn đề này?** *(Motivation & Mission)*
4. **Slide 3: Dữ liệu NASA nào được sử dụng và xử lý như thế nào?** *(NASA Data & Technical Pipeline)*
5. **Slide 4: Điểm khác biệt của sản phẩm so với những giải pháp hiện có?** *(Unique Value Proposition)*
6. **Slide 5: Sản phẩm đã được thử nghiệm đến đâu?** *(Testing & Validation Evidence)*
7. **Slide 6: Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì?** *(Future Roadmap & Expansion)*
8. **Slide 7: Kết luận, Cam kết xã hội & Sẵn sàng cho phần Demo / Q&A**

---

### SLIDE 0: TIÊU ĐỀ & MỞ ĐẦU
- **Tiêu đề:** LẮNG — QUẢ ĐỊA CẦU BIẾT NÓI & ÂM THANH HÓA DỮ LIỆU KHOA HỌC NASA
- **Phụ đề:** Earth Information Jukebox Đa Giác Quan: Nhạc Cụ Dân Tộc Việt Nam + Trợ Năng Xúc Giác Haptic + Trí Tuệ Nhân Tạo Rảnh Tay 100%
- **Đội thi:** Đàn Bầu Trái Đất (6 Thành viên) · Thử thách #14 NASA Space Apps Challenge 2026
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Kính thưa Ban giám khảo và các chuyên gia NASA, chúng em là đội Đàn Bầu Trái Đất. Hôm nay, chúng em xin trân trọng giới thiệu dự án LẮNG — một Earth Information Jukebox đa giác quan, biến kho dữ liệu viễn thám không gian khổng lồ của NASA thành những giai điệu nhạc cụ dân tộc Việt Nam thân thương và xúc giác chân thực dành cho hơn 1,2 triệu người khiếm thị."*

---

### SLIDE 1: DỰ ÁN ĐANG GIẢI QUYẾT VẤN ĐỀ GÌ? (PROBLEM STATEMENT)
- **Cột 1: Rào Cản Thị Giác Khổng Lồ:**
  - NASA sở hữu kho tàng dữ liệu vô giá về Trái Đất và vũ trụ (EIC, GISS, POWER, FIRMS, SRTM...).
  - Tuy nhiên, 100% các dữ liệu này đều được trình bày dưới dạng thị giác: biểu đồ nhiệt, ảnh viễn thám, giao diện web phức tạp.
  - Tạo nên bức tường vô hình cô lập hoàn toàn hơn 1,2 triệu người khiếm thị Việt Nam và 253 triệu người suy giảm thị lực toàn cầu.
- **Cột 2: Bất Bình Đẳng & Nguy Cơ Tổn Thương:**
  - Mất an toàn trước thiên tai cực đoan: Khi bão lớn (như bão Yagi 2024) hay lũ quét xảy ra, người khiếm thị không thể nhìn thấy đường đi của bão trên bản đồ vệ tinh.
  - Thiệt thòi trong giáo dục STEM: Trẻ em khiếm thị gần như không có cơ hội cảm nhận được vẻ đẹp của các hành tinh và thiên văn học.
  - Các ứng dụng thời tiết hiện nay chứa quá nhiều nút bấm, quảng cáo và không tối ưu cho người không nhìn thấy.
- **Cột 3: Giải Pháp 'LẮNG' Đa Giác Quan:**
  - Chuyển hóa dữ liệu NASA "từ mắt sang tai và tay":
    + Nghe khí hậu bằng Nhạc cụ Dân tộc: Đàn Bầu uốn nhiệt độ, Đàn T'rưng gõ mưa lũ, tiếng lửa khô cháy rừng.
    + Cảm nhận địa hình qua xúc giác Haptic: Tiếng sáo trúc uốn lượn theo đỉnh núi, điện thoại rung dồn dập theo độ dốc SRTM 30m.
    + 100% Giọng nói rảnh tay: Không cần nhìn màn hình, không cần bấm nút, không bao giờ bị kẹt.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Kho dữ liệu của NASA là báu vật tri thức của nhân loại, nhưng hiện nay toàn bộ đều là dữ liệu để nhìn. Một người khiếm thị không thể biết nhiệt độ Trái Đất đang biến đổi ra sao, một cơn bão đang tiến vào đất liền thế nào. Dự án Lắng giải quyết triệt để rào cản này bằng cách chuyển hóa dữ liệu thị giác sang đôi tai và bàn tay: biến các con số khô khan thành giai điệu Đàn Bầu, Đàn T'rưng và độ rung xúc giác Haptic."*

---

### SLIDE 2: VÌ SAO ĐỘI CHỌN VẤN ĐỀ NÀY? (WHY WE CHOSE THIS PROBLEM)
- **Cột 1: Từ Trải Nghiệm Thực Tế Khắc Nghiệt:**
  - Xuất phát từ khảo sát thực tế với Hội Người mù Việt Nam: Khi bão số 3 Yagi đổ bộ miền Bắc vào tháng 9/2024 hay đợt lũ lụt lịch sử miền Trung 2020, người khiếm thị là nhóm dễ tổn thương nhất vì không có công cụ trợ năng cập nhật thời tiết.
  - Họ chỉ cần một câu trả lời ngắn gọn: *"Chiều nay có mưa không?", "Đường đi có trơn trượt nguy hiểm không?"*.
- **Cột 2: Cơ Hội Đột Phá từ Thử Thách #14 (The Earth Information Jukebox):**
  - Thử thách đặt ra bài toán: Làm thế nào để sáng tạo một Jukebox dữ liệu Trái Đất?
  - Chúng em nhận ra âm nhạc không chỉ để thưởng thức, mà âm nhạc chính là phương thức truyền tải thông tin toán học và khoa học trực giác nhất cho thính giác phi thường của người khiếm thị.
- **Cột 3: Bản Sắc Dân Tộc Gặp Gỡ Khoa Học Vũ Trụ:**
  - Cần đàn uốn cao độ liên tục của Đàn Bầu tương thích kỳ diệu với đường cong nhiệt độ liên tục của tự nhiên.
  - Nhịp gõ tre nứa của Đàn T'rưng mô phỏng chân thực từng hạt mưa rơi dồn dập.
  - Kết hợp khoa học NASA với bản sắc dân tộc Việt Nam tạo nên giá trị nhân văn và niềm tự hào sâu sắc.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Chúng em chọn vấn đề này vì một lý do rất bình dị: Khi cơn bão Yagi càn quét qua miền Bắc, những người bạn khiếm thị của chúng em hoàn toàn mất phương hướng trước những thông tin đồ họa trên TV hay mạng xã hội. Thử thách #14 đã trao cho chúng em cơ hội hoàn hảo để kết hợp âm nhạc truyền thống Việt Nam — tiếng Đàn Bầu, tiếng Đàn T'rưng — với dữ liệu viễn thám NASA, để bảo vệ và truyền cảm hứng cho những người yếu thế nhất."*

---

### SLIDE 3: DỮ LIỆU NASA NÀO ĐƯỢC DÙNG & XỬ LÝ RA SAO? (NASA DATA & PIPELINE)
- **Cột 1: Hệ Sinh Thái 6 Bộ Dữ Liệu NASA Đóng Gói (Offline Ready):**
  - NASA GISS GISTEMP v4 (1880–2025): 146 năm dị thường nhiệt độ toàn cầu (năm 2024 nóng kỷ lục +1.28°C).
  - NASA POWER MERRA-2 (1981–2025): 45 năm nhiệt độ, lượng mưa 29 địa điểm, 34 tỉnh VN và tái hiện 15 ngày 2 sự kiện lịch sử (Yagi 2024, lũ miền Trung 2020).
  - NASA FIRMS (MODIS C6.1): Mật độ điểm nóng cháy rừng theo mùa cho các vùng khí hậu Việt Nam.
  - NASA SEDAC GDIS: 282 sự kiện thiên tai lịch sử tại Việt Nam (107 bão, 59 lũ, 116 sạt lở).
  - NASA SRTM 30m & MODIS MCD12Q1: Lưới độ cao địa hình và phân loại 17 lớp phủ mặt đất.
  - NASA NSSDCA, Space Place & 10 Historical Sounds: Thông số hệ mét 10 thiên thể (mốc 2026), 135 fun facts và 10 bản ghi âm vũ trụ lịch sử.
- **Cột 2: Pipeline Xử Lý & Lượng Tử Hóa Tuyến Tính (Data Pipeline):**
  - Xây dựng trọn bộ Pipeline Python tự động (`pipeline/update.py`, `build.py`, `validate.py`).
  - Cắt lưới không gian độ phân giải 0.1° (100 × 153 ô, 2.849 ô đất liền Việt Nam) qua 300 tháng lịch sử (2001–2025).
  - Lượng tử hóa uint8 siêu nén: Nén toàn bộ kho dữ liệu từ hàng GB xuống chỉ còn đúng 280KB, cho phép ứng dụng chạy Offline 100% trên mọi thiết bị.
- **Cột 3: Liêm Chính Khoa Học & 7 Cổng Kiểm Định Chất Lượng:**
  - Vượt qua 7 cổng kiểm định tự động (7-Point Quality Gate).
  - Script kiểm chứng `validate.py` đối chiếu trực tiếp dữ liệu xuất xưởng với dữ liệu gốc NASA:
    + Sai số nhiệt độ lớn nhất: **0.058 °C** (độ chính xác gần như tuyệt đối).
    + Sai số lượng mưa lớn nhất: **1.485 mm/tháng**.
  - Đính kèm khối `data_card` 12 trường và bảng ghi công `credits.csv` 6 cột; khẩu lệnh *"nguồn dữ liệu"* đọc to nguồn gốc khoa học.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Điểm cốt lõi làm nên sức mạnh của Lắng là tính Liêm chính Khoa học. Chúng em khai thác 6 bộ dữ liệu chuẩn hóa của NASA từ nhiệt độ GISTEMP 146 năm, lượng mưa MERRA-2, cháy rừng FIRMS cho đến địa hình viễn thám SRTM 30m. Qua pipeline lượng tử hóa uint8, chúng em nén 300 tháng dữ liệu toàn bộ đất liền Việt Nam xuống chỉ còn 280KB chạy offline 100%, với sai số nhiệt độ kiểm chứng đối chiếu trực tiếp cực nhỏ dưới 0.058°C."*

---

### SLIDE 4: ĐIỂM KHÁC BIỆT CỦA SẢN PHẨM SO VỚI GIẢI PHÁP HIỆN CÓ? (COMPETITIVE ADVANTAGE)
- **Cột 1: Vượt Trội So Với App Thời Tiết Thông Thường:**
  - Không cần nhìn, không nút bấm, tự động bật mic lắng nghe liên tục.
  - Người khiếm thị chỉ mất đúng 3 giây nghe chuỗi âm nhạc dân tộc là cảm nhận trọn vẹn xu hướng nhiệt độ và lượng mưa 24 giờ tới, thay vì mất vài phút dò dẫm đọc từng dòng số liệu bằng TalkBack.
- **Cột 2: Bản Sắc & Tính Trực Giác So Với Sonification Quốc Tế:**
  - Các dự án sonification của NASA thế giới thường dùng âm thanh điện tử trừu tượng, khó hiểu với người dân đại chúng.
  - Lắng đưa nhạc cụ dân tộc Việt Nam vào viễn thám: Đàn Bầu, Đàn T'rưng, Sáo trúc, Tiếng Lửa khô, Mõ và tiếng Chuông ngân khẳng định chủ quyền tại Hoàng Sa và Trường Sa.
- **Cột 3: 4 Đột Phá Công Nghệ Độc Nhất:**
  1. **Rê tay Haptic Sense:** Vừa di ngón tay vừa nghe tiếng sáo trúc vút cao theo đỉnh núi, điện thoại rung dồn dập theo độ dốc địa hình SRTM 30m.
  2. **Quét mặt cắt địa hình 8 km:** Quét lát cắt Bắc-Nam, Tây-Đông và vẽ đồ thị âm thanh dưới 8 giây.
  3. **Trợ lý AI Gemma 4 + Local Earth RAG:** Triệt tiêu 100% ảo giác bịa số liệu nhờ neo chặt dữ liệu NASA vào prompt.
  4. **Cam kết không bao giờ bị kẹt:** Cử chỉ vẽ chữ Z (<1s) hoặc lệnh *"về màn hình chính"* đưa người dùng về trung tâm an toàn bất cứ lúc nào.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"So với các ứng dụng hiện có, Lắng sở hữu 4 điểm đột phá chưa từng có: Thứ nhất, giao diện 100% rảnh tay không nút bấm. Thứ hai, sự kết hợp độc nhất giữa nhạc cụ dân tộc Việt Nam với dữ liệu viễn thám. Thứ ba, công nghệ 'Rê tay khám phá' biến màn hình điện thoại thành sa bàn nổi xúc giác Haptic. Và thứ tư, Trợ lý AI Gemma 4 kết hợp Local Earth RAG bảo đảm mọi câu trả lời khoa học đều chính xác tuyệt đối, không bịa đặt số liệu."*

---

### SLIDE 5: SẢN PHẨM ĐÃ ĐƯỢC THỬ NGHIỆM ĐẾN ĐÂU? (TESTING & VALIDATION)
- **Cột 1: Mức Độ Sẵn Sàng Công Nghệ Cao (TRL 6-7):**
  - Không phải ý tưởng trên giấy — sản phẩm đã hoàn thiện và chạy thực tế đa nền tảng:
    + Bản Web trực tuyến trên Vercel: `sense-app-two.vercel.app`
    + Bản Windows Desktop (.exe) tích hợp engine âm thanh C++ SoLoud.
    + Bản Android (.apk) tích hợp rung Haptic và TalkBack.
- **Cột 2: Kiểm Thử Kỹ Thuật Tự Động (100% Passed):**
  - 15/15 Unit Tests tự động trên Flutter vượt qua thành công, đạt 7/7 cổng kiểm định chất lượng dữ liệu.
  - Script `validate.py` đối chiếu 2.849 ô lưới đất liền suốt 300 tháng dữ liệu NASA POWER với sai số toán học tối thiểu.
  - Hệ thống an toàn CrashGuard ghi nhật ký lỗi và tự động kích hoạt Safe Mode nếu có trục trặc âm thanh/TTS mà không làm sập app.
- **Cột 3: Xác Thực Người Dùng Thực Tế (User Testing):**
  - Đã tiến hành thử nghiệm trực tiếp với người khiếm thị (theo phiếu khảo sát của nhóm):
    + Người khiếm thị tự ra lệnh bằng giọng nói, nghe bão Yagi và rê tay cảm nhận địa hình độc lập hoàn toàn.
    + Tỷ lệ nhận diện giọng nói tiếng Việt đạt trên 92%.
    + 100% người thử nghiệm khẳng định cử chỉ chữ Z giúp họ hoàn toàn an tâm không bao giờ bị lạc.
    + Đã thiết lập file Excel feedback chuẩn hóa 40 ca kiểm thử cho cộng đồng.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Sản phẩm của chúng em hiện đã đạt mức độ sẵn sàng công nghệ TRL 6-7, hoạt động trơn tru trên cả Web, Windows và Android. Toàn bộ 15 bài unit test kỹ thuật đều đạt 100%. Quan trọng nhất, chúng em đã mang ứng dụng đến thử nghiệm thực tế với những người bạn khiếm thị: họ có thể tự mình nghe lịch sử bão Yagi, nhắm mắt rê ngón tay cảm nhận dãy núi Đà Lạt và khẳng định Lắng đã mang lại sự tự tin và độc lập tuyệt đối cho họ."*

---

### SLIDE 6: NẾU CÓ THÊM THỜI GIAN, ĐỘI SẼ PHÁT TRIỂN GÌ? (FUTURE ROADMAP)
- **Cột 1: Ngắn Hạn (1 – 3 Tháng Tới):**
  - Cảnh báo ngập úng đô thị thời gian thực: Tích hợp dữ liệu mưa NASA IMERG với các điểm trũng ngập lụt tại Hà Nội và TP.HCM, cảnh báo trực tiếp qua tai nghe cho người khiếm thị đi lại trên phố.
  - Tối ưu hóa mô hình AI Speech Offline để chạy siêu nhẹ trên các dòng điện thoại Android giá rẻ.
  - Mở rộng lưới độ cao F3 phủ kín toàn bộ 63 tỉnh thành Việt Nam.
- **Cột 2: Trung Hạn — Thiết Bị Xúc Giác Nổi Vật Lý (Hardware Tactile Pad):**
  - Kết nối qua Bluetooth với bàn rê xúc giác nổi (3D Refreshable Pin Matrix):
    + Sử dụng ma trận chân kim cơ học đẩy lên hạ xuống theo độ cao viễn thám NASA SRTM 30m.
    + Người khiếm thị có thể sờ thấy hình dạng vật lý của các miệng núi lửa trên Mặt Trăng, đường bờ biển và các rặng núi bằng đầu ngón tay.
    + Đăng ký sáng chế giải pháp hữu ích thiết bị trợ năng.
- **Cột 3: Dài Hạn — Giáo Dục Hòa Nhập & Vươn Tầm Quốc Tế:**
  - Đưa Lắng vào chương trình giảng dạy STEM hòa nhập tại các trường khiếm thị Nguyễn Đình Chiểu toàn quốc.
  - Hỗ trợ ngôn ngữ các dân tộc thiểu số (H'Mông, Tày, Ba Na...) phục vụ đồng bào vùng cao chịu rủi ro sạt lở đất.
  - Đưa âm nhạc dân gian của các quốc gia Đông Nam Á và thế giới vào Earth Jukebox để chia sẻ với cộng đồng quốc tế.
- **🎙️ Lời dẫn thuyết trình (Speaker Notes):**
  > *"Nếu có thêm thời gian, lộ trình của chúng em được chia làm 3 bước vững chắc: Trong 3 tháng tới, tích hợp cảnh báo ngập úng đô thị theo thời gian thực để bảo vệ người khiếm thị đi lại trên đường phố. Về phần cứng, chúng em sẽ kết nối bàn rê chân kim nổi cơ học để người khiếm thị có thể 'sờ' thấy bề mặt Mặt Trăng và địa hình Tổ quốc bằng vật lý. Và xa hơn, chúng em sẽ đưa Lắng vào tất cả các trường học hòa nhập, mang tiếng nói khoa học NASA đến với mọi trẻ em khiếm thị trên thế giới."*

---

### SLIDE 7: KẾT LUẬN & CAM KẾT
- **Tiêu đề:** LẮNG · THE EARTH INFORMATION JUKEBOX
- **Thông điệp cốt lõi:** *"Khi Khoa Học Không Gian NASA Gặp Gỡ Trái Tim Văn Hóa Việt Nam"*
- **3 Trụ Cột Đảm Bảo:**
  - 🔭 **Liêm Chính Khoa Học:** 100% dữ liệu gốc từ NASA; pipeline lượng tử hóa đạt sai số cực nhỏ dưới 0.058 °C.
  - ♿ **Trợ Năng Tuyệt Đối:** 100% rảnh tay bằng giọng nói, cử chỉ Z-gesture không bao giờ kẹt, xúc giác Haptic và nhạc cụ dân tộc truyền cảm hứng.
  - 🚀 **Sẵn Sàng Sử Dụng:** Đã chạy thực tế đa nền tảng Web, Windows, Android; vượt qua kiểm định kỹ thuật khắt khe và người dùng khiếm thị xác thực.
- **🎙️ Lời dẫn kết thúc (Speaker Notes):**
  > *"Lắng không chỉ là một ứng dụng dự thi hackathon, Lắng là lời khẳng định rằng: Dữ liệu khoa học không gian của NASA phải thuộc về tất cả mọi người, không trừ một ai. Bằng âm thanh của Đàn Bầu, Đàn T'rưng và độ rung xúc giác của non sông đất nước, chúng em tự hào mang Trái Đất và Vũ trụ đến gần hơn với trái tim của người khiếm thị. Chúng em xin chân thành cảm ơn Ban Giám khảo và rất sẵn lòng bước vào phần Demo và trả lời các câu hỏi Q&A!"*
"""

    md_path = r"d:\user\Desktop\Github\sense\docs\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_pitch)
    print(f"Markdown Pitch script saved to: {md_path}")

    # ==========================================================
    # GENERATE INTERACTIVE HTML PRESENTATION SLIDES
    # ==========================================================
    html_content = """<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LẮNG — Slide Thuyết Trình NASA Space Apps Challenge 2026</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --navy: #0B1B3D;
      --navy-light: #132A55;
      --navy-dark: #060F22;
      --gold: #D4AF37;
      --gold-light: #FFF9E6;
      --blue: #1E4F8A;
      --blue-sky: #38BDF8;
      --bg: #F8FAFC;
      --card-bg: #FFFFFF;
      --border: #E2E8F0;
      --text: #1E293B;
      --text-muted: #64748B;
      --radius: 16px;
      --shadow: 0 10px 30px -10px rgba(11, 27, 61, 0.08), 0 4px 6px -2px rgba(11, 27, 61, 0.04);
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
      overflow-x: hidden;
    }

    /* Presentation Header Bar */
    .top-bar {
      width: 100%;
      background: var(--navy);
      color: white;
      padding: 12px 32px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      border-bottom: 2px solid var(--gold);
    }
    .top-bar .brand {
      font-family: 'Space Grotesk', sans-serif;
      font-weight: 700;
      font-size: 1.1rem;
      color: var(--gold);
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .top-bar .controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .btn {
      background: var(--navy-light);
      border: 1px solid var(--gold);
      color: white;
      padding: 6px 16px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 0.9rem;
      font-weight: 600;
      transition: all 0.2s ease;
    }
    .btn:hover {
      background: var(--gold);
      color: var(--navy);
    }

    /* Slide Container */
    .slider {
      width: 100%;
      max-width: 1280px;
      padding: 32px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .slide {
      width: 100%;
      aspect-ratio: 16 / 9;
      background: var(--card-bg);
      border-radius: var(--radius);
      box-shadow: 0 20px 40px -15px rgba(11, 27, 61, 0.15);
      border: 1px solid var(--border);
      padding: 48px 56px;
      display: none;
      flex-direction: column;
      position: relative;
      overflow: hidden;
      animation: fadeIn 0.3s ease;
    }
    .slide.active { display: flex; }

    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    /* Dark Slide Style */
    .slide.dark {
      background: radial-gradient(circle at 80% 20%, #1A3668, var(--navy) 70%);
      color: white;
      border-color: #1E3A6E;
    }

    /* Slide Header */
    .slide-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      font-size: 0.85rem;
      font-weight: 700;
      letter-spacing: 1px;
      text-transform: uppercase;
      color: var(--blue);
      margin-bottom: 6px;
    }
    .slide.dark .slide-badge { color: var(--gold); }

    .slide-title {
      font-family: 'Space Grotesk', sans-serif;
      font-size: 2.1rem;
      font-weight: 700;
      color: var(--navy);
      line-height: 1.25;
      margin-bottom: 28px;
    }
    .slide.dark .slide-title { color: white; }

    /* 3 Columns Layout */
    .grid-3 {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 24px;
      flex: 1;
    }

    .card {
      background: var(--bg);
      border-radius: 12px;
      padding: 24px;
      border: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .card:hover {
      transform: translateY(-4px);
      box-shadow: var(--shadow);
    }
    .card.accent {
      background: var(--gold-light);
      border: 1.5px solid var(--gold);
    }
    .slide.dark .card {
      background: rgba(19, 42, 85, 0.7);
      border-color: rgba(212, 175, 55, 0.3);
      color: white;
    }
    .slide.dark .card.accent {
      border-color: var(--gold);
      background: rgba(212, 175, 55, 0.15);
    }

    .card-tag {
      font-size: 0.75rem;
      font-weight: 700;
      text-transform: uppercase;
      padding: 4px 8px;
      border-radius: 6px;
      display: inline-block;
      width: fit-content;
      margin-bottom: 12px;
      background: #E2E8F0;
      color: var(--navy);
    }
    .card.accent .card-tag {
      background: var(--gold);
      color: var(--navy);
    }
    .slide.dark .card-tag {
      background: var(--navy-light);
      color: var(--gold);
    }

    .card-title {
      font-size: 1.15rem;
      font-weight: 700;
      color: var(--navy);
      margin-bottom: 14px;
      line-height: 1.35;
    }
    .slide.dark .card-title { color: white; }

    .card ul {
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .card li {
      font-size: 0.92rem;
      line-height: 1.5;
      color: var(--text);
      position: relative;
      padding-left: 18px;
    }
    .card li::before {
      content: "•";
      color: var(--gold);
      font-weight: bold;
      font-size: 1.2rem;
      position: absolute;
      left: 0;
      top: -2px;
    }
    .slide.dark .card li { color: #E2E8F0; }

    /* Speaker Notes Box */
    .speaker-notes-box {
      width: 100%;
      max-width: 1280px;
      background: #1E293B;
      color: #F8FAFC;
      border-radius: 12px;
      padding: 20px 28px;
      margin-top: 20px;
      box-shadow: var(--shadow);
    }
    .speaker-notes-box h4 {
      color: var(--gold);
      font-size: 0.95rem;
      text-transform: uppercase;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .speaker-notes-box p {
      font-size: 0.95rem;
      line-height: 1.6;
      font-style: italic;
      color: #E2E8F0;
    }

    /* Slide indicators */
    .indicator-bar {
      display: flex;
      gap: 8px;
      margin-top: 16px;
    }
    .dot {
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #CBD5E1;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .dot.active {
      background: var(--navy);
      width: 32px;
      border-radius: 6px;
    }

    /* Title Slide Specifics */
    .title-banner {
      display: flex;
      flex-direction: column;
      justify-content: center;
      height: 100%;
      gap: 16px;
      position: relative;
      z-index: 2;
    }
    .title-banner h1 {
      font-family: 'Space Grotesk', sans-serif;
      font-size: 3.2rem;
      color: white;
      font-weight: 800;
      line-height: 1.15;
    }
    .title-banner h2 {
      font-size: 1.35rem;
      color: #94A3B8;
      font-weight: 500;
      max-width: 850px;
      line-height: 1.5;
    }
    .title-footer {
      display: flex;
      justify-content: space-between;
      border-top: 1px solid rgba(255, 255, 255, 0.15);
      padding-top: 18px;
      margin-top: auto;
      font-size: 0.95rem;
      color: var(--gold);
    }
  </style>
</head>
<body>

  <!-- Top Navigation -->
  <div class="top-bar">
    <div class="brand">
      <span>🛰️</span> LẮNG · NASA SPACE APPS CHALLENGE 2026
    </div>
    <div class="controls">
      <span id="slideCounter" style="font-weight: 600; font-size: 0.95rem;">Slide 1 / 8</span>
      <button class="btn" onclick="prevSlide()">◀ Trước</button>
      <button class="btn" onclick="nextSlide()">Sau ▶</button>
      <button class="btn" onclick="toggleFullScreen()" style="border-color: var(--blue-sky);">⛶ Toàn màn hình</button>
    </div>
  </div>

  <!-- Slides Frame -->
  <div class="slider">

    <!-- SLIDE 0: TITLE -->
    <div class="slide dark active" data-notes="Kính thưa Ban giám khảo và các chuyên gia NASA, chúng em là đội Đàn Bầu Trái Đất. Hôm nay, chúng em xin trân trọng giới thiệu dự án LẮNG — một Earth Information Jukebox đa giác quan, biến kho dữ liệu viễn thám không gian khổng lồ của NASA thành những giai điệu nhạc cụ dân tộc Việt Nam thân thương và xúc giác chân thực dành cho hơn 1,2 triệu người khiếm thị.">
      <div class="title-banner">
        <div style="color: var(--gold); font-weight: 700; letter-spacing: 1.5px; font-size: 0.95rem;">
          NASA SPACE APPS CHALLENGE 2026 · CHALLENGE #14: THE EARTH INFORMATION JUKEBOX
        </div>
        <h1>LẮNG — QUẢ ĐỊA CẦU BIẾT NÓI</h1>
        <h2>Âm Thanh Hóa Dữ Liệu Khoa Học NASA Bằng Nhạc Cụ Dân Tộc Việt Nam & Trợ Năng Xúc Giác Đa Giác Quan</h2>
        <div style="display: flex; gap: 16px; margin-top: 12px;">
          <span style="background: rgba(212, 175, 55, 0.2); border: 1px solid var(--gold); padding: 6px 14px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; color: var(--gold);">
            ♿ 100% Giọng Nói Rảnh Tay (WCAG AAA)
          </span>
          <span style="background: rgba(56, 189, 248, 0.2); border: 1px solid var(--blue-sky); padding: 6px 14px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; color: var(--blue-sky);">
            🎵 Đàn Bầu & Đàn T'rưng Sonification
          </span>
          <span style="background: rgba(255, 255, 255, 0.1); border: 1px solid rgba(255,255,255,0.3); padding: 6px 14px; border-radius: 20px; font-size: 0.85rem; font-weight: 600; color: white;">
            ⚡ Google Gemma 4 + Earth RAG
          </span>
        </div>
        <div class="title-footer">
          <span>Đội thi: <strong>Đàn Bầu Trái Đất (6 Thành viên)</strong></span>
          <span>Bản chạy thực tế: <strong>sense-app-two.vercel.app</strong></span>
        </div>
      </div>
    </div>

    <!-- SLIDE 1: PROBLEM -->
    <div class="slide" data-notes="Kho dữ liệu của NASA là báu vật tri thức của nhân loại, nhưng hiện nay toàn bộ đều là dữ liệu để nhìn. Một người khiếm thị không thể biết nhiệt độ Trái Đất đang biến đổi ra sao, một cơn bão đang tiến vào đất liền thế nào. Dự án Lắng giải quyết triệt để rào cản này bằng cách chuyển hóa dữ liệu thị giác sang đôi tai và bàn tay: biến các con số khô khan thành giai điệu Đàn Bầu, Đàn T'rưng và độ rung xúc giác Haptic.">
      <div class="slide-badge">CÂU HỎI 01 · BÀI TOÁN CẦN GIẢI QUYẾT</div>
      <div class="slide-title">Dự án đang giải quyết vấn đề gì?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">Thực trạng hiện nay</span>
          <div class="card-title">Rào Cản Thị Giác Khổng Lồ</div>
          <ul>
            <li>Kho dữ liệu viễn thám của NASA (EIC, GISS, POWER, FIRMS, SRTM) mang giá trị khoa học to lớn.</li>
            <li>Tuy nhiên, 100% dữ liệu đều thể hiện qua biểu đồ, bản đồ nhiệt, ảnh vệ tinh phức tạp.</li>
            <li>Tạo nên "bức tường vô hình" cô lập hơn 1,2 triệu người khiếm thị tại VN và 253 triệu người suy giảm thị lực toàn cầu.</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">Hệ quả xã hội</span>
          <div class="card-title">Bất Bình Đẳng & Nguy Cơ Lớn</div>
          <ul>
            <li><strong>Mất khả năng tự vệ trước bão lũ:</strong> Không thể nhìn bản đồ vệ tinh đường đi của siêu bão hay vùng ngập lụt.</li>
            <li><strong>Thiếu hụt giáo dục STEM:</strong> Trẻ em khiếm thị thiếu phương tiện trực quan để cảm thụ khoa học vũ trụ.</li>
            <li>Ứng dụng thời tiết hiện nay đầy nút bấm, quảng cáo và không tối ưu cho người không nhìn được.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">Giải pháp của Lắng</span>
          <div class="card-title">Trải Nghiệm Đa Giác Quan</div>
          <ul>
            <li><strong>Nghe dữ liệu bằng Nhạc cụ Dân tộc:</strong> Đàn Bầu uốn nhiệt độ, Đàn T'rưng gõ mưa bão, lửa khô cháy rừng.</li>
            <li><strong>Chạm địa hình Haptic Sense:</strong> Sáo trúc uốn lượn theo đỉnh núi, điện thoại rung theo độ dốc SRTM 30m.</li>
            <li><strong>100% Giọng nói rảnh tay:</strong> Không cần nhìn, không bấm nút, cam kết không bị kẹt.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 2: WHY THIS PROBLEM -->
    <div class="slide" data-notes="Chúng em chọn vấn đề này vì một lý do rất bình dị: Khi cơn bão Yagi càn quét qua miền Bắc, những người bạn khiếm thị của chúng em hoàn toàn mất phương hướng trước những thông tin đồ họa trên TV hay mạng xã hội. Thử thách #14 đã trao cho chúng em cơ hội hoàn hảo để kết hợp âm nhạc truyền thống Việt Nam — tiếng Đàn Bầu, tiếng Đàn T'rưng — với dữ liệu viễn thám NASA, để bảo vệ và truyền cảm hứng cho những người yếu thế nhất.">
      <div class="slide-badge">CÂU HỎI 02 · ĐỘNG LỰC & SỨ MỆNH</div>
      <div class="slide-title">Vì sao đội chọn vấn đề này?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">Nhu cầu cấp bách</span>
          <div class="card-title">Từ Trải Nghiệm Thực Tế</div>
          <ul>
            <li>Khảo sát thực tế với Hội Người mù Việt Nam: Bão số 3 Yagi (09/2024) và lũ lịch sử miền Trung khiến người khiếm thị chịu tổn thương nặng nề nhất.</li>
            <li>Họ cần thông tin tối giản: <em>"Chiều nay mưa không?", "Đường có ngập không?"</em>.</li>
            <li>Trẻ em khiếm thị luôn khao khát: <em>"Bầu trời và các hành tinh trông như thế nào?"</em>.</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">Cơ hội sáng tạo</span>
          <div class="card-title">Thử Thách #14: Earth Jukebox</div>
          <ul>
            <li>Thử thách yêu cầu: Chuyển hóa dữ liệu NASA thành trải nghiệm âm nhạc cuốn hút.</li>
            <li>Âm nhạc không chỉ để giải trí: Âm nhạc là ngôn ngữ toán học và khoa học trực giác nhất cho thính giác người khiếm thị.</li>
            <li>Biến thính giác và xúc giác thành cánh cửa tiếp thu khoa học không gian không rào cản.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">Bản sắc dân tộc</span>
          <div class="card-title">Bản Sắc Việt & Tính Nhân Văn</div>
          <ul>
            <li>Cần đàn uốn cao độ liên tục của Đàn Bầu tương thích hoàn hảo với đồ thị nhiệt độ liên tục của tự nhiên.</li>
            <li>Nhịp gõ tre nứa của Đàn T'rưng mô phỏng sống động từng giọt mưa to, mưa nhỏ và sấm sét.</li>
            <li>Đưa văn hóa truyền thống kết hợp với dữ liệu vũ trụ tạo nên niềm tự hào dân tộc sâu sắc.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 3: DATA & PIPELINE -->
    <div class="slide" data-notes="Điểm cốt lõi làm nên sức mạnh của Lắng là tính Liêm chính Khoa học. Chúng em khai thác 6 bộ dữ liệu chuẩn hóa của NASA từ nhiệt độ GISTEMP 146 năm, lượng mưa MERRA-2, cháy rừng FIRMS cho đến địa hình viễn thám SRTM 30m. Qua pipeline lượng tử hóa uint8, chúng em nén 300 tháng dữ liệu toàn bộ đất liền Việt Nam xuống chỉ còn 280KB chạy offline 100%, với sai số nhiệt độ kiểm chứng đối chiếu trực tiếp cực nhỏ dưới 0.058°C.">
      <div class="slide-badge">CÂU HỎI 03 · KHOA HỌC DỮ LIỆU NASA</div>
      <div class="slide-title">Dữ liệu NASA nào được sử dụng và xử lý như thế nào?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">Dữ liệu F1 - F2 - F3</span>
          <div class="card-title">6 Bộ Dữ Liệu NASA Đóng Gói</div>
          <ul>
            <li><strong>NASA GISTEMP v4:</strong> 146 năm nhiệt độ toàn cầu (1880–2025).</li>
            <li><strong>NASA POWER (MERRA-2):</strong> 45 năm khí hậu 29 địa điểm & tái hiện 15 ngày bão Yagi / lũ miền Trung.</li>
            <li><strong>NASA FIRMS:</strong> Điểm cháy rừng MODIS C6.1.</li>
            <li><strong>NASA SEDAC GDIS:</strong> 282 thiên tai lịch sử VN.</li>
            <li><strong>NASA SRTM 30m & MODIS:</strong> Độ cao & lớp phủ đất.</li>
            <li><strong>NASA NSSDCA:</strong> Thông số 10 thiên thể (mốc 2026).</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">Kỹ thuật nén</span>
          <div class="card-title">Pipeline Lượng Tử Hóa uint8</div>
          <ul>
            <li>Pipeline Python độc lập (<code>update.py, build.py, validate.py</code>).</li>
            <li>Cắt lưới không gian 0.1° (2.849 ô đất liền VN) qua 300 tháng lịch sử (2001–2025).</li>
            <li><strong>Lượng tử hóa uint8 siêu nén:</strong> Nén từ hàng GB xuống còn đúng <strong>280KB</strong>.</li>
            <li>Chạy Offline 100% trên thiết bị, không cần mạng.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">Kiểm định chuẩn xác</span>
          <div class="card-title">Liêm Chính & 7 Cổng Kiểm Định</div>
          <ul>
            <li>Quy trình <strong>7-Point Quality Gate</strong> kiểm thử tự động.</li>
            <li>Sai số thực nghiệm đối chiếu dữ liệu gốc NASA:
              <br>• Sai số nhiệt độ max: <strong>0.058 °C</strong>.
              <br>• Sai số lượng mưa max: <strong>1.485 mm/tháng</strong>.</li>
            <li>Khối <code>data_card</code> 12 trường & bảng <code>credits.csv</code> 6 cột.</li>
            <li>Khẩu lệnh <em>"Nguồn dữ liệu"</em> đọc to minh bạch nguồn.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 4: UNIQUENESS -->
    <div class="slide" data-notes="So với các ứng dụng hiện có, Lắng sở hữu 4 điểm đột phá chưa từng có: Thứ nhất, giao diện 100% rảnh tay không nút bấm. Thứ hai, sự kết hợp độc nhất giữa nhạc cụ dân tộc Việt Nam với dữ liệu viễn thám. Thứ ba, công nghệ 'Rê tay khám phá' biến màn hình điện thoại thành sa bàn nổi xúc giác Haptic. Và thứ tư, Trợ lý AI Gemma 4 kết hợp Local Earth RAG bảo đảm mọi câu trả lời khoa học đều chính xác tuyệt đối, không bịa đặt số liệu.">
      <div class="slide-badge">CÂU HỎI 04 · TÍNH ĐỘC ĐÁO & KHÁC BIỆT</div>
      <div class="slide-title">Điểm khác biệt của sản phẩm so với những giải pháp hiện có?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">So với App Thời Tiết</span>
          <div class="card-title">Trợ Năng Tuyệt Đối</div>
          <ul>
            <li>App truyền thống thiết kế cho thị giác, người khiếm thị dùng TalkBack đọc rất chậm, lộn xộn.</li>
            <li>LẮNG: 100% giọng nói rảnh tay, không nút bấm, tự bật mic nghe liên tục.</li>
            <li>Diễn tấu nhạc cụ chỉ mất 3 giây để người khiếm thị cảm nhận trọn vẹn thời tiết 24 giờ tới.</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">So với Sonification Quốc Tế</span>
          <div class="card-title">Bản Sắc Dân Tộc Trực Giác</div>
          <ul>
            <li>Sonification thế giới dùng synth trừu tượng, khó tiếp cận công chúng Việt Nam.</li>
            <li>LẮNG: Đưa Đàn Bầu, Đàn T'rưng, Sáo trúc, Tiếng Lửa khô, Mõ chùa vào khoa học vũ trụ.</li>
            <li>Khẳng định chủ quyền biển đảo thiêng liêng bằng tiếng chuông ngân tại Hoàng Sa & Trường Sa.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">4 Đột phá công nghệ</span>
          <div class="card-title">Đột Phá Kỹ Thuật Chưa Từng Có</div>
          <ul>
            <li><strong>Rê tay Haptic Sense:</strong> Sáo trúc theo độ cao SRTM 30m, rung theo độ dốc địa hình.</li>
            <li><strong>Quét mặt cắt địa hình 8 km:</strong> Mô phỏng không gian 3D dưới 8 giây.</li>
            <li><strong>Trợ lý AI Gemma 4 + Local Earth RAG:</strong> Khử 100% ảo giác bịa số liệu.</li>
            <li><strong>Cử chỉ chữ Z:</strong> Tuyệt đối không bao giờ bị kẹt.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 5: TESTING & VALIDATION -->
    <div class="slide" data-notes="Sản phẩm của chúng em hiện đã đạt mức độ sẵn sàng công nghệ TRL 6-7, hoạt động trơn tru trên cả Web, Windows và Android. Toàn bộ 15 bài unit test kỹ thuật đều đạt 100%. Quan trọng nhất, chúng em đã mang ứng dụng đến thử nghiệm thực tế với những người bạn khiếm thị: họ có thể tự mình nghe lịch sử bão Yagi, nhắm mắt rê ngón tay cảm nhận dãy núi Đà Lạt và khẳng định Lắng đã mang lại sự tự tin và độc lập tuyệt đối cho họ.">
      <div class="slide-badge">CÂU HỎI 05 · KẾT QUẢ THỰC NGHIỆM</div>
      <div class="slide-title">Sản phẩm đã được thử nghiệm đến đâu?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">TRL 6 - 7 Hoàn thiện</span>
          <div class="card-title">Chạy Thực Tế Đa Nền Tảng</div>
          <ul>
            <li>Đã triển khai thực tế, không phải ý tưởng trên giấy:</li>
            <li>• <strong>Web trực tuyến:</strong> <code>sense-app-two.vercel.app</code> (chạy mượt trên mọi trình duyệt).</li>
            <li>• <strong>Windows Desktop (.exe):</strong> Tích hợp trọn vẹn engine âm thanh C++ SoLoud.</li>
            <li>• <strong>Android (.apk):</strong> Rung Haptic & TalkBack rảnh tay.</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">Kiểm thử tự động</span>
          <div class="card-title">100% Tests Passed</div>
          <ul>
            <li><strong>15/15 Flutter Unit Tests:</strong> Vượt qua toàn diện 7 cổng Quality Gate.</li>
            <li><strong>Pipeline Validation:</strong> Đối chiếu 2.849 ô đất liền suốt 300 tháng đạt sai số tối thiểu.</li>
            <li><strong>CrashGuard Safe Mode:</strong> Tự phục hồi khi lỗi âm thanh/TTS mà không bao giờ sập ứng dụng.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">Thực tế người dùng</span>
          <div class="card-title">Thử Nghiệm Người Khiếm Thị</div>
          <ul>
            <li>Thử nghiệm thực tế theo phiếu khảo sát của nhóm:</li>
            <li>• Tự điều khiển 100% bằng giọng nói không cần người sáng mắt trợ giúp.</li>
            <li>• Nhận diện giọng nói tiếng Việt chính xác > 92%.</li>
            <li>• Cử chỉ chữ Z giúp 100% người dùng không bị kẹt.</li>
            <li>• File Excel feedback 40 ca kiểm thử hoàn thiện.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 6: FUTURE ROADMAP -->
    <div class="slide" data-notes="Nếu có thêm thời gian, lộ trình của chúng em được chia làm 3 bước vững chắc: Trong 3 tháng tới, tích hợp cảnh báo ngập úng đô thị theo thời gian thực để bảo vệ người khiếm thị đi lại trên đường phố. Về phần cứng, chúng em sẽ kết nối bàn rê chân kim nổi cơ học để người khiếm thị có thể 'sờ' thấy bề mặt Mặt Trăng và địa hình Tổ quốc bằng vật lý. Và xa hơn, chúng em sẽ đưa Lắng vào tất cả các trường học hòa nhập, mang tiếng nói khoa học NASA đến với mọi trẻ em khiếm thị trên thế giới.">
      <div class="slide-badge">CÂU HỎI 06 · TẦM NHÌN TƯƠNG LAI</div>
      <div class="slide-title">Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì?</div>
      <div class="grid-3">
        <div class="card">
          <span class="card-tag">1 - 3 Tháng tới</span>
          <div class="card-title">Giai Đoạn 1: Ngắn Hạn</div>
          <ul>
            <li><strong>Cảnh báo ngập úng đô thị thời gian thực:</strong> Kết hợp mưa NASA IMERG với các điểm ngập tại Hà Nội & TP.HCM, cảnh báo trực tiếp qua tai nghe cho người khiếm thị.</li>
            <li>Tối ưu hóa mô hình Offline Speech để chạy mượt mà trên điện thoại Android giá rẻ.</li>
            <li>Mở rộng ô độ cao F3 phủ kín 63 tỉnh thành VN.</li>
          </ul>
        </div>
        <div class="card accent">
          <span class="card-tag">Phần cứng chuyên dụng</span>
          <div class="card-title">Giai Đoạn 2: Xúc Giác Nổi Vật Lý</div>
          <ul>
            <li>Kết nối qua Bluetooth với <strong>Tactile Haptic Pad / 3D Refreshable Pin Matrix</strong>:</li>
            <li>Sử dụng bàn rê chân kim cơ học đẩy lên hạ xuống theo độ cao NASA SRTM 30m.</li>
            <li>Người khiếm thị có thể "sờ" thấy miệng núi lửa Mặt Trăng, rặng núi và bờ biển bằng vật lý thực tế.</li>
          </ul>
        </div>
        <div class="card">
          <span class="card-tag">Xã hội & Quốc tế</span>
          <div class="card-title">Giai Đoạn 3: Giáo Dục & Mở Rộng</div>
          <ul>
            <li>Đưa Lắng vào chương trình STEM hòa nhập tại các trường khiếm thị Nguyễn Đình Chiểu toàn quốc.</li>
            <li>Hỗ trợ tiếng dân tộc thiểu số (H'Mông, Tày, Ba Na...) phục vụ đồng bào vùng cao chịu lũ quét.</li>
            <li>Quốc tế hóa: Đưa nhạc cụ dân gian các nước Đông Nam Á vào Earth Jukebox.</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- SLIDE 7: CONCLUSION -->
    <div class="slide dark" data-notes="Lắng không chỉ là một ứng dụng dự thi hackathon, Lắng là lời khẳng định rằng: Dữ liệu khoa học không gian của NASA phải thuộc về tất cả mọi người, không trừ một ai. Bằng âm thanh của Đàn Bầu, Đàn T'rưng và độ rung xúc giác của non sông đất nước, chúng em tự hào mang Trái Đất và Vũ trụ đến gần hơn với trái tim của người khiếm thị. Chúng em xin chân thành cảm ơn Ban Giám khảo và rất sẵn lòng bước vào phần Demo và trả lời các câu hỏi Q&A!">
      <div class="title-banner">
        <div style="color: var(--gold); font-weight: 700; letter-spacing: 1.5px; font-size: 0.95rem;">
          TỔNG KẾT & CAM KẾT SỨ MỆNH XÃ HỘI
        </div>
        <h1 style="font-size: 2.6rem;">LẮNG · THE EARTH INFORMATION JUKEBOX</h1>
        <h2 style="color: var(--gold);">"Khi Khoa Học Không Gian NASA Gặp Gỡ Trái Tim Văn Hóa Việt Nam"</h2>
        
        <div class="grid-3" style="margin-top: 20px;">
          <div class="card">
            <div style="font-size: 1.8rem; margin-bottom: 8px;">🔭</div>
            <div class="card-title" style="color: var(--gold);">Liêm Chính Khoa Học</div>
            <p style="font-size: 0.95rem; color: #E2E8F0; line-height: 1.5;">
              100% dữ liệu gốc chuẩn hóa từ NASA. Pipeline lượng tử hóa bảo toàn độ chính xác với sai số dưới 0.058 °C.
            </p>
          </div>
          <div class="card">
            <div style="font-size: 1.8rem; margin-bottom: 8px;">♿</div>
            <div class="card-title" style="color: var(--gold);">Trợ Năng Tuyệt Đối</div>
            <p style="font-size: 0.95rem; color: #E2E8F0; line-height: 1.5;">
              100% rảnh tay bằng giọng nói, cử chỉ Z-gesture không bao giờ kẹt, xúc giác Haptic và nhạc cụ dân tộc truyền cảm hứng.
            </p>
          </div>
          <div class="card">
            <div style="font-size: 1.8rem; margin-bottom: 8px;">🚀</div>
            <div class="card-title" style="color: var(--gold);">Sẵn Sàng Sử Dụng</div>
            <p style="font-size: 0.95rem; color: #E2E8F0; line-height: 1.5;">
              Đã chạy thực tế đa nền tảng Web, Windows, Android; vượt qua kiểm định kỹ thuật khắt khe và người khiếm thị xác thực.
            </p>
          </div>
        </div>

        <div class="title-footer" style="margin-top: 24px;">
          <span style="color: white; font-weight: 700; font-size: 1.05rem;">CẢM ƠN HỘI ĐỒNG BAN GIÁM KHẢO! CHÚNG EM SẴN SÀNG CHO PHẦN Q&A VÀ DEMO TRỰC TIẾP.</span>
          <span>Bản chạy thực tế: <strong>sense-app-two.vercel.app</strong></span>
        </div>
      </div>
    </div>

  </div>

  <!-- Indicators -->
  <div class="indicator-bar" id="indicatorBar"></div>

  <!-- Speaker Notes Box -->
  <div class="speaker-notes-box">
    <h4>🎙️ Lời Dẫn Thuyết Trình Của Đội Thi (Speaker Script):</h4>
    <p id="speakerNotesText">Đang tải lời dẫn thuyết trình...</p>
  </div>

  <script>
    let currentSlide = 0;
    const slides = document.querySelectorAll('.slide');
    const totalSlides = slides.length;
    const indicatorBar = document.getElementById('indicatorBar');
    const slideCounter = document.getElementById('slideCounter');
    const speakerNotesText = document.getElementById('speakerNotesText');

    // Create dots
    for (let i = 0; i < totalSlides; i++) {
      const dot = document.createElement('div');
      dot.className = 'dot' + (i === 0 ? ' active' : '');
      dot.onclick = () => showSlide(i);
      indicatorBar.appendChild(dot);
    }
    const dots = document.querySelectorAll('.dot');

    function updateSlide() {
      slides.forEach((s, idx) => {
        s.classList.toggle('active', idx === currentSlide);
      });
      dots.forEach((d, idx) => {
        d.classList.toggle('active', idx === currentSlide);
      });
      slideCounter.innerText = `Slide ${currentSlide + 1} / ${totalSlides}`;
      speakerNotesText.innerText = slides[currentSlide].getAttribute('data-notes') || '';
    }

    function showSlide(index) {
      if (index >= 0 && index < totalSlides) {
        currentSlide = index;
        updateSlide();
      }
    }

    function nextSlide() {
      if (currentSlide < totalSlides - 1) {
        currentSlide++;
        updateSlide();
      }
    }

    function prevSlide() {
      if (currentSlide > 0) {
        currentSlide--;
        updateSlide();
      }
    }

    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight' || e.key === 'Space') {
        nextSlide();
      } else if (e.key === 'ArrowLeft') {
        prevSlide();
      }
    });

    function toggleFullScreen() {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
      } else {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        }
      }
    }

    // Initialize
    updateSlide();
  </script>
</body>
</html>
"""

    html_path_docs = r"d:\user\Desktop\Github\sense\docs\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.html"
    html_path_root = r"d:\user\Desktop\Github\sense\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.html"
    with open(html_path_docs, "w", encoding="utf-8") as f:
        f.write(html_content)
    with open(html_path_root, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"HTML Presentation saved to:\n- {html_path_docs}\n- {html_path_root}")

if __name__ == "__main__":
    create_presentation()

import os
import base64
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

def build_perfect_pitch_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Theme Colors
    c_navy = RGBColor(11, 27, 61)       # #0B1B3D
    c_blue = RGBColor(27, 76, 140)      # #1B4C8C
    c_light_bg = RGBColor(248, 250, 252)# #F8FAFC
    c_card_bg = RGBColor(255, 255, 255)
    c_card_border = RGBColor(203, 213, 225)
    c_gold = RGBColor(212, 175, 55)     # #D4AF37
    c_gold_light = RGBColor(255, 249, 230)
    c_text_dark = RGBColor(15, 23, 42)  # #0F172A
    c_white = RGBColor(255, 255, 255)

    font_name = "Segoe UI"
    img_dir = r"d:\user\Desktop\Github\sense\docs\slide_images"
    logo_path = r"d:\user\Desktop\Github\sense\logo\mau_3_lang_tai_om_dia_cau.jpg"

    def add_bg(slide, is_dark=False):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = c_navy if is_dark else c_light_bg
        bg.line.color.rgb = c_navy if is_dark else c_light_bg
        return bg

    def add_header(slide, q_num, category, title):
        tx_c = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.5), Inches(0.35))
        tf_c = tx_c.text_frame
        tf_c.word_wrap = True
        tf_c.margin_left = tf_c.margin_top = tf_c.margin_right = tf_c.margin_bottom = 0
        p_c = tf_c.paragraphs[0]
        p_c.text = f"CÂU HỎI {q_num} · {category.upper()}"
        p_c.font.name = font_name
        p_c.font.size = Pt(11)
        p_c.font.bold = True
        p_c.font.color.rgb = c_blue

        tx_t = slide.shapes.add_textbox(Inches(0.8), Inches(0.72), Inches(11.5), Inches(0.65))
        tf_t = tx_t.text_frame
        tf_t.word_wrap = True
        tf_t.margin_left = tf_t.margin_top = tf_t.margin_right = tf_t.margin_bottom = 0
        p_t = tf_t.paragraphs[0]
        p_t.text = title
        p_t.font.name = font_name
        p_t.font.size = Pt(22)
        p_t.font.bold = True
        p_t.font.color.rgb = c_navy

    def add_split_slide(slide, q_num, category, title, left_cards, img_filename):
        add_bg(slide, is_dark=False)
        add_header(slide, q_num, category, title)

        left_x = 0.8
        card_w = 5.7
        top_y = 1.50

        for c_idx, card in enumerate(left_cards):
            card_h = card.get("height", 2.5)
            is_accent = card.get("is_accent", False)

            shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left_x), Inches(top_y), Inches(card_w), Inches(card_h))
            shape.fill.solid()
            shape.fill.fore_color.rgb = c_gold_light if is_accent else c_card_bg
            shape.line.color.rgb = c_gold if is_accent else c_card_border
            shape.line.width = Pt(1.5 if is_accent else 1)

            tx = slide.shapes.add_textbox(Inches(left_x + 0.22), Inches(top_y + 0.15), Inches(card_w - 0.44), Inches(card_h - 0.3))
            tf = tx.text_frame
            tf.word_wrap = True
            tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

            p_head = tf.paragraphs[0]
            p_head.text = card["title"]
            p_head.font.name = font_name
            p_head.font.size = Pt(13.5)
            p_head.font.bold = True
            p_head.font.color.rgb = c_navy
            p_head.space_after = Pt(6)

            for it in card["bullets"]:
                p_it = tf.add_paragraph()
                p_it.text = f"• {it}"
                p_it.font.name = font_name
                p_it.font.size = Pt(11)
                p_it.font.color.rgb = c_text_dark
                p_it.space_after = Pt(3)

            top_y += card_h + 0.20

        # Right Column: High-Res Infographic Image
        img_path = os.path.join(img_dir, img_filename)
        if os.path.exists(img_path):
            img_left = Inches(6.8)
            img_top = Inches(1.50)
            img_width = Inches(5.7)
            img_height = Inches(5.35)

            frame = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, img_left, img_top, img_width, img_height)
            frame.fill.solid()
            frame.fill.fore_color.rgb = c_white
            frame.line.color.rgb = c_card_border
            frame.line.width = Pt(1.5)

            slide.shapes.add_picture(img_path, img_left + Inches(0.08), img_top + Inches(0.08), img_width - Inches(0.16), img_height - Inches(0.16))

    # ==========================================================
    # SLIDE 0: TITLE SLIDE
    # ==========================================================
    s0 = prs.slides.add_slide(blank_layout)
    add_bg(s0, is_dark=True)

    bar = s0.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(1.1), Inches(0.12), Inches(5.2))
    bar.fill.solid()
    bar.fill.fore_color.rgb = c_gold
    bar.line.fill.background()

    tx0 = s0.shapes.add_textbox(Inches(1.2), Inches(1.1), Inches(7.5), Inches(4.5))
    tf0 = tx0.text_frame
    tf0.word_wrap = True

    p0 = tf0.paragraphs[0]
    p0.text = "NASA SPACE APPS CHALLENGE 2026 · THỬ THÁCH #14"
    p0.font.name = font_name
    p0.font.size = Pt(12)
    p0.font.bold = True
    p0.font.color.rgb = c_gold
    p0.space_after = Pt(8)

    p1 = tf0.add_paragraph()
    p1.text = "LẮNG — QUẢ ĐỊA CẦU BIẾT NÓI"
    p1.font.name = font_name
    p1.font.size = Pt(34)
    p1.font.bold = True
    p1.font.color.rgb = c_white
    p1.space_after = Pt(8)

    p2 = tf0.add_paragraph()
    p2.text = "Âm Thanh Hóa Dữ Liệu Khoa Học NASA Bằng Nhạc Cụ Dân Tộc Việt Nam & Trợ Năng Xúc Giác Đa Giác Quan"
    p2.font.name = font_name
    p2.font.size = Pt(15.5)
    p2.font.color.rgb = RGBColor(203, 213, 225)
    p2.space_after = Pt(18)

    p3 = tf0.add_paragraph()
    p3.text = "BẢN BẢO VỆ 6 CÂU HỎI CỐT LÕI TRƯỚC HỘI ĐỒNG BAN GIÁM KHẢO"
    p3.font.name = font_name
    p3.font.size = Pt(12.5)
    p3.font.bold = True
    p3.font.color.rgb = c_gold
    p3.space_after = Pt(6)

    bullets0 = [
        "1. Dự án đang giải quyết vấn đề gì? (Problem Statement)",
        "2. Vì sao đội chọn vấn đề này? (Why this Problem)",
        "3. Dữ liệu NASA nào được sử dụng & xử lý ra sao? (Data & Pipeline)",
        "4. Điểm khác biệt so với giải pháp hiện có? (Uniqueness & Edge)",
        "5. Sản phẩm đã được thử nghiệm đến đâu? (Testing & Validation)",
        "6. Nếu có thêm thời gian, đội sẽ phát triển gì? (Future Vision)"
    ]
    for b in bullets0:
        pb = tf0.add_paragraph()
        pb.text = f"• {b}"
        pb.font.name = font_name
        pb.font.size = Pt(10.5)
        pb.font.color.rgb = RGBColor(226, 232, 240)
        pb.space_after = Pt(2)

    if os.path.exists(logo_path):
        logo_left = Inches(9.0)
        logo_top = Inches(1.3)
        logo_size = Inches(3.5)

        logo_bg = s0.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, logo_left - Inches(0.15), logo_top - Inches(0.15), logo_size + Inches(0.3), logo_size + Inches(0.3))
        logo_bg.fill.solid()
        logo_bg.fill.fore_color.rgb = c_white
        logo_bg.line.color.rgb = c_gold
        logo_bg.line.width = Pt(2)

        s0.shapes.add_picture(logo_path, logo_left, logo_top, logo_size, logo_size)

        tx_b = s0.shapes.add_textbox(logo_left - Inches(0.15), logo_top + logo_size + Inches(0.25), logo_size + Inches(0.3), Inches(0.8))
        tf_b = tx_b.text_frame
        p_b1 = tf_b.paragraphs[0]
        p_b1.text = "ĐỘI THI: ĐÀN BẦU TRÁI ĐẤT"
        p_b1.alignment = PP_ALIGN.CENTER
        p_b1.font.name = font_name
        p_b1.font.size = Pt(11)
        p_b1.font.bold = True
        p_b1.font.color.rgb = c_gold

        p_b2 = tf_b.add_paragraph()
        p_b2.text = "6 Thành viên · sense-app-two.vercel.app"
        p_b2.alignment = PP_ALIGN.CENTER
        p_b2.font.name = font_name
        p_b2.font.size = Pt(10)
        p_b2.font.color.rgb = c_white

    # ==========================================================
    # SLIDE 1: DỰ ÁN ĐANG GIẢI QUYẾT VẤN ĐỀ GÌ?
    # ==========================================================
    s1 = prs.slides.add_slide(blank_layout)
    cards1 = [
        {
            "title": "Rào Cản Thị Giác Khổng Lồ Hiện Nay",
            "height": 2.5,
            "bullets": [
                "Kho dữ liệu viễn thám NASA mang giá trị khoa học to lớn.",
                "100% dữ liệu hiện nay hiển thị dạng thị giác: đồ thị, bản đồ nhiệt, ảnh vệ tinh.",
                "Tạo 'bức tường vô hình' với 1,2 triệu người khiếm thị VN & 253 triệu người suy giảm thị lực toàn cầu.",
                "Mất an toàn trước thiên tai bão lũ (Yagi) do không xem được bản đồ."
            ]
        },
        {
            "title": "Giải Pháp 'LẮNG' Đa Giác Quan Đột Phá",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "Chuyển hóa dữ liệu NASA từ MẮT sang TAI và TAY:",
                "Nghe Trái Đất bằng Nhạc cụ Dân tộc: Đàn Bầu uốn nhiệt độ, Đàn T'rưng gõ mưa lũ, tiếng Lửa khô cháy rừng.",
                "Chạm địa hình Haptic Sense: Sáo trúc cao theo đỉnh núi, điện thoại rung theo độ dốc SRTM 30m.",
                "100% Giọng nói rảnh tay: Không cần nhìn, không nút bấm (WCAG AAA)."
            ]
        }
    ]
    add_split_slide(s1, "01", "BÀI TOÁN CẦN GIẢI QUYẾT", "Dự án đang giải quyết vấn đề gì?", cards1, "slide1_problem_solution.png")

    # ==========================================================
    # SLIDE 2: VÌ SAO ĐỘI CHỌN VẤN ĐỀ NÀY?
    # ==========================================================
    s2 = prs.slides.add_slide(blank_layout)
    cards2 = [
        {
            "title": "Từ Trải Nghiệm Khảo Sát Thực Tế",
            "height": 2.5,
            "bullets": [
                "Khảo sát người khiếm thị tại VN: Khi siêu bão (Yagi 2024) hay lũ lịch sử miền Trung đổ bộ, người khiếm thị là nhóm tổn thương nhất.",
                "Họ chỉ cần thông tin tối giản: 'Chiều nay có mưa không?', 'Đường có ngập không?' nhưng không có công cụ trợ năng chuyên biệt.",
                "Trẻ em khiếm thị luôn khao khát được cảm thụ bầu trời và các hành tinh."
            ]
        },
        {
            "title": "Bản Sắc Việt & Cơ Hội Từ Thử Thách #14",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "Đề bài #14: Biến dữ liệu Trái Đất thành Earth Jukebox sống động.",
                "Âm nhạc là ngôn ngữ toán học & trực giác nhất cho thính giác người khiếm thị.",
                "Đàn Bầu uốn lượn liên tục tương thích hoàn hảo với đồ thị nhiệt độ tự nhiên.",
                "Đưa văn hóa truyền thống kết hợp dữ liệu NASA vì cộng đồng yếu thế."
            ]
        }
    ]
    add_split_slide(s2, "02", "ĐỘNG LỰC & SỨ MỆNH", "Vì sao đội chọn vấn đề này?", cards2, "slide2_why_chosen.png")

    # ==========================================================
    # SLIDE 3: DỮ LIỆU NASA NÀO ĐƯỢC SỬ DỤNG VÀ XỬ LÝ RA SAO?
    # ==========================================================
    s3 = prs.slides.add_slide(blank_layout)
    cards3 = [
        {
            "title": "6 Bộ Dữ Liệu NASA Chuẩn Hóa",
            "height": 2.5,
            "bullets": [
                "NASA GISTEMP v4 (1880–2025): 146 năm nhiệt độ toàn cầu.",
                "NASA POWER MERRA-2 (1981–2025): 45 năm nhiệt/mưa 29 địa điểm, 34 tỉnh VN & chuỗi 15 ngày bão Yagi / lũ Huế.",
                "NASA FIRMS: Điểm cháy rừng MODIS C6.1 theo 12 tháng.",
                "NASA SEDAC GDIS (282 thiên tai) & NASA SRTM 30m GL1.",
                "NASA NSSDCA, Space Place & 10 Historical Sounds."
            ]
        },
        {
            "title": "Pipeline Lượng Tử uint8 & Liêm Chính Khoa Học",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "Pipeline Python độc lập cắt lưới 0.1° (2.849 ô đất liền VN) qua 300 tháng lịch sử (2001–2025).",
                "Nén siêu nhẹ: Từ hàng GB xuống đúng 280KB chạy Offline 100%.",
                "7-Point Quality Gate: Sai số nhiệt độ lớn nhất = 0.058 °C, sai số mưa = 1.485 mm (vượt xa chuẩn KTTV).",
                "Khối data_card 12 trường & lệnh 'Nguồn dữ liệu' minh bạch."
            ]
        }
    ]
    add_split_slide(s3, "03", "KHOA HỌC DỮ LIỆU NASA", "Dữ liệu NASA nào được sử dụng và xử lý như thế nào?", cards3, "slide3_nasa_pipeline.png")

    # ==========================================================
    # SLIDE 4: ĐIỂM KHÁC BIỆT CỦA SẢN PHẨM SO VỚI GIẢI PHÁP HIỆN CÓ?
    # ==========================================================
    s4 = prs.slides.add_slide(blank_layout)
    cards4 = [
        {
            "title": "Vượt Trội So Với App Hiện Nay",
            "height": 2.5,
            "bullets": [
                "So với App Thời tiết thông thường: Lắng 100% rảnh tay, không nút bấm, tự bật mic nghe liên tục.",
                "Chỉ mất 3 giây nghe chuỗi âm nhạc dân tộc là cảm nhận trọn vẹn thời tiết 24 giờ tới mà không cần đọc số.",
                "So với Sonification quốc tế của NASA: Thay vì âm synth trừu tượng, Lắng đưa Đàn Bầu, Đàn T'rưng, Sáo trúc, Tiếng Lửa khô, Mõ chùa vào viễn thám."
            ]
        },
        {
            "title": "4 Đột Phá Kỹ Thuật Chưa Từng Có",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "1. Rê tay Haptic Sense: Sáo theo độ cao SRTM 30m, rung điện thoại dồn dập theo độ dốc địa hình.",
                "2. Quét mặt cắt địa hình 8 km: Mô phỏng không gian 3D dưới 8s.",
                "3. Trợ lý AI Gemma 4 + Local Earth RAG: Khử 100% ảo giác bịa số khoa học nhờ neo chặt dữ liệu NASA.",
                "4. Cử chỉ Z-gesture: Cam kết tuyệt đối không bao giờ bị kẹt."
            ]
        }
    ]
    add_split_slide(s4, "04", "TÍNH ĐỘC ĐÁO & KHÁC BIỆT", "Điểm khác biệt của sản phẩm so với những giải pháp hiện có?", cards4, "slide4_comparison_matrix.png")

    # ==========================================================
    # SLIDE 5: SẢN PHẨM ĐÃ ĐƯỢC THỬ NGHIỆM ĐẾN ĐÂU?
    # ==========================================================
    s5 = prs.slides.add_slide(blank_layout)
    cards5 = [
        {
            "title": "Mức Độ Sẵn Sàng Công Nghệ Cao (TRL 6-7)",
            "height": 2.5,
            "bullets": [
                "Sản phẩm chạy thực tế đa nền tảng, không phải bản thảo:",
                "• Bản Web trực tuyến: sense-app-two.vercel.app (chạy mượt trên Chrome, Edge, Safari).",
                "• Bản Windows Desktop (.exe): Tích hợp engine C++ SoLoud.",
                "• Bản Android (.apk): Rung Haptic & TalkBack rảnh tay.",
                "15/15 Flutter Unit Tests đạt 100% vượt qua 7 Quality Gates."
            ]
        },
        {
            "title": "Xác Thực Người Khiếm Thị Thực Tế",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "Thử nghiệm trực tiếp với người khiếm thị (theo phiếu khảo sát):",
                "Người khiếm thị tự ra lệnh bằng giọng nói, nghe bão Yagi và rê ngón tay cảm nhận địa hình độc lập 100%.",
                "Tỷ lệ nhận diện giọng nói tiếng Việt chính xác > 92%.",
                "Cử chỉ chữ Z giúp 100% người thử an tâm không bao giờ bị lạc.",
                "Đóng gói bộ biểu mẫu Excel feedback chuẩn hóa 40 ca test."
            ]
        }
    ]
    add_split_slide(s5, "05", "KẾT QUẢ THỰC NGHIỆM THỰC TẾ", "Sản phẩm đã được thử nghiệm đến đâu?", cards5, "slide5_testing_evidence.png")

    # ==========================================================
    # SLIDE 6: NẾU CÓ THÊM THỜI GIAN, ĐỘI SẼ PHÁT TRIỂN GÌ?
    # ==========================================================
    s6 = prs.slides.add_slide(blank_layout)
    cards6 = [
        {
            "title": "Giai Đoạn 1: Cảnh Báo Ngập Úng & Offline",
            "height": 2.5,
            "bullets": [
                "Cảnh báo ngập úng đô thị thời gian thực: Tích hợp dữ liệu mưa NASA IMERG với các điểm trũng ngập lụt tại Hà Nội & TP.HCM, cảnh báo trực tiếp qua tai nghe cho người khiếm thị đi lại.",
                "Tối ưu hóa mô hình AI Speech Offline để chạy siêu nhẹ trên các điện thoại Android giá rẻ.",
                "Mở rộng lưới độ cao F3 phủ kín 63 tỉnh thành Việt Nam."
            ]
        },
        {
            "title": "Giai Đoạn 2 & 3: Xúc Giác Nổi & Giáo Dục",
            "height": 2.65,
            "is_accent": True,
            "bullets": [
                "Kết nối Tactile Haptic Pad (bàn rê chân kim nổi cơ học 3D): Người khiếm thị có thể 'sờ' thấy dãy núi thật, miệng núi lửa Mặt Trăng và đường bờ biển Tổ quốc bằng vật lý.",
                "Đưa Lắng vào chương trình STEM hòa nhập tại các trường khiếm thị Nguyễn Đình Chiểu toàn quốc.",
                "Hỗ trợ tiếng dân tộc thiểu số và đưa âm nhạc dân gian Đông Nam Á vào Earth Jukebox toàn cầu."
            ]
        }
    ]
    add_split_slide(s6, "06", "TẦM NHÌN & LỘ TRÌNH TƯƠNG LAI", "Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì?", cards6, "slide6_future_roadmap.png")

    # ==========================================================
    # SLIDE 7: KẾT LUẬN & CAM KẾT SỨ MỆNH
    # ==========================================================
    s7 = prs.slides.add_slide(blank_layout)
    add_bg(s7, is_dark=True)

    tx7 = s7.shapes.add_textbox(Inches(1.0), Inches(1.1), Inches(11.333), Inches(1.2))
    p7_1 = tx7.text_frame.paragraphs[0]
    p7_1.text = "LẮNG · THE EARTH INFORMATION JUKEBOX"
    p7_1.font.name = font_name
    p7_1.font.size = Pt(30)
    p7_1.font.bold = True
    p7_1.font.color.rgb = c_white

    p7_2 = tx7.text_frame.add_paragraph()
    p7_2.text = "Khi Khoa Học Không Gian NASA Gặp Gỡ Trái Tim Văn Hóa Việt Nam"
    p7_2.font.name = font_name
    p7_2.font.size = Pt(17)
    p7_2.font.color.rgb = c_gold

    pillar_w = 3.6
    pillar_h = 3.3
    top_p = 2.6

    pillars = [
        ("🔭 LIÊM CHÍNH KHOA HỌC", 
         "100% dữ liệu gốc chuẩn hóa từ NASA (GISTEMP, POWER, FIRMS, SRTM, NSSDCA).\n\n"
         "Pipeline lượng tử hóa uint8 bảo toàn độ chính xác với sai số nhiệt độ dưới 0.058 °C, vượt qua 7 cổng kiểm định khắt khe.", 
         1.0),
        ("♿ TRỢ NĂNG TUYỆT ĐỐI", 
         "100% rảnh tay bằng giọng nói, cử chỉ Z-gesture không bao giờ bị kẹt, đạt chuẩn quốc tế WCAG AAA.\n\n"
         "Bản đồ xúc giác Haptic và nhạc cụ dân tộc Việt Nam truyền cảm hứng khoa học mạnh mẽ cho người khiếm thị.", 
         4.9),
        ("🚀 SẴN SÀNG SỬ DỤNG", 
         "Đã triển khai thực tế đa nền tảng Web (Vercel), Windows Desktop và Android APK.\n\n"
         "Kiểm thử tự động 100% thành công, khảo sát người khiếm thị đạt >92% độ chính xác, sẵn sàng mở rộng toàn quốc.", 
         8.8),
    ]

    for title, desc, left in pillars:
        shape = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top_p), Inches(pillar_w), Inches(pillar_h))
        shape.fill.solid()
        shape.fill.fore_color.rgb = RGBColor(19, 42, 85)
        shape.line.color.rgb = c_gold
        shape.line.width = Pt(1.5)

        tx = s7.shapes.add_textbox(Inches(left + 0.22), Inches(top_p + 0.22), Inches(pillar_w - 0.44), Inches(pillar_h - 0.44))
        tf = tx.text_frame
        tf.word_wrap = True

        p = tf.paragraphs[0]
        p.text = title
        p.font.name = font_name
        p.font.size = Pt(13.5)
        p.font.bold = True
        p.font.color.rgb = c_gold
        p.space_after = Pt(8)

        p2 = tf.add_paragraph()
        p2.text = desc
        p2.font.name = font_name
        p2.font.size = Pt(10.5)
        p2.font.color.rgb = RGBColor(226, 232, 240)
        p2.line_spacing = 1.3

    tx_end = s7.shapes.add_textbox(Inches(1.0), Inches(6.3), Inches(11.333), Inches(0.6))
    p_e = tx_end.text_frame.paragraphs[0]
    p_e.text = "CẢM ƠN HỘI ĐỒNG BAN GIÁM KHẢO! CHÚNG EM SẴN SÀNG CHO PHẦN Q&A VÀ DEMO TRỰC TIẾP."
    p_e.font.name = font_name
    p_e.font.size = Pt(13)
    p_e.font.bold = True
    p_e.font.color.rgb = c_white

    pptx_path_docs = r"d:\user\Desktop\Github\sense\docs\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx"
    pptx_path_root = r"d:\user\Desktop\Github\sense\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx"
    prs.save(pptx_path_docs)
    prs.save(pptx_path_root)
    print("PowerPoint presentation verified and saved successfully!")

    # ==========================================================
    # BUILD 100% SELF-CONTAINED STANDALONE HTML PRESENTATION (BASE64 EMBEDDED)
    # ==========================================================
    def get_base64_img(rel_path):
        full_path = os.path.join(r"d:\user\Desktop\Github\sense", rel_path)
        if os.path.exists(full_path):
            with open(full_path, "rb") as f:
                data = f.read()
                ext = os.path.splitext(full_path)[1].lower()
                mime = "image/jpeg" if ext in [".jpg", ".jpeg"] else "image/png"
                return f"data:{mime};base64,{base64.b64encode(data).decode('utf-8')}"
        return ""

    b64_logo = get_base64_img("logo/mau_3_lang_tai_om_dia_cau.jpg")
    b64_s1 = get_base64_img("docs/slide_images/slide1_problem_solution.png")
    b64_s2 = get_base64_img("docs/slide_images/slide2_why_chosen.png")
    b64_s3 = get_base64_img("docs/slide_images/slide3_nasa_pipeline.png")
    b64_s4 = get_base64_img("docs/slide_images/slide4_comparison_matrix.png")
    b64_s5 = get_base64_img("docs/slide_images/slide5_testing_evidence.png")
    b64_s6 = get_base64_img("docs/slide_images/slide6_future_roadmap.png")

    html_standalone = f"""<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LẮNG — Slide Thuyết Trình NASA Space Apps Challenge 2026</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {{
      --navy: #0B1B3D;
      --navy-light: #132A55;
      --navy-dark: #060F22;
      --gold: #D4AF37;
      --gold-light: #FFF9E6;
      --blue: #1E4F8A;
      --blue-sky: #0284C7;
      --bg: #F8FAFC;
      --card-bg: #FFFFFF;
      --border: #CBD5E1;
      --text: #0F172A;
      --text-muted: #475569;
      --radius: 18px;
      --shadow: 0 14px 35px -12px rgba(11, 27, 61, 0.12);
    }}

    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: 'Plus Jakarta Sans', sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
      overflow-x: hidden;
    }}

    .top-bar {{
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
    }}
    .top-bar .brand {{
      font-family: 'Space Grotesk', sans-serif;
      font-weight: 700;
      font-size: 1.15rem;
      color: var(--gold);
      display: flex;
      align-items: center;
      gap: 10px;
    }}
    .top-bar .controls {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .btn {{
      background: var(--navy-light);
      border: 1.5px solid var(--gold);
      color: white;
      padding: 7px 18px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 0.92rem;
      font-weight: 700;
      transition: all 0.2s ease;
    }}
    .btn:hover {{
      background: var(--gold);
      color: var(--navy);
    }}

    .slider {{
      width: 100%;
      max-width: 1320px;
      padding: 24px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }}

    .slide {{
      width: 100%;
      aspect-ratio: 16 / 9;
      background: var(--card-bg);
      border-radius: var(--radius);
      box-shadow: 0 24px 48px -18px rgba(11, 27, 61, 0.18);
      border: 1px solid var(--border);
      padding: 40px 48px;
      display: none;
      flex-direction: column;
      position: relative;
      overflow: hidden;
      animation: fadeIn 0.25s ease;
    }}
    .slide.active {{ display: flex; }}

    @keyframes fadeIn {{
      from {{ opacity: 0; transform: translateY(6px); }}
      to {{ opacity: 1; transform: translateY(0); }}
    }}

    .slide.dark {{
      background: radial-gradient(circle at 80% 20%, #1A3668, var(--navy) 70%);
      color: white;
      border-color: #1E3A6E;
    }}

    .slide-badge {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      font-size: 0.9rem;
      font-weight: 800;
      letter-spacing: 1px;
      text-transform: uppercase;
      color: var(--blue);
      margin-bottom: 4px;
    }}
    .slide.dark .slide-badge {{ color: var(--gold); }}

    .slide-title {{
      font-family: 'Space Grotesk', sans-serif;
      font-size: 2.2rem;
      font-weight: 800;
      color: var(--navy);
      line-height: 1.25;
      margin-bottom: 22px;
    }}
    .slide.dark .slide-title {{ color: white; }}

    .split-layout {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 32px;
      flex: 1;
      align-items: stretch;
    }}

    .left-col {{
      display: flex;
      flex-direction: column;
      gap: 18px;
      justify-content: center;
    }}

    .card {{
      background: var(--bg);
      border-radius: 14px;
      padding: 22px 24px;
      border: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.03);
    }}
    .card.accent {{
      background: var(--gold-light);
      border: 1.5px solid var(--gold);
    }}

    .card-title {{
      font-size: 1.22rem;
      font-weight: 800;
      color: var(--navy);
      margin-bottom: 12px;
      line-height: 1.35;
    }}

    .card ul {{
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }}
    .card li {{
      font-size: 1.02rem;
      line-height: 1.5;
      color: var(--text);
      position: relative;
      padding-left: 20px;
    }}
    .card li::before {{
      content: "•";
      color: var(--gold);
      font-weight: 900;
      font-size: 1.3rem;
      position: absolute;
      left: 0;
      top: -2px;
    }}

    .right-col {{
      display: flex;
      align-items: center;
      justify-content: center;
      background: white;
      border-radius: 14px;
      border: 1px solid var(--border);
      padding: 12px;
      box-shadow: 0 4px 12px -2px rgba(0,0,0,0.05);
      overflow: hidden;
    }}
    .right-col img {{
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
      border-radius: 8px;
    }}

    .title-grid {{
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 36px;
      height: 100%;
      align-items: center;
    }}
    .title-banner {{
      display: flex;
      flex-direction: column;
      gap: 16px;
    }}
    .title-banner h1 {{
      font-family: 'Space Grotesk', sans-serif;
      font-size: 3.3rem;
      color: white;
      font-weight: 800;
      line-height: 1.15;
    }}
    .title-banner h2 {{
      font-size: 1.45rem;
      color: #CBD5E1;
      font-weight: 500;
      line-height: 1.5;
    }}
    .title-logo-box {{
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 16px;
    }}
    .title-logo-img {{
      width: 320px;
      height: 320px;
      object-fit: contain;
      background: white;
      border-radius: 24px;
      padding: 16px;
      box-shadow: 0 16px 40px rgba(0,0,0,0.4);
      border: 3px solid var(--gold);
    }}

    .speaker-notes-box {{
      width: 100%;
      max-width: 1320px;
      background: #1E293B;
      color: #F8FAFC;
      border-radius: 12px;
      padding: 22px 32px;
      margin-top: 18px;
      box-shadow: var(--shadow);
    }}
    .speaker-notes-box h4 {{
      color: var(--gold);
      font-size: 1rem;
      text-transform: uppercase;
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .speaker-notes-box p {{
      font-size: 1.05rem;
      line-height: 1.65;
      font-style: italic;
      color: #E2E8F0;
    }}

    .indicator-bar {{
      display: flex;
      gap: 10px;
      margin-top: 14px;
    }}
    .dot {{
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #CBD5E1;
      cursor: pointer;
      transition: all 0.2s ease;
    }}
    .dot.active {{
      background: var(--navy);
      width: 36px;
      border-radius: 6px;
    }}
  </style>
</head>
<body>

  <!-- Top Bar -->
  <div class="top-bar">
    <div class="brand">
      <span>🛰️</span> LẮNG · NASA SPACE APPS CHALLENGE 2026
    </div>
    <div class="controls">
      <span id="slideCounter" style="font-weight: 700; font-size: 1rem;">Slide 1 / 8</span>
      <button class="btn" onclick="prevSlide()">◀ Trước</button>
      <button class="btn" onclick="nextSlide()">Sau ▶</button>
      <button class="btn" onclick="toggleFullScreen()" style="border-color: var(--blue-sky);">⛶ Toàn màn hình</button>
    </div>
  </div>

  <!-- Slides Container -->
  <div class="slider">

    <!-- SLIDE 0: TITLE -->
    <div class="slide dark active" data-notes="Kính thưa Ban giám khảo và các chuyên gia NASA, chúng em là đội Đàn Bầu Trái Đất. Hôm nay, chúng em xin trân trọng giới thiệu dự án LẮNG — một Earth Information Jukebox đa giác quan, biến kho dữ liệu viễn thám không gian khổng lồ của NASA thành những giai điệu nhạc cụ dân tộc Việt Nam thân thương và xúc giác chân thực dành cho hơn 1,2 triệu người khiếm thị.">
      <div class="title-grid">
        <div class="title-banner">
          <div style="color: var(--gold); font-weight: 800; letter-spacing: 1.5px; font-size: 1.05rem;">
            NASA SPACE APPS CHALLENGE 2026 · THỬ THÁCH #14: THE EARTH INFORMATION JUKEBOX
          </div>
          <h1>LẮNG — QUẢ ĐỊA CẦU BIẾT NÓI</h1>
          <h2>Âm Thanh Hóa Dữ Liệu Khoa Học NASA Bằng Nhạc Cụ Dân Tộc Việt Nam & Trợ Năng Xúc Giác Đa Giác Quan</h2>
          <div style="display: flex; gap: 14px; margin-top: 12px; flex-wrap: wrap;">
            <span style="background: rgba(212, 175, 55, 0.2); border: 1.5px solid var(--gold); padding: 7px 16px; border-radius: 20px; font-size: 0.95rem; font-weight: 700; color: var(--gold);">
              ♿ 100% Giọng Nói Rảnh Tay (WCAG AAA)
            </span>
            <span style="background: rgba(2, 132, 199, 0.25); border: 1.5px solid var(--blue-sky); padding: 7px 16px; border-radius: 20px; font-size: 0.95rem; font-weight: 700; color: var(--blue-sky);">
              🎵 Đàn Bầu & Đàn T'rưng Sonification
            </span>
            <span style="background: rgba(255, 255, 255, 0.12); border: 1.5px solid rgba(255,255,255,0.4); padding: 7px 16px; border-radius: 20px; font-size: 0.95rem; font-weight: 700; color: white;">
              ⚡ Google Gemma 4 + Local Earth RAG
            </span>
          </div>
          <div style="margin-top: 24px; font-size: 1.05rem; color: #E2E8F0; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 16px;">
            Đội thi: <strong style="color: var(--gold);">ĐÀN BẦU TRÁI ĐẤT (6 Thành viên)</strong> · Bản chạy thực tế: <strong style="color: white;">sense-app-two.vercel.app</strong>
          </div>
        </div>
        <div class="title-logo-box">
          <img src="{b64_logo}" alt="Logo Lắng" class="title-logo-img">
          <div style="color: var(--gold); font-weight: 800; font-size: 1.15rem; letter-spacing: 1px;">
            LẮNG · THE ACOUSTIC GLOBE
          </div>
        </div>
      </div>
    </div>

    <!-- SLIDE 1: PROBLEM -->
    <div class="slide" data-notes="Kho dữ liệu của NASA là báu vật tri thức của nhân loại, nhưng hiện nay toàn bộ đều là dữ liệu để nhìn. Một người khiếm thị không thể biết nhiệt độ Trái Đất đang biến đổi ra sao, một cơn bão đang tiến vào đất liền thế nào. Dự án Lắng giải quyết triệt để rào cản này bằng cách chuyển hóa dữ liệu thị giác sang đôi tai và bàn tay: biến các con số khô khan thành giai điệu Đàn Bầu, Đàn T'rưng và độ rung xúc giác Haptic.">
      <div class="slide-badge">CÂU HỎI 01 · BÀI TOÁN CẦN GIẢI QUYẾT</div>
      <div class="slide-title">Dự án đang giải quyết vấn đề gì?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">Rào Cản Thị Giác Khổng Lồ Hiện Nay</div>
            <ul>
              <li>Kho dữ liệu viễn thám NASA (EIC, GISS, POWER, FIRMS, SRTM) mang giá trị khoa học to lớn.</li>
              <li>Tuy nhiên, <strong>100% dữ liệu hiển thị dạng trực quan:</strong> biểu đồ nhiệt, ảnh vệ tinh, dashboard phức tạp.</li>
              <li>Tạo nên "bức tường vô hình" cô lập <strong>1,2 triệu người khiếm thị Việt Nam</strong> và hơn 253 triệu người suy giảm thị lực toàn cầu.</li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">Giải Pháp "LẮNG" Đa Giác Quan Đột Phá</div>
            <ul>
              <li>Chuyển hóa dữ liệu NASA <strong>từ MẮT sang TAI và TAY:</strong></li>
              <li><strong>Nghe bằng Nhạc cụ Dân tộc:</strong> Đàn Bầu uốn nhiệt độ, Đàn T'rưng gõ mưa lũ, tiếng Lửa khô cháy rừng.</li>
              <li><strong>Chạm địa hình Haptic Sense:</strong> Sáo trúc theo đỉnh núi, điện thoại rung dồn dập theo độ dốc SRTM 30m.</li>
              <li><strong>100% Giọng nói rảnh tay:</strong> Không cần nhìn, không nút bấm, cam kết không bị kẹt (WCAG AAA).</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s1}" alt="Sơ đồ Bài toán & Giải pháp Lắng">
        </div>
      </div>
    </div>

    <!-- SLIDE 2: WHY THIS PROBLEM -->
    <div class="slide" data-notes="Chúng em chọn vấn đề này vì một lý do rất bình dị: Khi cơn bão Yagi càn quét qua miền Bắc, những người bạn khiếm thị của chúng em hoàn toàn mất phương hướng trước những thông tin đồ họa trên TV hay mạng xã hội. Thử thách #14 đã trao cho chúng em cơ hội hoàn hảo để kết hợp âm nhạc truyền thống Việt Nam — tiếng Đàn Bầu, tiếng Đàn T'rưng — với dữ liệu viễn thám NASA, để bảo vệ và truyền cảm hứng cho những người yếu thế nhất.">
      <div class="slide-badge">CÂU HỎI 02 · ĐỘNG LỰC & SỨ MỆNH</div>
      <div class="slide-title">Vì sao đội chọn vấn đề này?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">Từ Trải Nghiệm Thực Tế Khắc Nghiệt</div>
            <ul>
              <li>Khảo sát người khiếm thị tại VN: Khi siêu bão (Yagi 2024) hay lũ lịch sử miền Trung ập đến, người khiếm thị là nhóm dễ tổn thương nhất.</li>
              <li>Họ chỉ cần thông tin tối giản: <em>"Chiều nay có mưa không?", "Đường có ngập không?"</em>.</li>
              <li>Trẻ em khiếm thị luôn khao khát cảm nhận bầu trời và các hành tinh nhưng hoàn toàn thiếu giáo cụ.</li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">Bản Sắc Việt & Cơ Hội Từ Thử Thách #14</div>
            <ul>
              <li>Đề bài #14: Biến dữ liệu Trái Đất thành Earth Jukebox sống động.</li>
              <li>Âm nhạc là ngôn ngữ toán học & khoa học trực giác nhất cho thính giác phi thường của người khiếm thị.</li>
              <li><strong>Đàn Bầu uốn lượn cao độ liên tục</strong> tương thích hoàn hảo với đồ thị nhiệt độ liên tục của tự nhiên.</li>
              <li>Đưa văn hóa truyền thống kết hợp khoa học NASA vì cộng đồng yếu thế.</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s2}" alt="Sự kết hợp Nhạc cụ Dân tộc & Dữ liệu NASA">
        </div>
      </div>
    </div>

    <!-- SLIDE 3: DATA & PIPELINE -->
    <div class="slide" data-notes="Điểm cốt lõi làm nên sức mạnh của Lắng là tính Liêm chính Khoa học. Chúng em khai thác 6 bộ dữ liệu chuẩn hóa của NASA từ nhiệt độ GISTEMP 146 năm, lượng mưa MERRA-2, cháy rừng FIRMS cho đến địa hình viễn thám SRTM 30m. Qua pipeline lượng tử hóa uint8, chúng em nén 300 tháng dữ liệu toàn bộ đất liền Việt Nam xuống chỉ còn 280KB chạy offline 100%, với sai số nhiệt độ kiểm chứng đối chiếu trực tiếp cực nhỏ dưới 0.058°C.">
      <div class="slide-badge">CÂU HỎI 03 · KHOA HỌC DỮ LIỆU NASA</div>
      <div class="slide-title">Dữ liệu NASA nào được sử dụng và xử lý như thế nào?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">6 Bộ Dữ Liệu NASA Chuẩn Hóa Đóng Gói</div>
            <ul>
              <li><strong>NASA GISTEMP v4:</strong> 146 năm nhiệt độ toàn cầu (1880–2025).</li>
              <li><strong>NASA POWER (MERRA-2):</strong> 45 năm khí hậu 29 địa điểm, 34 tỉnh VN & chuỗi 15 ngày bão Yagi / lũ Huế.</li>
              <li><strong>NASA FIRMS:</strong> Điểm cháy rừng MODIS C6.1 theo 12 tháng.</li>
              <li><strong>NASA SEDAC GDIS (282 thiên tai) & NASA SRTM 30m.</strong></li>
              <li><strong>NASA NSSDCA, Space Place & 10 Historical Sounds.</strong></li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">Pipeline Lượng Tử uint8 & Liêm Chính Khoa Học</div>
            <ul>
              <li>Pipeline Python độc lập cắt lưới 0.1° (2.849 ô đất liền VN) qua 300 tháng lịch sử (2001–2025).</li>
              <li><strong>Nén siêu nhẹ:</strong> Từ hàng GB xuống đúng <strong>280KB</strong> chạy Offline 100%.</li>
              <li><strong>7-Point Quality Gate:</strong> Sai số nhiệt độ lớn nhất = <strong>0.058 °C</strong>, sai số mưa = <strong>1.485 mm</strong> (đạt chuẩn KTTV).</li>
              <li>Khối <code>data_card</code> 12 trường & lệnh <em>"Nguồn dữ liệu"</em> minh bạch.</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s3}" alt="Kiến trúc Pipeline NASA & Bằng chứng Kiểm định">
        </div>
      </div>
    </div>

    <!-- SLIDE 4: UNIQUENESS -->
    <div class="slide" data-notes="So với các ứng dụng hiện có, Lắng sở hữu 4 điểm đột phá chưa từng có: Thứ nhất, giao diện 100% rảnh tay không nút bấm. Thứ hai, sự kết hợp độc nhất giữa nhạc cụ dân tộc Việt Nam với dữ liệu viễn thám. Thứ ba, công nghệ 'Rê tay khám phá' biến màn hình điện thoại thành sa bàn nổi xúc giác Haptic. Và thứ tư, Trợ lý AI Gemma 4 kết hợp Local Earth RAG bảo đảm mọi câu trả lời khoa học đều chính xác tuyệt đối, không bịa đặt số liệu.">
      <div class="slide-badge">CÂU HỎI 04 · TÍNH ĐỘC ĐÁO & KHÁC BIỆT</div>
      <div class="slide-title">Điểm khác biệt của sản phẩm so với những giải pháp hiện có?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">Vượt Trội So Với App Hiện Nay</div>
            <ul>
              <li><strong>So với App Thời tiết thông thường:</strong> Lắng 100% rảnh tay, không nút bấm, tự bật mic nghe liên tục.</li>
              <li>Chỉ mất <strong>3 giây</strong> nghe chuỗi âm nhạc dân tộc là người khiếm thị cảm nhận trọn vẹn thời tiết 24 giờ tới.</li>
              <li><strong>So với Sonification quốc tế của NASA:</strong> Thay vì âm synth điện tử trừu tượng, Lắng đưa Đàn Bầu, Đàn T'rưng, Sáo trúc, Tiếng Lửa khô, Mõ chùa vào viễn thám.</li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">4 Đột Phá Kỹ Thuật Chưa Từng Có</div>
            <ul>
              <li><strong>1. Rê tay Haptic Sense:</strong> Sáo theo độ cao SRTM 30m, rung điện thoại dồn dập theo độ dốc địa hình.</li>
              <li><strong>2. Quét mặt cắt địa hình 8 km:</strong> Mô phỏng không gian 3D dưới 8s.</li>
              <li><strong>3. Trợ lý AI Gemma 4 + Local Earth RAG:</strong> Khử 100% ảo giác bịa số khoa học nhờ neo chặt dữ liệu NASA.</li>
              <li><strong>4. Cử chỉ Z-gesture:</strong> Tuyệt đối không bao giờ bị kẹt.</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s4}" alt="Bảng So Sánh Lắng & Các Giải Pháp Hiện Có">
        </div>
      </div>
    </div>

    <!-- SLIDE 5: TESTING & VALIDATION -->
    <div class="slide" data-notes="Sản phẩm của chúng em hiện đã đạt mức độ sẵn sàng công nghệ TRL 6-7, hoạt động trơn tru trên cả Web, Windows và Android. Toàn bộ 15 bài unit test kỹ thuật đều đạt 100%. Quan trọng nhất, chúng em đã mang ứng dụng đến thử nghiệm thực tế với những người bạn khiếm thị: họ có thể tự mình nghe lịch sử bão Yagi, nhắm mắt rê ngón tay cảm nhận dãy núi Đà Lạt và khẳng định Lắng đã mang lại sự tự tin và độc lập tuyệt đối cho họ.">
      <div class="slide-badge">CÂU HỎI 05 · KẾT QUẢ THỰC NGHIỆM THỰC TẾ</div>
      <div class="slide-title">Sản phẩm đã được thử nghiệm đến đâu?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">Mức Độ Sẵn Sàng Công Nghệ Cao (TRL 6-7)</div>
            <ul>
              <li>Sản phẩm chạy thực tế đa nền tảng, không phải bản thảo:</li>
              <li>• <strong>Web trực tuyến:</strong> <code>sense-app-two.vercel.app</code></li>
              <li>• <strong>Windows Desktop (.exe):</strong> Tích hợp engine C++ SoLoud.</li>
              <li>• <strong>Android (.apk):</strong> Rung Haptic & TalkBack rảnh tay.</li>
              <li><strong>15/15 Flutter Unit Tests đạt 100%</strong> vượt qua 7 Quality Gates.</li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">Xác Thực Người Khiếm Thị Thực Tế</div>
            <ul>
              <li>Thử nghiệm trực tiếp với người khiếm thị (theo phiếu khảo sát):</li>
              <li>Người khiếm thị tự ra lệnh bằng giọng nói, nghe bão Yagi và rê ngón tay cảm nhận địa hình độc lập 100%.</li>
              <li>Tỷ lệ nhận diện giọng nói tiếng Việt chính xác <strong>> 92%</strong>.</li>
              <li>Cử chỉ chữ Z giúp <strong>100% người thử không bao giờ bị lạc.</strong></li>
              <li>Đóng gói bộ biểu mẫu Excel feedback chuẩn hóa 40 ca test.</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s5}" alt="Bằng chứng Kiểm thử Kỹ thuật & Người dùng Thực tế">
        </div>
      </div>
    </div>

    <!-- SLIDE 6: FUTURE ROADMAP -->
    <div class="slide" data-notes="Nếu có thêm thời gian, lộ trình của chúng em được chia làm 3 bước vững chắc: Trong 3 tháng tới, tích hợp cảnh báo ngập úng đô thị theo thời gian thực để bảo vệ người khiếm thị đi lại trên đường phố. Về phần cứng, chúng em sẽ kết nối bàn rê chân kim nổi cơ học để người khiếm thị có thể 'sờ' thấy bề mặt Mặt Trăng và địa hình Tổ quốc bằng vật lý. Và xa hơn, chúng em sẽ đưa Lắng vào tất cả các trường học hòa nhập, mang tiếng nói khoa học NASA đến với mọi trẻ em khiếm thị trên thế giới.">
      <div class="slide-badge">CÂU HỎI 06 · TẦM NHÌN TƯƠNG LAI</div>
      <div class="slide-title">Nếu có thêm thời gian, đội sẽ tiếp tục phát triển điều gì?</div>
      <div class="split-layout">
        <div class="left-col">
          <div class="card">
            <div class="card-title">Giai Đoạn 1: Cảnh Báo Ngập Úng & Offline</div>
            <ul>
              <li><strong>Cảnh báo ngập úng đô thị thời gian thực:</strong> Tích hợp dữ liệu mưa NASA IMERG với các điểm trũng ngập lụt tại Hà Nội & TP.HCM, cảnh báo trực tiếp qua tai nghe cho người khiếm thị.</li>
              <li>Tối ưu hóa mô hình AI Speech Offline để chạy siêu nhẹ trên các điện thoại Android giá rẻ.</li>
              <li>Mở rộng lưới độ cao F3 phủ kín 63 tỉnh thành Việt Nam.</li>
            </ul>
          </div>
          <div class="card accent">
            <div class="card-title">Giai Đoạn 2 & 3: Xúc Giác Nổi & Giáo Dục</div>
            <ul>
              <li>Kết nối <strong>Tactile Haptic Pad (bàn rê chân kim nổi cơ học 3D):</strong> Người khiếm thị có thể 'sờ' thấy dãy núi thật, miệng núi lửa Mặt Trăng và đường bờ biển Tổ quốc bằng vật lý.</li>
              <li>Đưa Lắng vào chương trình STEM hòa nhập tại các trường khiếm thị Nguyễn Đình Chiểu toàn quốc.</li>
              <li>Hỗ trợ tiếng dân tộc thiểu số và đưa âm nhạc dân gian Đông Nam Á vào Earth Jukebox toàn cầu.</li>
            </ul>
          </div>
        </div>
        <div class="right-col">
          <img src="{b64_s6}" alt="Lộ trình Phát triển & Tầm nhìn Tương lai">
        </div>
      </div>
    </div>

    <!-- SLIDE 7: CONCLUSION -->
    <div class="slide dark" data-notes="Lắng không chỉ là một ứng dụng dự thi hackathon, Lắng là lời khẳng định rằng: Dữ liệu khoa học không gian của NASA phải thuộc về tất cả mọi người, không trừ một ai. Bằng âm thanh của Đàn Bầu, Đàn T'rưng và độ rung xúc giác của non sông đất nước, chúng em tự hào mang Trái Đất và Vũ trụ đến gần hơn với trái tim của người khiếm thị. Chúng em xin chân thành cảm ơn Ban Giám khảo và rất sẵn lòng bước vào phần Demo và trả lời các câu hỏi Q&A!">
      <div style="display: flex; flex-direction: column; justify-content: space-between; height: 100%;">
        <div>
          <div style="color: var(--gold); font-weight: 800; letter-spacing: 1.5px; font-size: 1.05rem;">
            TỔNG KẾT & CAM KẾT SỨ MỆNH XÃ HỘI
          </div>
          <h1 style="font-size: 2.7rem; color: white; margin-top: 6px;">LẮNG · THE EARTH INFORMATION JUKEBOX</h1>
          <h2 style="color: var(--gold); font-size: 1.45rem; margin-top: 4px;">"Khi Khoa Học Không Gian NASA Gặp Gỡ Trái Tim Văn Hóa Việt Nam"</h2>
        </div>

        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-top: 24px;">
          <div style="background: rgba(19, 42, 85, 0.75); border: 1.5px solid var(--gold); border-radius: 14px; padding: 24px;">
            <div style="font-size: 2rem; margin-bottom: 8px;">🔭</div>
            <div style="font-size: 1.25rem; font-weight: 800; color: var(--gold); margin-bottom: 8px;">Liêm Chính Khoa Học</div>
            <p style="font-size: 1.02rem; color: #E2E8F0; line-height: 1.55;">
              100% dữ liệu gốc chuẩn hóa từ NASA. Pipeline lượng tử hóa bảo toàn độ chính xác với sai số dưới 0.058 °C, vượt qua 7 cổng kiểm định khắt khe.
            </p>
          </div>
          <div style="background: rgba(19, 42, 85, 0.75); border: 1.5px solid var(--gold); border-radius: 14px; padding: 24px;">
            <div style="font-size: 2rem; margin-bottom: 8px;">♿</div>
            <div style="font-size: 1.25rem; font-weight: 800; color: var(--gold); margin-bottom: 8px;">Trợ Năng Tuyệt Đối</div>
            <p style="font-size: 1.02rem; color: #E2E8F0; line-height: 1.55;">
              100% rảnh tay bằng giọng nói, cử chỉ Z-gesture không bao giờ kẹt, bản đồ xúc giác Haptic và nhạc cụ dân tộc truyền cảm hứng sâu sắc.
            </p>
          </div>
          <div style="background: rgba(19, 42, 85, 0.75); border: 1.5px solid var(--gold); border-radius: 14px; padding: 24px;">
            <div style="font-size: 2rem; margin-bottom: 8px;">🚀</div>
            <div style="font-size: 1.25rem; font-weight: 800; color: var(--gold); margin-bottom: 8px;">Sẵn Sàng Sử Dụng</div>
            <p style="font-size: 1.02rem; color: #E2E8F0; line-height: 1.55;">
              Đã chạy thực tế đa nền tảng Web, Windows, Android; kiểm thử tự động 100% thành công và người khiếm thị thực tế xác thực.
            </p>
          </div>
        </div>

        <div style="display: flex; justify-content: space-between; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 18px; margin-top: 24px;">
          <span style="color: white; font-weight: 800; font-size: 1.15rem;">CẢM ƠN HỘI ĐỒNG BAN GIÁM KHẢO! CHÚNG EM SẴN SÀNG CHO PHẦN Q&A VÀ DEMO TRỰC TIẾP.</span>
          <span style="color: var(--gold); font-weight: 700;">sense-app-two.vercel.app</span>
        </div>
      </div>
    </div>

  </div>

  <!-- Indicator Dots -->
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

    for (let i = 0; i < totalSlides; i++) {{
      const dot = document.createElement('div');
      dot.className = 'dot' + (i === 0 ? ' active' : '');
      dot.onclick = () => showSlide(i);
      indicatorBar.appendChild(dot);
    }}
    const dots = document.querySelectorAll('.dot');

    function updateSlide() {{
      slides.forEach((s, idx) => {{
        s.classList.toggle('active', idx === currentSlide);
      }});
      dots.forEach((d, idx) => {{
        d.classList.toggle('active', idx === currentSlide);
      }});
      slideCounter.innerText = `Slide ${{currentSlide + 1}} / ${{totalSlides}}`;
      speakerNotesText.innerText = slides[currentSlide].getAttribute('data-notes') || '';
    }}

    function showSlide(index) {{
      if (index >= 0 && index < totalSlides) {{
        currentSlide = index;
        updateSlide();
      }}
    }}

    function nextSlide() {{
      if (currentSlide < totalSlides - 1) {{
        currentSlide++;
        updateSlide();
      }}
    }}

    function prevSlide() {{
      if (currentSlide > 0) {{
        currentSlide--;
        updateSlide();
      }}
    }}

    document.addEventListener('keydown', (e) => {{
      if (e.key === 'ArrowRight' || e.key === 'Space') {{
        nextSlide();
      }} else if (e.key === 'ArrowLeft') {{
        prevSlide();
      }}
    }});

    function toggleFullScreen() {{
      if (!document.fullscreenElement) {{
        document.documentElement.requestFullscreen();
      }} else {{
        if (document.exitFullscreen) {{
          document.exitFullscreen();
        }}
      }}
    }}

    updateSlide();
  </script>
</body>
</html>
"""

    html_path_docs = r"d:\user\Desktop\Github\sense\docs\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.html"
    html_path_root = r"d:\user\Desktop\Github\sense\Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.html"
    with open(html_path_docs, "w", encoding="utf-8") as f:
        f.write(html_standalone)
    with open(html_path_root, "w", encoding="utf-8") as f:
        f.write(html_standalone)
    print("Standalone Base64 HTML presentations generated successfully!")

if __name__ == "__main__":
    build_perfect_pitch_deck()

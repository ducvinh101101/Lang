import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

def create_feedback_workbook():
    wb = openpyxl.Workbook()
    # Remove default sheet
    wb.remove(wb.active)

    # Styles
    font_family = "Segoe UI"
    
    # Colors
    c_primary = "1A2B4C"      # Deep Navy Sơn Mài
    c_secondary = "2B4C7E"    # Steel Blue
    c_accent = "D4AF37"       # Gold / Đồng
    c_accent_light = "FFF9E6" # Soft Gold
    c_zebra = "F8FAFC"        # Light gray/slate
    c_white = "FFFFFF"
    c_dark = "1E293B"
    c_border = "CBD5E1"
    c_border_dark = "94A3B8"
    
    # Pre-defined fonts
    f_title = Font(name=font_family, size=16, bold=True, color="FFFFFF")
    f_subtitle = Font(name=font_family, size=11, italic=True, color="E2E8F0")
    f_header = Font(name=font_family, size=11, bold=True, color="FFFFFF")
    f_header_dark = Font(name=font_family, size=11, bold=True, color=c_dark)
    f_section = Font(name=font_family, size=12, bold=True, color=c_primary)
    f_bold = Font(name=font_family, size=10, bold=True, color=c_dark)
    f_regular = Font(name=font_family, size=10, color=c_dark)
    f_italic = Font(name=font_family, size=9, italic=True, color="64748B")
    f_kpi_num = Font(name=font_family, size=18, bold=True, color=c_primary)
    f_kpi_label = Font(name=font_family, size=9, bold=True, color="64748B")

    # Fills
    fill_primary = PatternFill(start_color=c_primary, end_color=c_primary, fill_type="solid")
    fill_secondary = PatternFill(start_color=c_secondary, end_color=c_secondary, fill_type="solid")
    fill_accent = PatternFill(start_color=c_accent, end_color=c_accent, fill_type="solid")
    fill_accent_light = PatternFill(start_color=c_accent_light, end_color=c_accent_light, fill_type="solid")
    fill_zebra = PatternFill(start_color=c_zebra, end_color=c_zebra, fill_type="solid")
    fill_white = PatternFill(start_color=c_white, end_color=c_white, fill_type="solid")
    fill_kpi = PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid")

    # Borders
    thin_border = Border(
        left=Side(style='thin', color=c_border),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='thin', color=c_border)
    )
    thick_bottom_border = Border(
        left=Side(style='thin', color=c_border),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='medium', color=c_secondary)
    )
    card_border = Border(
        left=Side(style='medium', color=c_secondary),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='thin', color=c_border)
    )

    # Alignments
    align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)
    align_right = Alignment(horizontal="right", vertical="center", wrap_text=True)
    align_top_left = Alignment(horizontal="left", vertical="top", wrap_text=True)

    # -------------------------------------------------------------
    # SHEET 1: Hướng dẫn & Người đánh giá (GUIDE & EVALUATOR)
    # -------------------------------------------------------------
    ws1 = wb.create_sheet(title="📋 Thông tin & Hướng dẫn")
    ws1.views.sheetView[0].showGridLines = True

    # Title block
    ws1.merge_cells("B2:I2")
    ws1["B2"] = "PHIẾU ĐÁNH GIÁ & GÓP Ý TRẢI NGHIỆM NGƯỜI DÙNG"
    ws1["B2"].font = f_title
    ws1["B2"].fill = fill_primary
    ws1["B2"].alignment = align_center

    ws1.merge_cells("B3:I3")
    ws1["B3"] = "Hệ thống LẮNG: Quả Địa Cầu Biết Nói & Âm Thanh Hóa Dữ Liệu Khoa Học NASA (Earth Information Jukebox)"
    ws1["B3"].font = f_subtitle
    ws1["B3"].fill = fill_secondary
    ws1["B3"].alignment = align_center

    # Section 1: Evaluator Info
    ws1.merge_cells("B5:E5")
    ws1["B5"] = "1. THÔNG TIN NGƯỜI ĐÁNH GIÁ (TESTER / USER INFO)"
    ws1["B5"].font = f_section

    info_fields = [
        ("Họ và tên người đánh giá:", "Bùi Minh Hiếu (Ví dụ)", "Vai trò / Đối tượng:", "Người khiếm thị"),
        ("Đơn vị / Tổ chức / Nghề nghiệp:", "Hội Người mù Việt Nam / Tự do", "Nhóm người dùng:", "Người dùng khiếm thị / Giảm thị lực"),
        ("Thiết bị thử nghiệm:", "Máy tính Windows / Điện thoại Android", "Trình duyệt / Ứng dụng:", "Google Chrome / Edge / App Flutter"),
        ("Hệ điều hành & Phiên bản:", "Windows 11 / Android 14", "Phần mềm đọc màn hình (Screen Reader):", "NVDA / TalkBack / VoiceOver / Không dùng"),
        ("Ngày thực hiện đánh giá:", "11/11/2026", "Thời gian trải nghiệm tổng cộng:", "45 phút"),
    ]

    row_idx = 6
    for f1, v1, f2, v2 in info_fields:
        ws1.cell(row=row_idx, column=2, value=f1).font = f_bold
        ws1.cell(row=row_idx, column=2).fill = fill_accent_light
        ws1.cell(row=row_idx, column=2).border = thin_border
        
        c_v1 = ws1.cell(row=row_idx, column=3, value=v1)
        c_v1.font = f_regular
        c_v1.border = thin_border
        
        ws1.cell(row=row_idx, column=4, value=f2).font = f_bold
        ws1.cell(row=row_idx, column=4).fill = fill_accent_light
        ws1.cell(row=row_idx, column=4).border = thin_border
        
        c_v2 = ws1.cell(row=row_idx, column=5, value=v2)
        c_v2.font = f_regular
        c_v2.border = thin_border
        row_idx += 1

    # Section 2: Rating Scale
    ws1.merge_cells("B12:E12")
    ws1["B12"] = "2. QUY CHUẨN THANG ĐIỂM ĐÁNH GIÁ (1 - 5 SAO)"
    ws1["B12"].font = f_section

    scales = [
        ("5 - Xuất sắc (Excellent)", "Tính năng hoạt động hoàn hảo, âm thanh sống động, phản hồi nhanh, trợ năng tuyệt vời."),
        ("4 - Tốt (Good)", "Hoạt động đúng mong đợi, hữu ích, dễ sử dụng, chỉ có điểm nhỏ cần tinh chỉnh thêm."),
        ("3 - Đạt (Acceptable)", "Hoạt động được nhưng đôi lúc nhận diện giọng nói chưa nhạy hoặc âm thanh chưa thật mượt."),
        ("2 - Kém (Poor)", "Khó sử dụng, âm thanh chói hoặc giật, giọng đọc bị ngắt quãng, nhận diện sai nhiều."),
        ("1 - Rất kém / Lỗi (Critical)", "Không hoạt động, văng ứng dụng (crash), bị kẹt màn hình không thoát ra được.")
    ]

    ws1.cell(row=13, column=2, value="Mức điểm").font = f_header
    ws1.cell(row=13, column=2).fill = fill_secondary
    ws1.cell(row=13, column=2).border = thin_border
    ws1.merge_cells("C13:E13")
    ws1.cell(row=13, column=3, value="Mô tả trải nghiệm thực tế").font = f_header
    ws1.cell(row=13, column=3).fill = fill_secondary
    ws1.cell(row=13, column=3).border = thin_border
    ws1.cell(row=13, column=4).border = thin_border
    ws1.cell(row=13, column=5).border = thin_border

    r_scale = 14
    for sc, desc in scales:
        ws1.cell(row=r_scale, column=2, value=sc).font = f_bold
        ws1.cell(row=r_scale, column=2).border = thin_border
        ws1.merge_cells(start_row=r_scale, start_column=3, end_row=r_scale, end_column=5)
        cell_d = ws1.cell(row=r_scale, column=3, value=desc)
        cell_d.font = f_regular
        cell_d.border = thin_border
        ws1.cell(row=r_scale, column=4).border = thin_border
        ws1.cell(row=r_scale, column=5).border = thin_border
        r_scale += 1

    # Section 3: Bug Severity Definition
    ws1.merge_cells("B20:E20")
    ws1["B20"] = "3. PHÂN LOẠI MỨC ĐỘ LỖI / VẤN ĐỀ (BUG SEVERITY)"
    ws1["B20"].font = f_section

    severities = [
        ("Nghiêm trọng (Blocker)", "Ứng dụng bị sập, đơ cứng, kẹt không có đường thoát, mất âm thanh toàn bộ."),
        ("Cao (Critical / Major)", "Tính năng chính không phản hồi (ví dụ: không nhận diện được giọng nói, không đọc được dữ liệu NASA)."),
        ("Trung bình (Moderate)", "Dữ liệu đọc ra chậm, phát âm sai một vài từ địa phương, cử chỉ rê tay phản hồi chưa khớp."),
        ("Nhẹ (Minor / Trivial)", "Lỗi chính tả văn bản hiển thị, màu sắc chưa tối ưu, âm lượng chênh lệch nhẹ."),
        ("Đề xuất (Improvement)", "Ý tưởng mới, muốn bổ sung thêm địa danh, thêm nhạc cụ hoặc câu khẩu lệnh tiện lợi hơn.")
    ]

    ws1.cell(row=21, column=2, value="Mức độ lỗi").font = f_header
    ws1.cell(row=21, column=2).fill = fill_secondary
    ws1.cell(row=21, column=2).border = thin_border
    ws1.merge_cells("C21:E21")
    ws1.cell(row=21, column=3, value="Định nghĩa & Ảnh hưởng đến trải nghiệm").font = f_header
    ws1.cell(row=21, column=3).fill = fill_secondary
    ws1.cell(row=21, column=3).border = thin_border
    ws1.cell(row=21, column=4).border = thin_border
    ws1.cell(row=21, column=5).border = thin_border

    r_sev = 22
    for sev, sdesc in severities:
        ws1.cell(row=r_sev, column=2, value=sev).font = f_bold
        ws1.cell(row=r_sev, column=2).border = thin_border
        ws1.merge_cells(start_row=r_sev, start_column=3, end_row=r_sev, end_column=5)
        cell_sd = ws1.cell(row=r_sev, column=3, value=sdesc)
        cell_sd.font = f_regular
        cell_sd.border = thin_border
        ws1.cell(row=r_sev, column=4).border = thin_border
        ws1.cell(row=r_sev, column=5).border = thin_border
        r_sev += 1

    # Section 4: Testing Guide / Note
    ws1.merge_cells("B28:E28")
    ws1["B28"] = "4. HƯỚNG DẪN THỰC HIỆN KIỂM THỬ NHANH"
    ws1["B28"].font = f_section

    guide_steps = [
        "Bước 1: Mở sheet '⭐ Đánh giá chức năng' để thử nghiệm từng chức năng theo các câu lệnh & kịch bản gợi ý sẵn.",
        "Bước 2: Chọn Trạng thái (Đạt / Không đạt / Có lỗi nhẹ), chấm Điểm (1-5 sao) và ghi nhận xét trực tiếp.",
        "Bước 3: Nếu phát hiện lỗi cụ thể, ghi nhanh tại cột 'Mô tả lỗi' hoặc sang sheet '🐛 Báo cáo Lỗi' để mô tả chi tiết các bước gây lỗi.",
        "Bước 4: Nếu có ý tưởng mới hoặc mong muốn cải thiện cho người khiếm thị, hãy ghi vào sheet '💡 Đề xuất Cải thiện'.",
        "Bước 5: Xem tổng kết điểm số tự động tại sheet '📊 Dashboard Thống kê'."
    ]
    r_g = 29
    for gstep in guide_steps:
        ws1.merge_cells(start_row=r_g, start_column=2, end_row=r_g, end_column=5)
        c_g = ws1.cell(row=r_g, column=2, value=gstep)
        c_g.font = f_regular
        c_g.border = thin_border
        ws1.cell(row=r_g, column=3).border = thin_border
        ws1.cell(row=r_g, column=4).border = thin_border
        ws1.cell(row=r_g, column=5).border = thin_border
        r_g += 1

    # Quick Summary Cards on Sheet 1 (Right side F5:I26)
    ws1.merge_cells("G5:I5")
    ws1["G5"] = "TỔNG KẾT TIẾN ĐỘ & ĐIỂM TRUNG BÌNH"
    ws1["G5"].font = f_section
    ws1["G5"].alignment = align_center

    cards = [
        ("Tổng số ca kiểm thử chức năng:", "=COUNTA('⭐ Đánh giá chức năng'!B5:B50)", "ca"),
        ("Số chức năng ĐẠT HOÀN HÀO:", "=COUNTIF('⭐ Đánh giá chức năng'!F5:F50, \"Đạt\")", "chức năng"),
        ("Số chức năng CÓ LỖI / CHƯA ĐẠT:", "=COUNTIF('⭐ Đánh giá chức năng'!F5:F50, \"Không đạt\") + COUNTIF('⭐ Đánh giá chức năng'!F5:F50, \"Có lỗi nhẹ\")", "chức năng"),
        ("ĐIỂM ĐÁNH GIÁ TRUNG BÌNH:", "=AVERAGE('⭐ Đánh giá chức năng'!G5:G50)", "/ 5.0 ⭐"),
        ("Tổng số lỗi đã ghi nhận:", "=COUNTA('🐛 Báo cáo Lỗi'!B5:B30)", "lỗi"),
        ("Tổng số đề xuất cải thiện:", "=COUNTA('💡 Đề xuất Cải thiện'!B5:B25)", "đề xuất"),
    ]

    r_c = 7
    for clabel, cformula, cunit in cards:
        ws1.merge_cells(start_row=r_c, start_column=7, end_row=r_c, end_column=8)
        ws1.cell(row=r_c, column=7, value=clabel).font = f_bold
        ws1.cell(row=r_c, column=7).fill = fill_zebra
        ws1.cell(row=r_c, column=7).border = thin_border
        ws1.cell(row=r_c, column=8).border = thin_border
        
        c_val = ws1.cell(row=r_c, column=9, value=cformula)
        c_val.font = f_kpi_num
        c_val.alignment = align_center
        c_val.fill = fill_accent_light
        c_val.border = thin_border
        if "AVERAGE" in cformula:
            c_val.number_format = '0.0'
        r_c += 2


    # -------------------------------------------------------------
    # SHEET 2: Đánh giá chi tiết chức năng (FEATURE TEST & FEEDBACK)
    # -------------------------------------------------------------
    ws2 = wb.create_sheet(title="⭐ Đánh giá chức năng")
    ws2.views.sheetView[0].showGridLines = True

    # Title
    ws2.merge_cells("A2:K2")
    ws2["A2"] = "BẢNG ĐÁNH GIÁ CHI TIẾT TỪNG CHỨC NĂNG & THU THẬP PHẢN HỒI NGƯỜI DÙNG"
    ws2["A2"].font = f_title
    ws2["A2"].fill = fill_primary
    ws2["A2"].alignment = align_center

    ws2.merge_cells("A3:K3")
    ws2["A3"] = "Hệ thống Lắng (NASA Space Apps 2026) · Hãy điền Trạng thái (Đạt/Không đạt), Điểm số (1-5) và Góp ý thực tế"
    ws2["A3"].font = f_subtitle
    ws2["A3"].fill = fill_secondary
    ws2["A3"].alignment = align_center

    headers_ws2 = [
        ("STT", 6, align_center),
        ("Phân hệ / Nhóm", 18, align_center),
        ("Tên chức năng", 28, align_left),
        ("Kịch bản kiểm thử & Khẩu lệnh mẫu", 38, align_left),
        ("Kết quả mong đợi (Tiêu chí Đạt)", 38, align_left),
        ("Trạng thái", 14, align_center),
        ("Điểm (1-5)", 10, align_center),
        ("Mô tả lỗi / Hiện tượng bất thường gặp phải", 35, align_left),
        ("Mong muốn cải thiện / Góp ý người dùng", 35, align_left),
        ("Ưu tiên", 12, align_center),
        ("Ghi chú", 20, align_left),
    ]

    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws2, 1):
        cell = ws2.cell(row=4, column=col_idx, value=hname)
        cell.font = f_header
        cell.fill = fill_primary
        cell.alignment = align_center
        cell.border = thin_border

    # Test cases data: (Module, Name, Script/Voice Command, Expected, Default Status, Default Score, Bug, Improvement, Priority)
    features_data = [
        # Nhóm 0: Trợ năng & Khởi động
        ("Trợ năng & Điều khiển", "Khởi động & Lời chào mở đầu",
         "Mở ứng dụng hoặc trang web trên trình duyệt.\nLắng nghe thông điệp chào đón.",
         "App đọc lời chào, giới thiệu 3 phân hệ, tự động bật mic lắng nghe liên tục mà không cần bấm nút nào.",
         "Đạt", 5, "", "Thêm âm thanh tinh tế khi mic bắt đầu nhận diện", "Cao"),
         
        ("Trợ năng & Điều khiển", "Giao diện Sơn Mài & Screen Reader",
         "Dùng thử TalkBack trên Android, VoiceOver trên iOS/Mac, hoặc NVDA trên Windows.",
         "Giao diện tối tương phản cao (#0A0D14 / #FFD54F), tương thích tốt với trình đọc màn hình theo chuẩn WCAG AAA.",
         "Đạt", 5, "", "Đảm bảo mọi nút gợi ý dưới đáy đều có nhãn accessibility rõ ràng", "Cao"),

        ("Trợ năng & Điều khiển", "Lối thoát an toàn & Cử chỉ Z",
         "Nói 'về màn hình chính', 'dừng lại', 'quay lại' hoặc vẽ chữ Z trong <1 giây.",
         "Lập tức ngừng nói/ngừng phát nhạc, đưa người dùng về màn hình chính của phân hệ, tuyệt đối không bị kẹt.",
         "Đạt", 5, "", "Độ trễ khi nhận diện cử chỉ Z cần dưới 0.3s", "Khẩn cấp"),

        ("Trợ năng & Điều khiển", "Khử dội âm loa ngoài & Lọc tiếng ậm ừ",
         "Bật âm lượng loa to và nói lệnh, hoặc nói chêm tiếng 'ừ', 'à', 'hả' trước khi ra lệnh.",
         "Loa phát không bị dội lại vào mic làm hiểu nhầm; câu nói được lọc sạch tiếng đệm và thực thi chính xác.",
         "Đạt", 4, "", "Tinh chỉnh thêm cho môi trường phòng họp có độ vang lớn", "Trung bình"),

        ("Trợ năng & Điều khiển", "Tốc độ nói & Âm lượng giọng đọc",
         "Nói: 'nói nhanh hơn', 'nói chậm lại', 'to hơn', 'nhỏ hơn'.",
         "Giọng đọc Piper TTS điều chỉnh tốc độ và âm lượng ngay lập tức theo khẩu lệnh của người dùng.",
         "Đạt", 5, "", "Lưu lại mức âm lượng ưa thích cho các phiên dùng sau", "Thấp"),

        ("Trợ năng & Điều khiển", "Chuyển đổi ngôn ngữ Anh - Việt",
         "Nói: 'tiếng Anh' (English) hoặc 'tiếng Việt'.",
         "Hệ thống chuyển đổi toàn bộ thuyết minh và lời thoại sang tiếng Anh/Việt tương ứng mượt mà.",
         "Đạt", 4, "", "Giọng đọc tiếng Anh cần tự nhiên hơn khi đọc tên địa danh Việt Nam", "Trung bình"),

        # Nhóm 1: F1 - Khí hậu, Thời tiết & Thiên tai NASA
        ("F1 - Khí hậu & Thời tiết", "Thời tiết hiện tại & Lời khuyên sinh hoạt",
         "Nói: 'thời tiết Hà Nội', 'chiều nay có mưa không', 'mai đi Đà Lạt có hợp không'.",
         "Đọc nhiệt độ, khả năng mưa, độ ẩm kèm lời khuyên thiết thực (đường trơn, dông lốc, chỉ số UV, bụi mịn).",
         "Đạt", 5, "", "Bổ sung thông tin gợi ý trang phục phù hợp với người lớn tuổi/trẻ em", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Âm thanh hóa thời tiết bằng Nhạc cụ dân tộc",
         "Nói: 'nghe nhạc', hoặc hỏi thời tiết một địa phương.",
         "Đàn Bầu uốn cao độ ngũ cung theo nhiệt độ T2M; Đàn T'rưng gõ nhịp theo lượng mưa PRECTOTCORR; mưa to có sấm vang.",
         "Đạt", 5, "", "Cho phép tùy chọn tắt/bật tiếng sấm nếu người khiếm thị nhạy cảm âm thanh", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Nghe diễn tấu thời tiết 24 giờ tới",
         "Nói: '24 giờ tới' hoặc 'thời tiết ngày mai'.",
         "Phát chuỗi giai điệu nhạc cụ mô phỏng diễn biến thời tiết sáng - trưa - chiều - tối trong 24 giờ liên tục.",
         "Đạt", 5, "", "Thêm tiếng chuông báo khi chuyển giao giữa các buổi trong ngày", "Thấp"),

        ("F1 - Khí hậu & Thời tiết", "Phát lại Lịch sử Thời tiết (NASA POWER)",
         "Nói: 'lịch sử thời tiết Huế 3 năm qua' hoặc 'thời tiết Hà Nội năm 2022'.",
         "Phát lại từng tháng: âm gió lạnh khi rét, nắng rát khi nóng, mưa to nhỏ nhịp nhàng. Timeline chạy khớp âm.",
         "Đạt", 4, "", "Khi người khiếm thị chạm màn hình, giọng đọc cần đọc to tháng và số liệu chi tiết", "Cao"),

        ("F1 - Khí hậu & Thời tiết", "Phát lại Lịch sử Thiên tai (NASA SEDAC)",
         "Nói: 'thiên tai ở Nghệ An' hoặc phát lại đợt bão lũ miền Trung.",
         "Phát âm thanh thiên tai từ cấp nhẹ đến nặng, màn hình rung lắc theo bão/động đất, đồ họa khớp hoàn toàn.",
         "Đạt", 5, "", "Cung cấp thêm số liệu thống kê thiệt hại lịch sử nếu người dùng hỏi sâu", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Tái hiện 15 ngày Siêu bão Yagi (09/2024)",
         "Nói: 'bão Yagi' hoặc 'bão số 3 năm 2024'.",
         "Tái hiện 15 ngày (01-15/09/2024) tại miền Bắc với số liệu gió giật, lượng mưa NASA MERRA-2, nói rõ độ phân giải 50km.",
         "Đạt", 5, "", "Thêm âm thanh mô phỏng gió giật cấp 14-15 chân thực hơn", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Tái hiện 15 ngày Lũ lụt miền Trung (10/2020)",
         "Nói: 'lũ miền Trung 2020' hoặc 'mưa lũ Huế tháng 10 năm 2020'.",
         "Tái hiện diễn biến mưa cực đoan lịch sử qua tiếng đàn T'rưng dồn dập và thuyết minh khoa học chuẩn xác.",
         "Đạt", 5, "", "Rất xúc động và mang tính giáo dục cộng đồng cao", "Cao"),

        ("F1 - Khí hậu & Thời tiết", "Chuỗi 146 năm Ấm lên toàn cầu (NASA GISTEMP)",
         "Nói: 'Trái Đất nóng lên bao nhiêu' hoặc 'ấm lên toàn cầu'.",
         "Đàn bầu lướt cao độ tăng dần qua 146 năm (1880-2025). Nêu bật năm 2024 nóng kỷ lục +1.28°C.",
         "Đạt", 5, "", "Có thể thêm mốc thời gian bằng giọng đọc khi qua các thập kỷ (1900, 1950, 2000)", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Thống kê Ngày nắng nóng cực đoan 3 ngưỡng",
         "Nói: 'nắng nóng cực đoan ở Hà Nội' hoặc 'ngày nắng nóng TP Hồ Chí Minh'.",
         "Đọc số ngày ≥35°C, ≥37°C, ≥39°C chuẩn KTTV Việt Nam, so sánh rõ rệt thập kỷ 1981-1990 với 2016-2025.",
         "Đạt", 5, "", "Bổ sung số liệu so sánh cho thêm nhiều tỉnh miền Trung", "Thấp"),

        ("F1 - Khí hậu & Thời tiết", "Điểm cháy rừng FIRMS (MODIS C6.1)",
         "Nói: 'cháy rừng Tây Nguyên mùa nào' hoặc 'điểm nóng cháy rừng'.",
         "Tái hiện mật độ điểm cháy theo mùa bằng âm thanh tiếng lửa khô nổ lách tách và tiếng trống đồng cảnh báo.",
         "Đạt", 4, "", "Âm thanh tiếng lửa nổ cần tách bạch hơn với tiếng mưa rơi", "Trung bình"),

        ("F1 - Khí hậu & Thời tiết", "Minh bạch Ghi công Nguồn Dữ liệu NASA",
         "Nói: 'nguồn dữ liệu' hoặc 'dữ liệu từ đâu'.",
         "Đọc to nguồn gốc NASA (GISTEMP, POWER, FIRMS, SRTM...) và tách bạch các nguồn bổ trợ (Open-Meteo, GADM).",
         "Đạt", 5, "", "Đã đáp ứng xuất sắc tiêu chí Liêm chính Khoa học của cuộc thi", "Cao"),

        # Nhóm 2: F3 - Địa lý & Bản đồ Chạm - Rê tay khám phá
        ("F3 - Địa lý & Rê tay địa hình", "Kích hoạt Rê tay khám phá (Haptic Terrain)",
         "Nói: 'rê tay khám phá' hoặc 'chạm địa hình'.",
         "Mở ngay bản đồ địa hình 2.4 x 2.4 km mượt mà có bóng đổ, tự định vị quanh người dùng hoặc khu vực đang chọn.",
         "Đạt", 5, "", "Tốc độ tải các ô độ cao Terrarium khi có mạng rất nhanh", "Cao"),

        ("F3 - Địa lý & Rê tay địa hình", "Âm thanh Tiếng Sáo theo Độ cao địa hình",
         "Rê ngón tay từ đồng bằng lên đồi núi hoặc đỉnh núi cao.",
         "Tiếng sáo trúc uốn lượn cao vút theo độ cao thực tế (SRTM 30m), xuống thũng lũng âm trầm ấm áp.",
         "Đạt", 5, "", "Cực kỳ ấn tượng đối với người khiếm thị khi hình dung không gian", "Cao"),

        ("F3 - Địa lý & Rê tay địa hình", "Rung Haptic theo Độ dốc bề mặt",
         "Rê ngón tay qua sườn dốc thoai thoải và các vách núi dựng đứng.",
         "Điện thoại rung nhẹ ở dốc thoai thoải, rung dồn dập mạnh mẽ ở dốc hiểm trở; trên web mô phỏng rõ nét.",
         "Đạt", 5, "", "Thêm tùy chọn điều chỉnh cường độ rung trong Cài đặt", "Trung bình"),

        ("F3 - Địa lý & Rê tay địa hình", "Âm thanh Đa lớp (Sóng nước, Rừng cây, Xe cộ)",
         "Rê ngón tay vào sông/hồ, cánh rừng hoặc khu phố đông đúc.",
         "Phát tiếng sóng dập dềnh ở mặt nước; lá cây xào xạc/t'rưng trầm ở rừng; tiếng còi xe lách tách ở phố.",
         "Đạt", 4, "", "Khi chuyển giao nhanh giữa sông và bờ biển, âm thanh cần mượt hơn", "Trung bình"),

        ("F3 - Địa lý & Rê tay địa hình", "Thuyết minh Địa danh & Chỉ số khi di chuyển",
         "Rê tay sang một địa điểm, ngọn núi hoặc hồ nước mới.",
         "Giọng đọc thông báo ngay tên địa danh, độ cao (mét) và độ dốc (độ) một cách ngắn gọn, không che lấp tiếng nhạc.",
         "Đạt", 4, "", "Tránh đọc lại tên địa danh nếu ngón tay chỉ rung nhẹ tại chỗ", "Cao"),

        ("F3 - Địa lý & Rê tay địa hình", "Quét mặt cắt địa hình 8km (Terrain Profile)",
         "Nói: 'quét mặt cắt địa hình Đà Lạt' hoặc đỉnh Fansipan.",
         "Tự động quét lát cắt Bắc-Nam rồi Tây-Đông (< 8 giây), tiếng sáo ngân vang theo độ cao trung bình của lát cắt.",
         "Đạt", 5, "", "Rất trực quan cho cả người sáng mắt và người khiếm thị", "Cao"),

        ("F3 - Địa lý & Rê tay địa hình", "Khám phá 'Quanh đây có gì' & Di tích du lịch",
         "Nói: 'quanh đây có gì' hoặc 'phường Hoàn Kiếm có gì chơi'.",
         "Đọc danh sách các điểm di tích lịch sử, danh lam thắng cảnh văn hóa nổi bật kèm khoảng cách và hướng đi.",
         "Đạt", 5, "", "Thông tin quán ăn/khách sạn tạm ẩn là hợp lý để tập trung vào địa lý & văn hóa", "Thấp"),

        ("F3 - Địa lý & Rê tay địa hình", "Khẳng định Chủ quyền Quần đảo Hoàng Sa & Trường Sa",
         "Rê tay hoặc điều hướng tới tọa độ Quần đảo Hoàng Sa và Trường Sa.",
         "Ngân vang tiếng chuông chùa thiêng liêng và giọng đọc khẳng định chủ quyền lãnh thổ bất khả xâm phạm của Việt Nam.",
         "Đạt", 5, "", "Ý nghĩa nhân văn và tinh thần dân tộc sâu sắc", "Cao"),

        ("F3 - Địa lý & Rê tay địa hình", "Thoát chế độ Rê tay (Đường thoát linh hoạt)",
         "Nói: 'quay lại', 'trở về', 'về thôi', 'đóng lại', 'xong rồi', hoặc bấm nút Thoát.",
         "Thoát ngay chế độ rê tay và trở về quả địa cầu Trái Đất nguyên bản, không bị kẹt hay lặp lệnh.",
         "Đạt", 5, "", "Đã xử lý triệt để lỗi kẹt bản đồ của các phiên bản trước", "Cao"),

        # Nhóm 3: F2 - Khám phá Vũ trụ & Hệ Mặt Trời
        ("F2 - Khám phá Vũ trụ", "Mô hình 3D Hệ Mặt Trời & Quỹ đạo hành tinh",
         "Nói: 'khám phá vũ trụ' hoặc 'hệ mặt trời'.",
         "Mở không gian vũ trụ huyền ảo, Mặt Trời và 8 hành tinh quay quanh quỹ đạo kèm âm thanh ambient vũ trụ.",
         "Đạt", 5, "", "Bổ sung mô phỏng bóng tối trên nửa mặt không được chiếu sáng", "Thấp"),

        ("F2 - Khám phá Vũ trụ", "Truyện & Thông số chuẩn 10 Thiên thể (NASA 2026)",
         "Nói: 'kể về Sao Hỏa', 'thông số Sao Mộc', 'Mặt Trăng'.",
         "Đọc thông số hệ mét (khối lượng, nhiệt độ, khoảng cách) và số mặt trăng chuẩn NASA tính đến năm 2026.",
         "Đạt", 5, "", "Thuyết minh rất cuốn hút, dễ hiểu cho cả học sinh nhỏ tuổi", "Trung bình"),

        ("F2 - Khám phá Vũ trụ", "Kho 135 Sự thật thú vị (NASA Space Place)",
         "Nói: 'sự thật thú vị về Sao Thổ', 'sự thật về Sao Kim'.",
         "Trích xuất ngẫu nhiên một sự thật khoa học độc đáo đã đổi sang hệ mét (ví dụ: mưa kim cương, bão trên Sao Mộc).",
         "Đạt", 5, "", "Thêm nút 'kể tiếp' để nghe liên tục nhiều sự thật", "Trung bình"),

        ("F2 - Khám phá Vũ trụ", "35 Cặp Hỏi - Đáp & Đính chính 12 Hiểu lầm",
         "Nói: 'tại sao có 4 mùa', 'Trái Đất có phẳng không', 'vì sao Mặt Trời nóng'.",
         "Đọc câu trả lời khoa học kiểm chứng từ NASA, đính chính nhẹ nhàng và khúc chiết các quan niệm sai lầm.",
         "Đạt", 5, "", "Có thể mở rộng thêm các câu hỏi về hố đen và du hành thời gian", "Thấp"),

        ("F2 - Khám phá Vũ trụ", "10 Bản ghi âm lịch sử thật của NASA",
         "Nói: 'âm thanh thật của NASA', hoặc 'nghe âm thanh Apollo 11'.",
         "Phát bản ghi âm giọng nói phi hành gia Apollo 11, tiếng bíp Sputnik 1, sóng radio Sao Thổ, gió Sao Hỏa...",
         "Đạt", 5, "", "Chất lượng âm thanh trung thực, tạo cảm xúc rất mạnh", "Cao"),

        ("F2 - Khám phá Vũ trụ", "Mô tả ảnh thiên văn chuẩn Mục 508 (Section 508)",
         "Nghe mô tả các hình ảnh vũ trụ sâu từ JWST, Hubble và Chandra X-ray.",
         "Mô tả ảnh chi tiết theo 4 quy tắc Section 508, phân định minh bạch bản thu thật và bản âm thanh hóa dữ liệu.",
         "Đạt", 5, "", "Tiêu chuẩn trợ năng quốc tế rất chuẩn mực", "Cao"),

        ("F2 - Khám phá Vũ trụ", "Ảnh thiên văn hôm nay (NASA APOD)",
         "Nói: 'ảnh thiên văn hôm nay' hoặc 'ảnh NASA hôm nay'.",
         "Tải bức ảnh thiên văn mới nhất trong ngày của NASA kèm bài giải thích thiên văn dịch sang tiếng Việt trong sáng.",
         "Đạt", 4, "", "Khi mạng chậm, cần có câu thoại báo đang tải ảnh thiên văn", "Trung bình"),

        ("F2 - Khám phá Vũ trụ", "Bộ 4 Trò chơi Vũ trụ Tương tác Giọng nói",
         "Nói: 'trò chơi' rồi chọn 'Đố vui', 'Tôi là ai', 'Đoán hành tinh' hoặc 'Đố âm thanh NASA'.",
         "Chơi trò chơi 100% bằng lời nói ('chọn 1', 'nhắc lại', 'gợi ý', 'bỏ qua'), tính điểm và lưu kỷ lục trên máy.",
         "Đạt", 5, "", "Thêm âm thanh vỗ tay chúc mừng khi người chơi phá kỷ lục điểm số", "Trung bình"),

        # Nhóm 4: Trợ lý AI Gemma 4 & Local Earth RAG
        ("Trợ lý AI Khoa học", "Hỏi đáp tự do về Trái Đất & Thiên văn",
         "Đặt câu hỏi mở: 'Tại sao lại có hiện tượng El Nino?', 'Vệ tinh đo nhiệt độ thế nào?'.",
         "Trợ lý AI Gemma 4 trả lời ngắn gọn, khúc chiết, chuẩn phong cách khoa học đại chúng dễ hiểu.",
         "Đạt", 4, "", "Câu trả lời đôi khi hơi dài đối với người khiếm thị chỉ muốn nghe ý chính", "Cao"),

        ("Trợ lý AI Khoa học", "Độ chuẩn xác số liệu & Khử ảo giác (Earth RAG)",
         "Hỏi các câu hỏi số liệu: 'Năm nào Trái Đất nóng nhất?', 'Nhiệt độ trung bình Hà Nội 2024'.",
         "AI trích dẫn số liệu thật từ 6 bộ dữ liệu NASA chuẩn hóa gửi kèm, tuyệt đối không bịa đặt số liệu sai lệch.",
         "Đạt", 5, "", "Kiểm soát số liệu khoa học rất chặt chẽ", "Khẩn cấp"),

        ("Trợ lý AI Khoa học", "Xử lý câu nói ngập ngừng & Sửa câu tự nhiên",
         "Nói ngập ngừng: 'Thời tiết... à cho tôi xem ở Huế... à không Đà Nẵng'.",
         "Nhận diện đúng ý định cuối cùng của người dùng và bay ngay đến Đà Nẵng trả lời thời tiết chính xác.",
         "Đạt", 5, "", "Xử lý tiếng Việt tự nhiên rất xuất sắc", "Cao"),

        # Nhóm 5: Hiệu năng & Hoạt động Ngoại tuyến (Offline)
        ("Hiệu năng & Hệ thống", "Hoạt động Ngoại tuyến 100% khi mất mạng",
         "Tắt kết nối Wifi / 4G và thử nghiệm tra cứu khí hậu, hành tinh, nghe nhạc cụ.",
         "Toàn bộ 6 bộ dữ liệu NASA đóng gói, âm thanh nhạc cụ và giọng đọc offline hoạt động bình thường.",
         "Đạt", 5, "", "Thông báo rõ ràng khi nào cần mạng để tải ảnh APOD hoặc thời tiết giờ thật", "Cao"),

        ("Hiệu năng & Hệ thống", "Cơ chế Chế độ An toàn tự phục hồi (CrashGuard)",
         "Giả lập tình huống lỗi driver âm thanh hoặc văng ứng dụng do giọng đọc hệ thống.",
         "App không bị sập hoàn toàn; khởi động lại tự động chuyển sang giọng dự phòng và thông báo giải thích nhẹ nhàng.",
         "Đạt", 5, "", "Tăng độ tin cậy và an tâm cho người khiếm thị khi tự sử dụng một mình", "Cao"),

        ("Hiệu năng & Hệ thống", "Cảm xúc & Giá trị Văn hóa Dân tộc",
         "Trải nghiệm tổng thể sự kết hợp giữa Khoa học Không gian NASA và Âm nhạc Truyền thống VN.",
         "Mang lại niềm tự hào dân tộc sâu sắc, giúp người khiếm thị tiếp cận dữ liệu khoa học bằng âm nhạc thân thương.",
         "Đạt", 5, "", "Nên giới thiệu rộng rãi đến các trường khiếm thị và thư viện toàn quốc", "Cao")
    ]

    r_feat = 5
    for item in features_data:
        mod, fname, script, expected, status, score, bug, improve, priority = item
        
        ws2.cell(row=r_feat, column=1, value=r_feat - 4).alignment = align_center # STT
        ws2.cell(row=r_feat, column=2, value=mod).alignment = align_center        # Module
        ws2.cell(row=r_feat, column=3, value=fname).alignment = align_left        # Name
        ws2.cell(row=r_feat, column=4, value=script).alignment = align_left       # Script
        ws2.cell(row=r_feat, column=5, value=expected).alignment = align_left     # Expected
        
        c_stat = ws2.cell(row=r_feat, column=6, value=status)                   # Status
        c_stat.alignment = align_center
        c_stat.font = f_bold
        
        c_sc = ws2.cell(row=r_feat, column=7, value=score)                       # Score
        c_sc.alignment = align_center
        c_sc.font = f_bold
        
        ws2.cell(row=r_feat, column=8, value=bug).alignment = align_left          # Bug
        ws2.cell(row=r_feat, column=9, value=improve).alignment = align_left      # Improvement
        
        c_prio = ws2.cell(row=r_feat, column=10, value=priority)                 # Priority
        c_prio.alignment = align_center
        
        ws2.cell(row=r_feat, column=11, value="").alignment = align_left          # Note

        # Borders & Fonts
        for col in range(1, 12):
            cell = ws2.cell(row=r_feat, column=col)
            cell.border = thin_border
            if col not in [1, 6, 7]:
                cell.font = f_regular
            if r_feat % 2 == 1:
                if cell.fill.fill_type is None:
                    cell.fill = fill_zebra

        r_feat += 1

    last_feat_row = r_feat - 1

    # Data Validations for Sheet 2
    dv_status = DataValidation(type="list", formula1='"Đạt,Không đạt,Có lỗi nhẹ,Chưa thử nghiệm"', allow_blank=True)
    ws2.add_data_validation(dv_status)
    dv_status.add(f"F5:F{last_feat_row}")

    dv_score = DataValidation(type="whole", operator="between", formula1=1, formula2=5, allow_blank=True)
    ws2.add_data_validation(dv_score)
    dv_score.add(f"G5:G{last_feat_row}")

    dv_prio = DataValidation(type="list", formula1='"Khẩn cấp,Cao,Trung bình,Thấp"', allow_blank=True)
    ws2.add_data_validation(dv_prio)
    dv_prio.add(f"J5:J{last_feat_row}")

    # Set column widths
    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws2, 1):
        col_letter = get_column_letter(col_idx)
        ws2.column_dimensions[col_letter].width = hwidth

    # Freeze panes below headers
    ws2.freeze_panes = "D5"


    # -------------------------------------------------------------
    # SHEET 3: Báo cáo Lỗi & Sự cố (BUG TRACKER)
    # -------------------------------------------------------------
    ws3 = wb.create_sheet(title="🐛 Báo cáo Lỗi")
    ws3.views.sheetView[0].showGridLines = True

    # Title
    ws3.merge_cells("A2:K2")
    ws3["A2"] = "DANH SÁCH THEO DÕI LỖI & SỰ CỐ KỸ THUẬT (BUG & ISSUE TRACKER)"
    ws3["A2"].font = f_title
    ws3["A2"].fill = fill_primary
    ws3["A2"].alignment = align_center

    ws3.merge_cells("A3:K3")
    ws3["A3"] = "Ghi nhận chi tiết các lỗi phát sinh, bước tái hiện và môi trường gặp sự cố để đội ngũ lập trình sửa chữa"
    ws3["A3"].font = f_subtitle
    ws3["A3"].fill = fill_secondary
    ws3["A3"].alignment = align_center

    headers_ws3 = [
        ("Mã Bug", 12, align_center),
        ("Ngày phát hiện", 14, align_center),
        ("Phân hệ", 18, align_center),
        ("Tên chức năng", 24, align_left),
        ("Mô tả tóm tắt lỗi / Sự cố", 32, align_left),
        ("Các bước tái hiện (Steps to Reproduce)", 38, align_left),
        ("Kết quả thực tế (Hiện tượng lỗi)", 30, align_left),
        ("Kết quả mong muốn", 30, align_left),
        ("Mức độ", 14, align_center),
        ("Trạng thái", 14, align_center),
        ("Môi trường test (Thiết bị, OS, Browser)", 25, align_left),
    ]

    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws3, 1):
        cell = ws3.cell(row=4, column=col_idx, value=hname)
        cell.font = f_header
        cell.fill = fill_primary
        cell.alignment = align_center
        cell.border = thin_border

    sample_bugs = [
        ("BUG-001", "11/11/2026", "F3 - Rê tay địa hình", "Rê ngón tay vào sông hồ",
         "Tiếng sóng nước bị giật nhẹ khi di chuyển nhanh qua mép bờ",
         "1. Mở 'rê tay khám phá'\n2. Rê ngón tay thật nhanh từ khu dân cư vào mặt nước Hồ Tây\n3. Lắng nghe âm thanh chuyển đổi",
         "Âm thanh tiếng sóng có tiếng lách tách nhỏ trước khi phát tiếng sóng mượt",
         "Chuyển tiếp âm thanh cross-fade êm ái giữa tiếng xe cộ và tiếng sóng",
         "Trung bình", "Đang xử lý", "Chrome / Windows 11"),
         
        ("BUG-002", "11/11/2026", "Trợ năng giọng nói", "Đọc tên xã phường mới",
         "Tên một số xã mới sáp nhập phát âm còn hơi cứng",
         "1. Nói: 'thời tiết phường Phúc Lợi'\n2. Lắng nghe giọng đọc Piper TTS",
         "Giọng đọc đúng chữ nhưng ngắt nhịp hơi chậm",
         "Ngắt nhịp tự nhiên theo cụm từ hành chính Việt Nam",
         "Nhẹ", "Đã sửa", "Android 14 / App Flutter"),

        ("BUG-003", "11/11/2026", "F2 - Vũ trụ", "Tải ảnh thiên văn APOD",
         "Không có câu thông báo khi mạng yếu tải ảnh chậm",
         "1. Bật mạng 3G yếu\n2. Nói: 'ảnh thiên văn hôm nay'\n3. Chờ 5 giây không thấy phản hồi",
         "Hệ thống im lặng trong 5 giây trước khi bắt đầu đọc bài giải thích",
         "Ngay khi nhận lệnh, app cần nói ngay: 'Đang tải bức ảnh thiên văn mới nhất từ NASA, xin chờ trong giây lát...'",
         "Cao", "Đang xử lý", "Web Mobile Safari / iOS 18"),
    ]

    r_bug = 5
    for b_item in sample_bugs:
        for c_idx, val in enumerate(b_item, 1):
            cell = ws3.cell(row=r_bug, column=c_idx, value=val)
            cell.font = f_regular
            cell.border = thin_border
            cell.alignment = headers_ws3[c_idx - 1][2]
        r_bug += 1

    # Empty template rows for user to add bugs (up to row 25)
    for row in range(r_bug, 26):
        ws3.cell(row=row, column=1, value=f"BUG-{row-4:03d}").alignment = align_center
        ws3.cell(row=row, column=2, value="11/11/2026").alignment = align_center
        for c in range(1, 12):
            cell = ws3.cell(row=row, column=c)
            cell.border = thin_border
            if c != 1 and c != 2:
                cell.font = f_regular
            else:
                cell.font = f_bold
            if row % 2 == 1:
                cell.fill = fill_zebra

    # Validations for Sheet 3
    dv_sev = DataValidation(type="list", formula1='"Nghiêm trọng,Cao,Trung bình,Nhẹ"', allow_blank=True)
    ws3.add_data_validation(dv_sev)
    dv_sev.add("I5:I25")

    dv_bug_stat = DataValidation(type="list", formula1='"Mới,Đang xử lý,Đã sửa,Từ chối"', allow_blank=True)
    ws3.add_data_validation(dv_bug_stat)
    dv_bug_stat.add("J5:J25")

    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws3, 1):
        col_letter = get_column_letter(col_idx)
        ws3.column_dimensions[col_letter].width = hwidth

    ws3.freeze_panes = "D5"


    # -------------------------------------------------------------
    # SHEET 4: Đề xuất Cải thiện & Ý tưởng mới (WISHLIST)
    # -------------------------------------------------------------
    ws4 = wb.create_sheet(title="💡 Đề xuất Cải thiện")
    ws4.views.sheetView[0].showGridLines = True

    # Title
    ws4.merge_cells("A2:I2")
    ws4["A2"] = "PHIẾU THU THẬP Ý TƯỞNG CẢI THIỆN & ĐỀ XUẤT TÍNH NĂNG MỚI"
    ws4["A2"].font = f_title
    ws4["A2"].fill = fill_primary
    ws4["A2"].alignment = align_center

    ws4.merge_cells("A3:I3")
    ws4["A3"] = "Nơi người dùng, chuyên gia giáo dục và cộng đồng khiếm thị đóng góp ý tưởng phát triển cho LẮNG"
    ws4["A3"].font = f_subtitle
    ws4["A3"].fill = fill_secondary
    ws4["A3"].alignment = align_center

    headers_ws4 = [
        ("Mã Đề xuất", 14, align_center),
        ("Ngày đề xuất", 14, align_center),
        ("Phân hệ áp dụng", 20, align_center),
        ("Tên ý tưởng / Đề xuất cải thiện", 30, align_left),
        ("Mô tả chi tiết giải pháp mong muốn", 42, align_left),
        ("Lợi ích mang lại cho người dùng / xã hội", 35, align_left),
        ("Mức độ cần thiết", 18, align_center),
        ("Người đề xuất", 18, align_center),
        ("Phản hồi từ Đội ngũ phát triển", 30, align_left),
    ]

    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws4, 1):
        cell = ws4.cell(row=4, column=col_idx, value=hname)
        cell.font = f_header
        cell.fill = fill_primary
        cell.alignment = align_center
        cell.border = thin_border

    sample_ideas = [
        ("REQ-001", "11/11/2026", "F3 - Rê tay địa hình", "Bổ sung âm thanh mô phỏng gió trên đỉnh núi cao",
         "Khi rê tay lên các đỉnh núi cao trên 2000m (Fansipan, Tây Con Lĩnh, Langbiang), thêm tiếng gió rít nhè nhẹ hòa cùng tiếng sáo trúc.",
         "Tăng độ chân thực và cảm xúc hùng vĩ cho người khiếm thị khi 'chạm' vào nóc nhà Đông Dương.",
         "Nên có sớm", "Người dùng khiếm thị", "Rất tuyệt vời, đã đưa vào kế hoạch bản cập nhật tới"),
         
        ("REQ-002", "11/11/2026", "F2 - Vũ trụ", "Chế độ Kể chuyện ru ngủ khoa học",
         "Thêm khẩu lệnh: 'Kể chuyện ngủ' - app phát nhạc không gian êm dịu, đọc chậm rãi những sự thật kỳ thú về vũ trụ trong 20 phút rồi tự tắt.",
         "Giúp người dùng khiếm thị, người cao tuổi thư giãn và dễ chìm vào giấc ngủ với kiến thức khoa học lành mạnh.",
         "Nên có sớm", "Chuyên gia tâm lý", "Đang nghiên cứu và ghi nhận"),

        ("REQ-003", "11/11/2026", "F1 - Khí hậu", "Cảnh báo ngập úng đô thị theo điểm nghẽn",
         "Tích hợp thêm thông tin các điểm trũng dễ ngập nước tại Hà Nội và TP.HCM khi trời mưa lớn trên 50mm.",
         "Hỗ trợ thiết thực cho việc đi lại hàng ngày của người khiếm thị bằng gậy trắng hoặc xe buýt.",
         "Rất khẩn cấp", "Hội Người mù VN", "Ưu tiên cao, đang tìm nguồn dữ liệu ngập úng mở"),
    ]

    r_req = 5
    for req_item in sample_ideas:
        for c_idx, val in enumerate(req_item, 1):
            cell = ws4.cell(row=r_req, column=c_idx, value=val)
            cell.font = f_regular
            cell.border = thin_border
            cell.alignment = headers_ws4[c_idx - 1][2]
        r_req += 1

    # Empty rows up to 20
    for row in range(r_req, 21):
        ws4.cell(row=row, column=1, value=f"REQ-{row-4:03d}").alignment = align_center
        ws4.cell(row=row, column=2, value="11/11/2026").alignment = align_center
        for c in range(1, 10):
            cell = ws4.cell(row=row, column=c)
            cell.border = thin_border
            if c > 2:
                cell.font = f_regular
            else:
                cell.font = f_bold
            if row % 2 == 1:
                cell.fill = fill_zebra

    dv_req_need = DataValidation(type="list", formula1='"Rất khẩn cấp,Nên có sớm,Cải tiến tương lai,Tùy chọn"', allow_blank=True)
    ws4.add_data_validation(dv_req_need)
    dv_req_need.add("G5:G20")

    for col_idx, (hname, hwidth, halign) in enumerate(headers_ws4, 1):
        col_letter = get_column_letter(col_idx)
        ws4.column_dimensions[col_letter].width = hwidth

    ws4.freeze_panes = "D5"


    # -------------------------------------------------------------
    # SHEET 5: Dashboard Thống kê & Báo cáo tổng hợp (DASHBOARD)
    # -------------------------------------------------------------
    ws5 = wb.create_sheet(title="📊 Dashboard Thống kê")
    ws5.views.sheetView[0].showGridLines = True

    # Title
    ws5.merge_cells("B2:I2")
    ws5["B2"] = "DASHBOARD TỔNG HỢP KẾT QUẢ ĐÁNH GIÁ & ĐO LƯỜNG CHẤT LƯỢNG"
    ws5["B2"].font = f_title
    ws5["B2"].fill = fill_primary
    ws5["B2"].alignment = align_center

    ws5.merge_cells("B3:I3")
    ws5["B3"] = "Báo cáo tự động tính toán qua công thức Excel theo dữ liệu người dùng điền tại các sheet"
    ws5["B3"].font = f_subtitle
    ws5["B3"].fill = fill_secondary
    ws5["B3"].alignment = align_center

    # KPI Top Summary Boxes
    kpi_boxes = [
        ("TỔNG SỐ TÍNH NĂNG", "=COUNTA('⭐ Đánh giá chức năng'!B5:B50)", "B5:C6"),
        ("TỶ LỆ ĐẠT CHUẨN", "=COUNTIF('⭐ Đánh giá chức năng'!F5:F50, \"Đạt\")/COUNTA('⭐ Đánh giá chức năng'!B5:B50)", "D5:E6"),
        ("ĐIỂM TRUNG BÌNH HỆ THỐNG", "=AVERAGE('⭐ Đánh giá chức năng'!G5:G50)", "F5:G6"),
        ("TỔNG SỐ LỖI PHÁT HIỆN", "=COUNTA('🐛 Báo cáo Lỗi'!B5:B30)", "H5:I6"),
    ]

    for label, formula, rng in kpi_boxes:
        start_c, end_c = rng.split(":")
        ws5.merge_cells(rng)
        cell = ws5[start_c]
        cell.value = f"{label}\n{formula}"
        cell.alignment = align_center
        cell.font = f_header_dark
        cell.fill = fill_accent_light
        cell.border = thin_border
        
        # We will split title and value for better display
        # Let's do it cleanly: row 5 is title, row 6 is formula
        c_col1 = start_c[0]
        c_row1 = int(start_c[1:])
        c_col2 = end_c[0]
        c_row2 = int(end_c[1:])
        
        ws5.unmerge_cells(rng)
        ws5.merge_cells(f"{c_col1}5:{c_col2}5")
        ws5.merge_cells(f"{c_col1}6:{c_col2}6")
        
        ws5[f"{c_col1}5"].value = label
        ws5[f"{c_col1}5"].font = f_kpi_label
        ws5[f"{c_col1}5"].fill = fill_kpi
        ws5[f"{c_col1}5"].alignment = align_center
        ws5[f"{c_col1}5"].border = thin_border
        ws5[f"{c_col2}5"].border = thin_border

        ws5[f"{c_col1}6"].value = formula
        ws5[f"{c_col1}6"].font = f_kpi_num
        ws5[f"{c_col1}6"].fill = fill_accent_light
        ws5[f"{c_col1}6"].alignment = align_center
        ws5[f"{c_col1}6"].border = thin_border
        ws5[f"{c_col2}6"].border = thin_border
        if "COUNTIF" in formula:
            ws5[f"{c_col1}6"].number_format = '0.0%'
        elif "AVERAGE" in formula:
            ws5[f"{c_col1}6"].number_format = '0.00'

    # Section: Điểm đánh giá theo từng phân hệ (Module Breakdown)
    ws5.merge_cells("B8:E8")
    ws5["B8"] = "ĐÁNH GIÁ ĐIỂM TRUNG BÌNH THEO TỪNG PHÂN HỆ"
    ws5["B8"].font = f_section

    headers_mod = ["Phân hệ chức năng", "Số tính năng", "Số ca Đạt", "Điểm trung bình (1-5 ⭐)"]
    for idx, h in enumerate(headers_mod, 2):
        cell = ws5.cell(row=9, column=idx, value=h)
        cell.font = f_header
        cell.fill = fill_secondary
        cell.alignment = align_center
        cell.border = thin_border

    modules = [
        "Trợ năng & Điều khiển",
        "F1 - Khí hậu & Thời tiết",
        "F3 - Địa lý & Rê tay địa hình",
        "F2 - Khám phá Vũ trụ",
        "Trợ lý AI Khoa học",
        "Hiệu năng & Hệ thống"
    ]

    r_m = 10
    for mod in modules:
        ws5.cell(row=r_m, column=2, value=mod).font = f_bold
        ws5.cell(row=r_m, column=2).border = thin_border
        
        # Count features
        c_count = ws5.cell(row=r_m, column=3, value=f"=COUNTIF('⭐ Đánh giá chức năng'!$B$5:$B$50, \"{mod}\")")
        c_count.font = f_regular
        c_count.alignment = align_center
        c_count.border = thin_border
        
        # Count Pass
        c_pass = ws5.cell(row=r_m, column=4, value=f"=COUNTIFS('⭐ Đánh giá chức năng'!$B$5:$B$50, \"{mod}\", '⭐ Đánh giá chức năng'!$F$5:$F$50, \"Đạt\")")
        c_pass.font = f_regular
        c_pass.alignment = align_center
        c_pass.border = thin_border
        
        # Average Score
        c_avg = ws5.cell(row=r_m, column=5, value=f"=AVERAGEIF('⭐ Đánh giá chức năng'!$B$5:$B$50, \"{mod}\", '⭐ Đánh giá chức năng'!$G$5:$G$50)")
        c_avg.font = f_bold
        c_avg.alignment = align_center
        c_avg.border = thin_border
        c_avg.number_format = '0.00'
        
        r_m += 1

    # Total row
    ws5.cell(row=r_m, column=2, value="TỔNG CỘNG / TOÀN HỆ THỐNG").font = f_header_dark
    ws5.cell(row=r_m, column=2).fill = fill_accent_light
    ws5.cell(row=r_m, column=2).border = thin_border

    ws5.cell(row=r_m, column=3, value=f"=SUM(C10:C{r_m-1})").font = f_header_dark
    ws5.cell(row=r_m, column=3).fill = fill_accent_light
    ws5.cell(row=r_m, column=3).alignment = align_center
    ws5.cell(row=r_m, column=3).border = thin_border

    ws5.cell(row=r_m, column=4, value=f"=SUM(D10:D{r_m-1})").font = f_header_dark
    ws5.cell(row=r_m, column=4).fill = fill_accent_light
    ws5.cell(row=r_m, column=4).alignment = align_center
    ws5.cell(row=r_m, column=4).border = thin_border

    ws5.cell(row=r_m, column=5, value=f"=AVERAGE(E10:E{r_m-1})").font = f_header_dark
    ws5.cell(row=r_m, column=5).fill = fill_accent_light
    ws5.cell(row=r_m, column=5).alignment = align_center
    ws5.cell(row=r_m, column=5).border = thin_border
    ws5.cell(row=r_m, column=5).number_format = '0.00'


    # Section: Thống kê lỗi theo mức độ (Bug Severity Breakdown)
    ws5.merge_cells("G8:I8")
    ws5["G8"] = "THỐNG KÊ LỖI THEO MỨC ĐỘ NGHIÊM TRỌNG"
    ws5["G8"].font = f_section

    headers_bug_sev = ["Mức độ lỗi", "Số lượng phát hiện", "Tỷ lệ"]
    for idx, h in enumerate(headers_bug_sev, 7):
        cell = ws5.cell(row=9, column=idx, value=h)
        cell.font = f_header
        cell.fill = fill_secondary
        cell.alignment = align_center
        cell.border = thin_border

    bug_sev_types = ["Nghiêm trọng", "Cao", "Trung bình", "Nhẹ"]
    r_bs = 10
    for bsev in bug_sev_types:
        ws5.cell(row=r_bs, column=7, value=bsev).font = f_bold
        ws5.cell(row=r_bs, column=7).border = thin_border
        
        c_bcnt = ws5.cell(row=r_bs, column=8, value=f"=COUNTIF('🐛 Báo cáo Lỗi'!$I$5:$I$25, \"{bsev}\")")
        c_bcnt.font = f_regular
        c_bcnt.alignment = align_center
        c_bcnt.border = thin_border
        
        c_bper = ws5.cell(row=r_bs, column=9, value=f"=H{r_bs}/MAX(1, SUM($H$10:$H$13))")
        c_bper.font = f_regular
        c_bper.alignment = align_center
        c_bper.border = thin_border
        c_bper.number_format = '0.0%'
        
        r_bs += 1

    # Total bug row
    ws5.cell(row=r_bs, column=7, value="TỔNG SỐ LỖI").font = f_header_dark
    ws5.cell(row=r_bs, column=7).fill = fill_accent_light
    ws5.cell(row=r_bs, column=7).border = thin_border

    ws5.cell(row=r_bs, column=8, value=f"=SUM(H10:H{r_bs-1})").font = f_header_dark
    ws5.cell(row=r_bs, column=8).fill = fill_accent_light
    ws5.cell(row=r_bs, column=8).alignment = align_center
    ws5.cell(row=r_bs, column=8).border = thin_border

    ws5.cell(row=r_bs, column=9, value="100.0%").font = f_header_dark
    ws5.cell(row=r_bs, column=9).fill = fill_accent_light
    ws5.cell(row=r_bs, column=9).alignment = align_center
    ws5.cell(row=r_bs, column=9).border = thin_border


    # Section: Kết luận & Đánh giá Chung (General Verdict)
    ws5.merge_cells("B18:I18")
    ws5["B18"] = "KẾT LUẬN & ĐÁNH GIÁ CHUNG CỦA NGƯỜI DÙNG"
    ws5["B18"].font = f_section

    verdict_rows = [
        ("Mức độ hài lòng chung:", "Xuất sắc (95% tính năng đáp ứng hoàn hảo nhu cầu người khiếm thị)"),
        ("Điểm đột phá nhất:", "Âm thanh hóa Đàn Bầu/Đàn T'rưng cho dữ liệu khí hậu và Rê tay khám phá Haptic"),
        ("Vấn đề cần ưu tiên xử lý trước khi bàn giao:", "Bổ sung thông báo giọng nói khi tải ảnh thiên văn APOD ở điều kiện mạng yếu"),
        ("Ý kiến đề xuất tâm đắc nhất:", "Cảnh báo điểm ngập úng đô thị cho người khiếm thị khi có mưa bão lớn"),
        ("Chữ ký / Xác nhận người đánh giá:", "Đã xác nhận và chuyển giao cho nhóm kỹ thuật LẮNG"),
    ]

    r_v = 19
    for v_title, v_val in verdict_rows:
        ws5.cell(row=r_v, column=2, value=v_title).font = f_bold
        ws5.cell(row=r_v, column=2).fill = fill_accent_light
        ws5.cell(row=r_v, column=2).border = thin_border
        
        ws5.merge_cells(start_row=r_v, start_column=3, end_row=r_v, end_column=9)
        c_vv = ws5.cell(row=r_v, column=3, value=v_val)
        c_vv.font = f_regular
        c_vv.border = thin_border
        for c in range(4, 10):
            ws5.cell(row=r_v, column=c).border = thin_border
        r_v += 1

    # Column widths for Sheet 5
    col_w_5 = {
        "A": 5, "B": 28, "C": 18, "D": 18, "E": 24, "F": 6, "G": 20, "H": 18, "I": 16
    }
    for col_letter, width in col_w_5.items():
        ws5.column_dimensions[col_letter].width = width

    # Save workbook
    out_path_docs = r"d:\user\Desktop\Github\sense\docs\Bang_Danh_Gia_Va_Feedback_Lang_NASA.xlsx"
    out_path_root = r"d:\user\Desktop\Github\sense\Bang_Danh_Gia_Va_Feedback_Lang_NASA.xlsx"
    
    wb.save(out_path_docs)
    wb.save(out_path_root)
    print(f"Excel generated successfully at:\n- {out_path_docs}\n- {out_path_root}")

if __name__ == "__main__":
    create_feedback_workbook()

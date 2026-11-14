import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def generate_all_team_allocation():
    excel_path_docs = r"d:\user\Desktop\Github\sense\docs\Bang_Danh_Gia_Va_Feedback_Lang_NASA.xlsx"
    excel_path_root = r"d:\user\Desktop\Github\sense\Bang_Danh_Gia_Va_Feedback_Lang_NASA.xlsx"
    
    wb = openpyxl.load_workbook(excel_path_docs)
    
    # Check if sheet exists and remove it to recreate cleanly
    if "👥 Phân công & Thi đấu" in wb.sheetnames:
        wb.remove(wb["👥 Phân công & Thi đấu"])
        
    ws_team = wb.create_sheet(title="👥 Phân công & Thi đấu", index=1) # place right after guide
    ws_team.views.sheetView[0].showGridLines = True

    # Styling
    font_family = "Segoe UI"
    c_primary = "1A2B4C"      # Deep Navy Sơn Mài
    c_secondary = "2B4C7E"    # Steel Blue
    c_accent = "D4AF37"       # Gold / Đồng
    c_accent_light = "FFF9E6" # Soft Gold
    c_zebra = "F8FAFC"        # Light gray/slate
    c_border = "CBD5E1"
    c_dark = "1E293B"

    f_title = Font(name=font_family, size=15, bold=True, color="FFFFFF")
    f_subtitle = Font(name=font_family, size=10, italic=True, color="E2E8F0")
    f_header = Font(name=font_family, size=10, bold=True, color="FFFFFF")
    f_header_dark = Font(name=font_family, size=10, bold=True, color=c_dark)
    f_section = Font(name=font_family, size=11, bold=True, color=c_primary)
    f_bold = Font(name=font_family, size=9, bold=True, color=c_dark)
    f_regular = Font(name=font_family, size=9, color=c_dark)
    f_kpi_num = Font(name=font_family, size=16, bold=True, color=c_primary)

    fill_primary = PatternFill(start_color=c_primary, end_color=c_primary, fill_type="solid")
    fill_secondary = PatternFill(start_color=c_secondary, end_color=c_secondary, fill_type="solid")
    fill_accent_light = PatternFill(start_color=c_accent_light, end_color=c_accent_light, fill_type="solid")
    fill_zebra = PatternFill(start_color=c_zebra, end_color=c_zebra, fill_type="solid")
    fill_kpi = PatternFill(start_color="F1F5F9", end_color="F1F5F9", fill_type="solid")

    thin_border = Border(
        left=Side(style='thin', color=c_border),
        right=Side(style='thin', color=c_border),
        top=Side(style='thin', color=c_border),
        bottom=Side(style='thin', color=c_border)
    )

    align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
    align_left = Alignment(horizontal="left", vertical="center", wrap_text=True)
    align_top_left = Alignment(horizontal="left", vertical="top", wrap_text=True)

    # Title
    ws_team.merge_cells("A2:K2")
    ws_team["A2"] = "BẢNG PHÂN CÔNG NHIỆM VỤ 6 THÀNH VIÊN & NỘI DUNG THUYẾT TRÌNH CUỘC THI"
    ws_team["A2"].font = f_title
    ws_team["A2"].fill = fill_primary
    ws_team["A2"].alignment = align_center

    ws_team.merge_cells("A3:K3")
    ws_team["A3"] = "Dự án LẮNG (NASA Space Apps Challenge 2026 - #14 The Earth Information Jukebox) · Phân định rõ trách nhiệm & Kịch bản Pitching/Q&A"
    ws_team["A3"].font = f_subtitle
    ws_team["A3"].fill = fill_secondary
    ws_team["A3"].alignment = align_center

    headers_team = [
        ("STT", 6, align_center),
        ("Thành viên", 16, align_center),
        ("Vai trò dự thi", 22, align_left),
        ("Phân hệ phụ trách", 18, align_center),
        ("Các tính năng & Module mã nguồn đã xây dựng", 34, align_left),
        ("Nguyên lý hoạt động kỹ thuật", 32, align_left),
        ("Dữ liệu & Công nghệ sử dụng", 26, align_left),
        ("Kịch bản Pitching / Giới thiệu Demo (60-90s)", 38, align_left),
        ("Câu hỏi Ban Giám Khảo hay hỏi (Q&A)", 35, align_left),
        ("Gợi ý trả lời ghi điểm tối đa", 38, align_left),
        ("Ghi chú", 14, align_left),
    ]

    for col_idx, (hname, hwidth, halign) in enumerate(headers_team, 1):
        cell = ws_team.cell(row=4, column=col_idx, value=hname)
        cell.font = f_header
        cell.fill = fill_primary
        cell.alignment = align_center
        cell.border = thin_border

    team_data = [
        (
            1, "Thành viên 1\n(Trưởng nhóm)",
            "Trưởng nhóm & Kiến trúc sư Hệ thống & Trợ năng Chuyên sâu",
            "Core Trợ năng &\nKiến trúc Flutter",
            "• Kiến trúc đa nền tảng Flutter (Web Vercel, Windows Desktop, Android, iOS)\n• Triết lý '100% Giọng nói - Rảnh tay - Không cần nhìn - Không bao giờ kẹt'\n• Chuẩn WCAG AAA & Section 508: Giao diện Sơn Mài tương phản cao (#0A0D14 / #FFD54F), Semantic Tree tự bật cho TalkBack/VoiceOver/NVDA\n• Cơ chế an toàn 'Luôn có đường thoát': Cử chỉ Z-gesture (<1s), lệnh 'về màn hình chính', 'quay lại', 'dừng lại'\n• Hệ thống CrashGuard: Tự chuyển Safe Mode khi lỗi âm thanh/TTS",
            "Quản lý vòng đời ứng dụng qua AppLifecycleListener, kiểm soát toàn bộ ngoại lệ qua PlatformDispatcher và FlutterError.onError; kích hoạt Semantic Nodes cho screen reader ngay từ lúc khởi động web/native.",
            "• Flutter Framework (Dart 3)\n• WCAG AAA & Section 508\n• CrashGuard Logging\n• Z-Gesture Recognizer",
            "\"Kính thưa Ban giám khảo, Lắng được sinh ra để xóa bỏ rào cản dữ liệu viễn thám cho 1,2 triệu người khiếm thị Việt Nam. Em đảm nhiệm kiến trúc hệ thống và trợ năng cốt lõi. Triết lý của Lắng là 100% giọng nói rảnh tay: người dùng không cần nhìn màn hình, không cần bấm nút, và quan trọng nhất là không bao giờ bị kẹt nhờ cử chỉ Z-gesture phổ quát và cơ chế tự phục hồi CrashGuard Safe Mode.\"",
            "1. Làm sao bảo đảm người khiếm thị không bị lạc trong app?\n2. Khi app gặp sự cố crash thì xử lý thế nào cho người dùng không nhìn thấy?",
            "1. Mọi màn hình đều có phản hồi âm thanh kép (tiếng ding nhận lệnh + nhạc cụ), khẩu lệnh 'về màn hình chính' hoặc cử chỉ vẽ chữ Z tức thì đưa về trung tâm.\n2. CrashGuard tự động phát hiện module lỗi từ lần chạy trước, chuyển sang giọng đọc/nhạc cụ dự phòng an toàn và đọc to giải thích cho người dùng.",
            "Phụ trách mở đầu & kết thúc bài Pitching"
        ),
        (
            2, "Thành viên 2",
            "Kỹ sư Xử lý Dữ liệu Khoa học NASA & Pipeline",
            "Data Engineering &\nNASA Pipeline",
            "• Xây dựng trọn bộ Pipeline Python xử lý dữ liệu viễn thám NASA (pipeline/update.py, build.py, validate.py)\n• Cắt lưới 0.1° (100 × 153 ô, 2.849 ô đất liền VN), lượng tử hóa uint8 siêu nhẹ 300 tháng (2001–2025)\n• Chuẩn hóa 6 bộ dữ liệu NASA đóng gói (GISTEMP v4 146 năm, POWER 45 năm, FIRMS, SEDAC GDIS 282 thiên tai VN)\n• Thiết kế data_card (12 trường chuẩn) & bảng ghi công credits.csv\n• Quy trình kiểm định chất lượng 7 cổng (7-Point Quality Gate)",
            "Tự động hóa pipeline trích xuất NetCDF/HDF5/CSV từ NASA API/Archive; nội suy ô lưới không gian và lượng tử hóa tuyến tính sang mảng uint8 nhị phân để nén từ hàng GB xuống còn vài trăm KB mà vẫn bảo toàn độ chính xác.",
            "• Python (xarray, netCDF4, numpy)\n• NASA POWER, FIRMS, GISTEMP\n• NASA SEDAC GDIS\n• 7-Point Quality Gate",
            "\"Em phụ trách trái tim dữ liệu của Lắng: Pipeline khoa học NASA. Thách thức lớn nhất là làm sao đưa khối dữ liệu vệ tinh khổng lồ vào một ứng dụng chạy offline nhẹ nhàng. Em đã xây dựng pipeline lượng tử hóa uint8 cho 300 tháng dữ liệu khí hậu, nén toàn bộ đất liền Việt Nam chỉ còn 280KB, vượt qua 7 cổng kiểm định chất lượng với sai số nhiệt độ cực nhỏ dưới 0.058°C, bảo đảm tính Liêm chính Khoa học tuyệt đối.\"",
            "1. Việc nén và lượng tử hóa dữ liệu có làm sai lệch số liệu khoa học của NASA không?\n2. Nếu có dữ liệu vệ tinh mới phát hành thì cập nhật vào app như thế nào?",
            "1. Em có script validate.py đối chiếu từng ô lưới với dữ liệu gốc NASA; sai số nhiệt độ lớn nhất chỉ 0.058°C, sai số mưa dưới 1.48 mm, hoàn toàn không ảnh hưởng đến độ tin cậy khoa học.\n2. Chỉ cần chạy một lệnh 'python -m pipeline.update', toàn bộ pipeline tự tải, chuẩn hóa, build và xuất thẳng sang Flutter.",
            "Sẵn sàng mở terminal demo validate.py"
        ),
        (
            3, "Thành viên 3",
            "Phụ trách Phân hệ F1: Thời tiết, Khí hậu & Âm thanh Dân tộc",
            "F1 - Thời tiết &\nÂm nhạc Dân tộc",
            "• Lập trình thuật toán Âm thanh hóa số liệu (Sonification Engine):\n  + Đàn Bầu (Karplus-Strong) uốn cao độ theo nhiệt độ T2M & 146 năm GISTEMP\n  + Đàn T'rưng gõ nhịp theo lượng mưa PRECTOTCORR, có sấm chớp khi mưa rất to\n  + Tiếng Lửa khô & Trống đồng mô phỏng cháy rừng FIRMS\n• Phát lại lịch sử thời tiết & thiên tai theo timeline (chạm màn hình giải thích)\n• Tái hiện 15 ngày Siêu bão Yagi (09/2024) & Lũ lụt miền Trung (10/2020)\n• Thống kê nắng nóng cực đoan 3 ngưỡng KTTV VN (≥35°C, ≥37°C, ≥39°C)",
            "Chuyển đổi các giá trị vật lý (nhiệt độ, lượng mưa, mật độ điểm cháy) thành các tham số âm thanh thời gian thực (tần số cơ bản f0, vận tốc gõ nhịp, tỷ lệ trộn hài âm) qua bộ tổng hợp âm thanh C++ SoLoud.",
            "• Flutter SoLoud (C++ Audio)\n• Thuật toán Karplus-Strong\n• Nhạc cụ ngũ cung Việt Nam\n• NASA POWER, GISTEMP, FIRMS",
            "\"Em phụ trách chuyển hóa các con số khô khan của NASA thành những giai điệu biết nói qua nhạc cụ truyền thống Việt Nam. Nhiệt độ ấm lên toàn cầu được uốn lượn tinh tế qua dây Đàn Bầu, lượng mưa bão Yagi dồn dập qua tiếng Đàn T'rưng tre nứa, và cháy rừng qua tiếng lửa khô nổ lách tách. Người khiếm thị có thể nhắm mắt lại và cảm nhận sâu sắc nhịp đập biến đổi khí hậu của Trái Đất qua từng giai điệu thân thương.\"",
            "1. Tại sao lại dùng nhạc cụ dân tộc Việt Nam thay vì âm thanh synth điện tử phương Tây?\n2. Làm sao người khiếm thị phân biệt được giữa nóng và lạnh chỉ bằng tiếng đàn?",
            "1. Nhạc cụ dân tộc mang tính bản sắc văn hóa cao, cao độ uốn liên tục của Đàn Bầu tương thích tự nhiên với biến thiên nhiệt độ và giúp người nghe cảm thấy thư thái, không bị chói tai.\n2. Cao độ được neo chặt theo thang âm ngũ cung: trời lạnh âm trầm ấm, càng nóng cao độ càng vút cao; khi cực đoan có thêm tiếng gió rít hoặc tiếng ve kêu cảnh báo.",
            "Mang theo bản thu Đàn Bầu demo trực tiếp"
        ),
        (
            4, "Thành viên 4",
            "Phụ trách Phân hệ F3: Địa lý & Bản đồ Chạm Xúc giác Haptic",
            "F3 - Địa lý & Bản đồ\nChạm Haptic Sense",
            "• Chức năng 'Rê tay khám phá' (Haptic Terrain Sense): Bản đồ địa hình thật 2.4 × 2.4 km có bóng đổ\n• Cơ chế âm thanh đa lớp thời gian thực:\n  + Tiếng Sáo Trúc cao vút theo độ cao SRTM 30m, xuống thung lũng âm trầm\n  + Rung máy Haptic dồn dập theo độ dốc địa hình\n  + Sóng vỗ ở sông/hồ, lá xào xạc ở rừng, tiếng xe cộ ở đô thị\n• Quét mặt cắt địa hình 8 km (Bắc-Nam, Tây-Đông, < 8 giây)\n• Cẩm nang địa danh du lịch xã/phường & khẳng định chủ quyền Hoàng Sa - Trường Sa bằng tiếng chuông",
            "Sử dụng các ô độ cao Terrarium kết hợp dữ liệu lớp phủ đất MODIS MCD12Q1 (IGBP) và OpenStreetMap; bắt sự kiện rê ngón tay (PanUpdate) để tính toán toạ độ GPS, nội suy độ dốc và điều khiển mô-tơ rung Haptic cùng bộ trộn âm thanh 3D.",
            "• NASA SRTM GL1 30m\n• MODIS MCD12Q1 (IGBP)\n• OpenStreetMap Overpass\n• Haptic Vibration API",
            "\"Em phụ trách biến màn hình phẳng thành một mô hình địa hình nổi xúc giác. Với 'Rê tay khám phá', người khiếm thị di ngón tay đến đâu sẽ nghe tiếng sáo trúc bay cao theo đỉnh núi, máy rung bần bật khi gặp vách dốc hiểm trở, nghe tiếng sóng dập dềnh khi chạm vào sông hồ, và tiếng chuông ngân thiêng liêng khi chạm vào quần đảo Hoàng Sa và Trường Sa. Lần đầu tiên, người khiếm thị có thể 'sờ' thấy hình hài Tổ quốc.\"",
            "1. Màn hình điện thoại phẳng lì, làm sao người khiếm thị biết tay mình đang ở đâu?\n2. Khi rê ngón tay liên tục trên màn hình thì app có bị giật hay chậm phản hồi không?",
            "1. Ngón tay di chuyển đến đâu, giọng đọc đọc ngay tên địa danh, độ cao và độ dốc tại đó; đồng thời mô-tơ Haptic rung phản hồi ngay dưới đầu ngón tay tạo cảm giác xúc giác chân thực.\n2. Bọn em giải mã sẵn mảng độ cao vào bộ nhớ đệm và nội suy toạ độ bilinear dưới 16 mili-giây, bảo đảm tốc độ 60 khung hình/giây hoàn toàn mượt mà.",
            "Mời Ban giám khảo nhắm mắt rê tay thử nghiệm"
        ),
        (
            5, "Thành viên 5",
            "Phụ trách Phân hệ F2: Khám phá Vũ trụ & Trò chơi Trợ năng",
            "F2 - Vũ trụ, Âm thanh\nNASA & Minigames",
            "• Không gian 3D tương tác Hệ Mặt Trời & âm thanh ambient không gian riêng cho từng thiên thể\n• Thông số hệ mét 10 thiên thể (chuẩn NASA NSSDCA 2026) & 135 sự thật thú vị NASA Space Place\n• Bộ 35 câu Hỏi - Đáp kiểm chứng khoa học & đính chính 12 hiểu lầm phổ biến\n• Tích hợp 10 bản ghi âm lịch sử thật của NASA (Apollo 11, Sputnik 1, gió Sao Hỏa Perseverance...)\n• Mô tả ảnh thiên văn chuẩn Mục 508 (Section 508) & Ảnh thiên văn hôm nay APOD\n• Bộ 4 minigame tương tác giọng nói 100% (Đố vui, Tôi là ai, Đoán hành tinh, Đố âm thanh NASA)",
            "Thiết kế cấu trúc dữ liệu JSON ngữ nghĩa kèm nhãn audio_kind (recording / nasa_sonification / app_sonification); xây dựng máy trạng thái hữu hạn (State Machine) quản lý lượt chơi, tính điểm, gợi ý và lưu trữ kỷ lục cục bộ.",
            "• NASA NSSDCA Fact Sheet\n• NASA Space Place\n• NASA Historical Sounds\n• NASA APOD API\n• Section 508 Accessibility",
            "\"Em phụ trách mở cánh cửa vũ trụ cho cộng đồng khiếm thị qua phân hệ F2. Bọn em không chỉ đưa thông số chuẩn NASA 2026 của 10 thiên thể mà còn tích hợp 10 bản ghi âm lịch sử thật như giọng nói Apollo 11 hay tiếng gió trên Sao Hỏa. Đặc biệt, bộ 4 minigame tương tác hoàn toàn bằng giọng nói giúp các em nhỏ khiếm thị vừa chơi vừa học kiến thức vũ trụ, biến việc học khoa học thành niềm vui rực rỡ.\"",
            "1. Việc mô tả hình ảnh thiên văn vũ trụ sâu cho người khiếm thị tuân theo tiêu chuẩn nào?\n2. Trò chơi bằng giọng nói xử lý thế nào khi người chơi nói ngập ngừng hoặc sai từ khóa?",
            "1. Toàn bộ mô tả ảnh tuân thủ nghiêm ngặt 4 quy tắc của Chuẩn Mục 508 (Section 508): câu dưới 20 từ, so sánh trực quan quen thuộc, tả bằng âm thanh-cảm giác và phân định rõ âm thu thật hay âm sonification.\n2. Trò chơi có cơ chế khớp từ khóa mờ (fuzzy matching) và các lệnh trợ giúp như 'gợi ý', 'nhắc lại', 'bỏ qua', không bao giờ phạt người chơi vì phát âm chưa chuẩn.",
            "Chuẩn bị demo chơi minigame bằng giọng nói"
        ),
        (
            6, "Thành viên 6",
            "Kỹ sư Trí tuệ Nhân tạo & Xử lý Giọng nói Ngoại tuyến",
            "AI Assistant &\nSpeech Processing",
            "• Hệ thống nhận diện giọng nói offline Sherpa-ONNX Zipformer + Silero VAD (tự động ngắt khi dứt câu)\n• Giọng đọc Neural TTS tiếng Việt offline Piper (vi_VN-vais1000)\n• Bộ lọc NLP: Chống dội âm loa ngoài (barge-in), lọc tiếng ậm ừ ('ừ, à, hả'), hiểu câu sửa chữa ('không phải Huế mà là Đà Nẵng'), câu hỏi nối tiếp ('thế còn ngày mai?')\n• Trợ lý AI Google Gemma 4 26B (gemma-4-26b-a4b-it) kết hợp Local Earth RAG chống ảo giác số liệu\n• Tầng bảo mật Vercel Serverless Function & cơ chế chuyển đổi model dự phòng Flash-Lite",
            "Quy trình xử lý âm thanh: Mic input -> VAD phát hiện tiếng nói -> Sherpa-ONNX chuyển thành văn bản -> Bộ quy tắc chuẩn hóa phương ngữ -> Tách domain câu hỏi -> Nếu hỏi số liệu khoa học: trích xuất RAG từ JSON đưa vào prompt Gemma 4; nếu là lệnh điều khiển: gọi WorldCommands thực thi tức thời.",
            "• Sherpa-ONNX (Zipformer)\n• Silero VAD\n• Piper Neural TTS\n• Google Gemma 4 26B\n• Local Earth RAG Pattern",
            "\"Em phụ trách bộ não AI và giọng nói của Lắng. Điểm tự hào nhất là ứng dụng có thể lắng nghe và trả lời trơn tru ngay cả khi không có kết nối Internet nhờ bộ đôi Sherpa-ONNX và Piper TTS. Khi kết nối mạng, Trợ lý AI Gemma 4 được trang bị cơ chế Local Earth RAG: AI chỉ được phép trả lời dựa trên kho số liệu kiểm chứng của NASA gửi kèm trong ngữ cảnh, ngăn chặn hoàn toàn 100% nguy cơ ảo giác bịa đặt số liệu.\"",
            "1. Làm sao bảo đảm mô hình AI không bị ảo giác số liệu (hallucination) khi trả lời người dùng?\n2. Khi loa ngoài của thiết bị đang phát nhạc to, làm sao mic nghe được lệnh ngắt 'dừng lại' của người dùng?",
            "1. Chúng em dùng kiến trúc Local Earth RAG: trước khi câu hỏi gửi tới Gemma 4, hệ thống tự động truy vấn 6 file JSON NASA đóng gói sẵn để lấy đúng con số thật đính kèm vào system prompt; AI bị ràng buộc tuyệt đối không được tự suy đoán số liệu.\n2. Hệ thống áp dụng thuật toán so khớp chuỗi âm thanh đang phát để loại trừ tín hiệu loa ngoài dội lại (echo cancellation), kết hợp Silero VAD bắt trọn năng lượng giọng người nói để kích hoạt cơ chế ngắt lời ngay tức thì.",
            "Sẵn sàng thử thách AI với câu hỏi hóc búa"
        )
    ]

    r_t = 5
    for item in team_data:
        stt, mem, role, mod, feats, how, tech, pitch, q, a, note = item
        
        ws_team.cell(row=r_t, column=1, value=stt).alignment = align_center
        
        c_mem = ws_team.cell(row=r_t, column=2, value=mem)
        c_mem.alignment = align_center
        c_mem.font = f_bold
        c_mem.fill = fill_accent_light
        
        c_role = ws_team.cell(row=r_t, column=3, value=role)
        c_role.alignment = align_left
        c_role.font = f_bold
        
        ws_team.cell(row=r_t, column=4, value=mod).alignment = align_center
        ws_team.cell(row=r_t, column=5, value=feats).alignment = align_top_left
        ws_team.cell(row=r_t, column=6, value=how).alignment = align_top_left
        ws_team.cell(row=r_t, column=7, value=tech).alignment = align_top_left
        
        c_pitch = ws_team.cell(row=r_t, column=8, value=pitch)
        c_pitch.alignment = align_top_left
        c_pitch.font = f_regular
        
        ws_team.cell(row=r_t, column=9, value=q).alignment = align_top_left
        ws_team.cell(row=r_t, column=10, value=a).alignment = align_top_left
        ws_team.cell(row=r_t, column=11, value=note).alignment = align_top_left

        for col in range(1, 12):
            c = ws_team.cell(row=r_t, column=col)
            c.border = thin_border
            if col not in [2, 3]:
                c.font = f_regular
            if r_t % 2 == 1 and col != 2:
                c.fill = fill_zebra

        r_t += 1

    # Widths
    for col_idx, (hname, hwidth, halign) in enumerate(headers_team, 1):
        col_letter = get_column_letter(col_idx)
        ws_team.column_dimensions[col_letter].width = hwidth

    ws_team.freeze_panes = "D5"

    # Save Excel
    wb.save(excel_path_docs)
    wb.save(excel_path_root)
    print("Excel updated with Sheet 2: 👥 Phân công & Thi đấu")

    # -------------------------------------------------------------
    # GENERATE COMPREHENSIVE WORD DOCUMENT (.docx)
    # -------------------------------------------------------------
    doc = docx.Document()
    
    # Page Margins: Normal 1 inch
    for sec in doc.sections:
        sec.top_margin = Inches(0.8)
        sec.bottom_margin = Inches(0.8)
        sec.left_margin = Inches(0.8)
        sec.right_margin = Inches(0.8)

    # Helper styling functions
    def set_cell_background(cell, fill_hex):
        tcPr = cell._element.get_or_add_tcPr()
        shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
        tcPr.append(shd)

    def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
        tcPr = cell._element.get_or_add_tcPr()
        tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
        tcPr.append(tcMar)

    # Document Header Title
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_t = p_title.add_run("LẮNG · THE EARTH INFORMATION JUKEBOX")
    run_t.font.name = "Segoe UI"
    run_t.font.size = Pt(20)
    run_t.font.bold = True
    run_t.font.color.rgb = RGBColor(0x1A, 0x2B, 0x4C)

    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_s = p_sub.add_run("KẾ HOẠCH PHÂN CÔNG NHIỆM VỤ 6 THÀNH VIÊN & CẨM NANG THUYẾT TRÌNH THI ĐẤU\nNASA SPACE APPS CHALLENGE 2026 — THỬ THÁCH #14")
    run_s.font.name = "Segoe UI"
    run_s.font.size = Pt(11)
    run_s.font.bold = True
    run_s.font.color.rgb = RGBColor(0x2B, 0x4C, 0x7E)

    doc.add_paragraph()

    # Introduction Box
    tbl_intro = doc.add_table(rows=1, cols=1)
    tbl_intro.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell_intro = tbl_intro.cell(0, 0)
    set_cell_background(cell_intro, "F1F5F9")
    set_cell_margins(cell_intro, top=140, bottom=140, left=200, right=200)
    p_in = cell_intro.paragraphs[0]
    r_in = p_in.add_run("MỤC ĐÍCH TÀI LIỆU:\nBản phân công này chia đều toàn bộ khối lượng công việc của dự án LẮNG cho 6 thành viên trong nhóm, bảo đảm không ai bị trùng lặp, mỗi người làm chủ hoàn toàn một phân hệ cốt lõi. Tài liệu cung cấp đầy đủ: Mã nguồn sở hữu, Nguyên lý kỹ thuật, Kịch bản thuyết trình Demo (60-90 giây) và Bộ câu hỏi Q&A hóc búa từ Ban giám khảo cùng câu trả lời ghi điểm tối đa.")
    r_in.font.name = "Segoe UI"
    r_in.font.size = Pt(10)
    r_in.font.italic = True

    doc.add_paragraph()

    # Summary Table of 6 Members
    p_tbl_h = doc.add_paragraph()
    r_th = p_tbl_h.add_run("BẢNG TỔNG HỢP VAI TRÒ 6 THÀNH VIÊN")
    r_th.font.name = "Segoe UI"
    r_th.font.size = Pt(13)
    r_th.font.bold = True
    r_th.font.color.rgb = RGBColor(0x1A, 0x2B, 0x4C)

    tbl_summary = doc.add_table(rows=7, cols=4)
    tbl_summary.alignment = WD_TABLE_ALIGNMENT.CENTER
    sum_headers = ["STT", "Thành viên", "Vai trò chính", "Phân hệ phụ trách"]
    for i, h in enumerate(sum_headers):
        c = tbl_summary.cell(0, i)
        set_cell_background(c, "1A2B4C")
        p = c.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run(h)
        r.font.name = "Segoe UI"
        r.font.size = Pt(10)
        r.font.bold = True
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    sum_rows = [
        ("1", "Thành viên 1 (Trưởng nhóm)", "Kiến trúc sư Hệ thống & Trợ năng Chuyên sâu", "Core Trợ năng & Đa nền tảng Flutter"),
        ("2", "Thành viên 2", "Kỹ sư Xử lý Dữ liệu Khoa học NASA & Pipeline", "Data Engineering & NASA Pipeline"),
        ("3", "Thành viên 3", "Phụ trách Phân hệ F1: Khí hậu, Thời tiết & Âm nhạc", "F1 Khí hậu & Âm thanh hóa Nhạc cụ"),
        ("4", "Thành viên 4", "Phụ trách Phân hệ F3: Địa lý & Bản đồ Chạm Xúc giác", "F3 Bản đồ Rê tay Haptic & Địa hình"),
        ("5", "Thành viên 5", "Phụ trách Phân hệ F2: Vũ trụ & Trò chơi Trợ năng", "F2 Khám phá Vũ trụ, NASA Sounds & Game"),
        ("6", "Thành viên 6", "Kỹ sư Trí tuệ Nhân tạo & Xử lý Giọng nói Ngoại tuyến", "AI Gemma 4, Local Earth RAG & Speech"),
    ]

    for r_idx, row_data in enumerate(sum_rows, 1):
        for c_idx, val in enumerate(row_data):
            cell = tbl_summary.cell(r_idx, c_idx)
            set_cell_background(cell, "F8FAFC" if r_idx % 2 == 1 else "FFFFFF")
            set_cell_margins(cell, top=80, bottom=80, left=120, right=120)
            p = cell.paragraphs[0]
            if c_idx in [0, 1]:
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            r = p.add_run(val)
            r.font.name = "Segoe UI"
            r.font.size = Pt(9.5)
            if c_idx == 1:
                r.font.bold = True

    doc.add_page_break()

    # Detailed Section for Each Member
    members_detail = [
        {
            "num": 1,
            "title": "THÀNH VIÊN 1 (TRƯỞNG NHÓM): KIẾN TRÚC SƯ HỆ THỐNG & TRỢ NĂNG CHUYÊN SÂU",
            "role": "System Architecture & Accessibility Lead",
            "modules": "app/lib/main.dart, app_state.dart, ui/theme.dart, core/crash_guard.dart, core/z_gesture.dart, features/blind/, features/help/",
            "what": [
                "Xây dựng kiến trúc ứng dụng đa nền tảng Flutter: Chạy mượt mà đồng bộ trên Web Vercel, Windows Desktop (.exe), Android (.apk) và iOS.",
                "Hiện thực hóa triết lý '100% Giọng nói - Rảnh tay hoàn toàn - Không cần nhìn - Không bao giờ kẹt': Người khiếm thị mở app là nghe lời chào và tự động mở mic lắng nghe, không cần mò mẫm bấm nút.",
                "Chuẩn Trợ năng quốc tế WCAG AAA & Section 508: Thiết kế giao diện tối Sơn Mài tương phản cao (#0A0D14 / #FFD54F); chủ động bật sẵn Semantic Nodes cho các trình đọc màn hình TalkBack, VoiceOver và NVDA.",
                "Cơ chế thoát hiểm khẩn cấp: Lập trình bộ nhận diện cử chỉ Z-gesture (< 1 giây) và các khẩu lệnh phổ quát ('về màn hình chính', 'quay lại', 'dừng lại') hoạt động ở mọi ngữ cảnh, không bao giờ để người dùng bị kẹt.",
                "Hệ sinh thái an toàn CrashGuard: Ghi vết nhật ký lỗi toàn diện; tự động nhận biết lần sập app trước để kích hoạt Safe Mode (chuyển sang giọng đọc/nhạc cụ dự phòng) mà không làm gián đoạn trải nghiệm người dùng."
            ],
            "how": "Quản lý luồng trạng thái tập trung qua AppScope (InheritedNotifier); lắng nghe sự kiện vòng đời hệ điều hành bằng AppLifecycleListener để giải phóng tài nguyên âm thanh; bắt trọn mọi ngoại lệ bằng CrashGuard và điều phối điều hướng rảnh tay.",
            "tech": "Flutter 3, Dart 3, WCAG AAA Accessibility Engine, Z-Gesture Recognizer, CrashGuard Safe Mode.",
            "pitch": "Kính thưa Ban giám khảo, Lắng được sinh ra để xóa bỏ hoàn toàn rào cản thông tin khoa học NASA cho 1,2 triệu người khiếm thị Việt Nam. Em đảm nhiệm kiến trúc tổng thể và trợ năng cốt lõi. Khác với các ứng dụng thông thường, Lắng mang triết lý 100% giọng nói rảnh tay: người khiếm thị không cần nhìn màn hình, không cần bấm bất kỳ nút nào, và tuyệt đối không bao giờ bị kẹt nhờ cử chỉ Z-gesture phổ quát và cơ chế tự phục hồi CrashGuard Safe Mode.",
            "qa": [
                ("Làm thế nào để người khiếm thị không bị lạc hay bối rối khi sử dụng ứng dụng?",
                 "Ứng dụng duy trì cơ chế phản hồi âm thanh kép: tiếng 'ding' báo nhận lệnh, tiếng nhạc cụ diễn tấu số liệu và giọng đọc Piper thuyết minh ngắn gọn. Đặc biệt, người dùng có thể nói 'về màn hình chính' hoặc vẽ chữ Z bất kỳ lúc nào để quay về toàn cảnh."),
                ("Khi ứng dụng bị lỗi driver âm thanh hoặc giọng đọc hệ thống bị crash thì xử lý ra sao?",
                 "Hệ thống CrashGuard của em tự động ghi vết nguyên nhân sập. Khi mở lại, app tự bật Chế độ An toàn (Safe Mode), chuyển sang giọng đọc dự phòng hoặc tắt tạm nhạc cụ lỗi, đồng thời đọc to giải thích nguyên nhân bằng giọng nói cho người dùng an tâm.")
            ]
        },
        {
            "num": 2,
            "title": "THÀNH VIÊN 2: KỸ SƯ XỬ LÝ DỮ LIỆU KHOA HỌC NASA & PIPELINE TỰ ĐỘNG",
            "role": "Data Engineering & NASA Pipeline Lead",
            "modules": "pipeline/config.py, build.py, update.py, validate.py, app/assets/data/credits.csv, docs/DATA_SOURCES.md, tests/",
            "what": [
                "Xây dựng toàn bộ Pipeline Python tự động hóa: Tải dữ liệu, trích xuất lưới không gian, chuẩn hóa thang đo và lượng tử hóa uint8.",
                "Chuẩn hóa 6 bộ dữ liệu NASA đóng gói cốt lõi: NASA POWER (MERRA-2 1981-2025), NASA GISS GISTEMP v4 (1880-2025), NASA FIRMS MODIS C6.1, NASA SEDAC GDIS (282 thiên tai VN), SRTM 30m, Planetary Fact Sheet.",
                "Cắt lưới không gian độ phân giải 0.1° bao phủ 2.849 ô đất liền Việt Nam qua 300 tháng lịch sử (2001–2025). Nén dữ liệu từ hàng Gigabyte xuống còn đúng 280KB.",
                "Thiết kế khối siêu dữ liệu khoa học data_card (12 trường thông tin) và bảng ghi công liêm chính credits.csv (6 cột tiêu chuẩn).",
                "Thiết lập quy trình kiểm định chất lượng tự động 7 cổng (7-Point Quality Gate) với sai số toán học cực nhỏ: nhiệt độ sai số lớn nhất 0.058°C, lượng mưa lớn nhất 1.485 mm."
            ],
            "how": "Sử dụng thư viện Python chuyên dụng xarray và netCDF4 để phân tích các tập dữ liệu khí tượng toàn cầu; áp dụng giải thuật nén lượng tử tuyến tính (Linear Quantization) sang mảng nhị phân uint8 kết hợp đối chiếu sai số tự động bằng validate.py.",
            "tech": "Python 3.11+, xarray, netCDF4, numpy, pytest, NASA Open APIs (POWER, FIRMS, GISTEMP, SEDAC).",
            "pitch": "Em phụ trách trái tim khoa học của Lắng: Pipeline dữ liệu NASA. Thách thức lớn nhất của đề tài #14 là làm sao đưa khối dữ liệu vệ tinh khổng lồ vào một ứng dụng chạy offline siêu nhẹ. Em đã xây dựng pipeline lượng tử hóa uint8 cho 300 tháng dữ liệu khí hậu, nén toàn bộ lãnh thổ Việt Nam chỉ còn 280KB, vượt qua 7 cổng kiểm định chất lượng với sai số nhiệt độ dưới 0.058°C, bảo đảm tính Liêm chính Khoa học tuyệt đối.",
            "qa": [
                ("Việc lượng tử hóa uint8 để giảm dung lượng có làm mất đi độ chính xác của dữ liệu NASA không?",
                 "Em đã viết riêng bộ kiểm thử validate.py đối chiếu từng ô lưới với dữ liệu gốc MERRA-2. Kết quả kiểm định cho thấy sai số nhiệt độ lớn nhất chỉ 0.058°C và sai số mưa dưới 1.48 mm/tháng, hoàn toàn nằm trong ngưỡng cho phép của Tổ chức Khí tượng Thế giới."),
                ("Nếu sau cuộc thi NASA cập nhật dữ liệu mới thì pipeline có tự động cập nhật được không?",
                 "Dự án được tự động hóa hoàn toàn. Chỉ cần chạy một lệnh 'python -m pipeline.update', mã nguồn sẽ tự tải dữ liệu mới từ API NASA, chuẩn hóa, chạy kiểm định và đồng bộ ngay sang ứng dụng mà không cần sửa code bằng tay.")
            ]
        },
        {
            "num": 3,
            "title": "THÀNH VIÊN 3: PHỤ TRÁCH PHÂN HỆ F1 — THỜI TIẾT, KHÍ HẬU & ÂM THANH DÂN TỘC",
            "role": "F1 Climate & Sonification Lead",
            "modules": "app/lib/audio/synth.dart, audio_engine.dart, features/history/, live/nasa_power.dart, live/hazard_history.dart, features/timeline/",
            "what": [
                "Sáng tạo và hiện thực hóa giải thuật Âm thanh hóa số liệu bằng Nhạc cụ Dân tộc Việt Nam (Cultural Data Sonification):",
                "  • Đàn Bầu (mô hình vật lý Karplus-Strong): Uốn lượn cao độ theo nhiệt độ không khí T2M và chuỗi 146 năm ấm lên toàn cầu GISTEMP.",
                "  • Đàn T'rưng: Gõ nhịp ống tre theo cường độ lượng mưa PRECTOTCORR; mưa lớn dồn dập có sấm vang rền.",
                "  • Tiếng Lửa khô nổ lách tách & Nhịp Trống đồng: Cảnh báo điểm nóng cháy rừng theo mùa NASA FIRMS và thời tiết cực đoan.",
                "Xây dựng tính năng 'Phát lại Lịch sử Thời tiết & Thiên tai': Thanh timeline trực quan, âm thanh chuyển biến hài hòa theo năm/tháng, chạm màn hình để nghe giải thích số liệu.",
                "Tái hiện 15 ngày chuỗi thiên tai lịch sử: Siêu bão Yagi (09/2024 tại miền Bắc) và Mưa lũ miền Trung (10/2020 tại Huế) với giải thích rõ ràng về độ phân giải ô lưới 50km.",
                "Thống kê chuỗi ngày nắng nóng cực đoan 3 ngưỡng KTTV Việt Nam (≥35°C, ≥37°C, ≥39°C) so sánh 1981–1990 với 2016–2025."
            ],
            "how": "Triển khai bộ tổng hợp âm thanh C++ SoLoud nhúng trong Flutter; mô phỏng dao động dây đàn bằng thuật toán Karplus-Strong; ánh xạ hàm số toán học giữa giá trị khí tượng và tần số nốt nhạc theo thang âm ngũ cung Việt Nam.",
            "tech": "Flutter SoLoud C++ Audio Engine, Karplus-Strong String Synthesis, NASA POWER & GISTEMP Datasets.",
            "pitch": "Em phụ trách chuyển hóa các biểu đồ khí hậu khô khan của NASA thành những giai điệu biết nói qua nhạc cụ truyền thống Việt Nam. Nhiệt độ nóng lên toàn cầu được uốn lượn tinh tế qua dây Đàn Bầu, lượng mưa bão Yagi dồn dập qua tiếng Đàn T'rưng Tây Nguyên, và cháy rừng qua tiếng lửa khô nổ lách tách. Người khiếm thị có thể nhắm mắt lại và cảm nhận sâu sắc biến đổi khí hậu bằng chính trái tim và đôi tai của mình.",
            "qa": [
                ("Tại sao lại dùng nhạc cụ dân tộc Việt Nam thay vì âm thanh điện tử hiện đại?",
                 "Âm thanh nhạc cụ truyền thống có tính biểu cảm tự nhiên cao, cấu trúc âm ngũ cung tạo cảm giác gần gũi, ấm áp và không gây mỏi tai khi nghe lâu. Đặc biệt, đặc tính uốn cao độ liên tục của Đàn Bầu là nhạc cụ duy nhất mô phỏng hoàn hảo đường cong nhiệt độ liên tục của tự nhiên."),
                ("Người khiếm thị làm sao biết lúc nào là bão, lúc nào là mưa thường?",
                 "Bọn em phân tầng âm thanh rất rõ: mưa nhỏ là tiếng đàn t'rưng thưa, mưa to nhịp gõ dày dặc kèm tiếng gió ào; khi có bão hoặc thiên tai cấp 3 trở lên, âm thanh sấm sét kết hợp với mô-tơ rung điện thoại giúp người dùng cảm nhận được sự dữ dội của thiên tai.")
            ]
        },
        {
            "num": 4,
            "title": "THÀNH VIÊN 4: PHỤ TRÁCH PHÂN HỆ F3 — ĐỊA LÝ & BẢN ĐỒ CHẠM XÚC GIÁC HAPTIC",
            "role": "F3 Geospatial & Haptic Sense Lead",
            "modules": "app/lib/features/globe/local_map.dart, live/terrain_tiles.dart, live/terrain_patch.dart, features/terrain_scan/, core/haptics.dart",
            "what": [
                "Phát triển tính năng đột phá 'Rê tay khám phá' (Haptic Terrain Sense): Cho phép người khiếm thị lướt ngón tay trên màn hình để cảm nhận địa hình thật 2.4 × 2.4 km có bóng đổ chân thực.",
                "Cơ chế âm thanh đa giác quan thời gian thực:",
                "  • Tiếng Sáo Trúc: Vút cao ở đỉnh núi, trầm ấm ở thung lũng (dữ liệu NASA SRTM 30m).",
                "  • Rung phản hồi Haptic: Máy rung nhẹ ở dốc thoai thoải, rung dồn dập dữ dội ở vách đá dựng đứng.",
                "  • Bề mặt tự nhiên: Sóng nước ở sông/hồ, lá xào xạc ở rừng cây, tiếng còi xe ở khu dân cư.",
                "Sáng tạo tính năng 'Quét mặt cắt địa hình 8 km': Lát cắt quét Bắc-Nam rồi Tây-Đông (< 8 giây), tiếng sáo ngân vang theo độ cao trung bình của mặt cắt.",
                "Tích hợp cẩm nang địa danh du lịch, di tích lịch sử xã/phường (Hà Nội và OpenStreetMap).",
                "Thuyết minh chủ quyền biển đảo thiêng liêng: Ngân vang tiếng chuông chùa và lời khẳng định chủ quyền tại quần đảo Hoàng Sa và Trường Sa."
            ],
            "how": "Tải các ô độ cao Terrarium nén (AWS/SRTM) kết hợp mặt nạ lớp phủ đất MODIS MCD12Q1 (IGBP); bắt sự kiện cảm ứng PanUpdate để tính toán toạ độ thực, nội suy độ dốc và điều khiển rung mô-tơ Haptic cùng bộ trộn âm thanh 3D.",
            "tech": "NASA SRTM GL1 30m, MODIS IGBP Land Cover, OpenStreetMap Overpass, Device Haptic Feedback API.",
            "pitch": "Em phụ trách biến màn hình cảm ứng phẳng lì thành một bản đồ xúc giác sống động. Với tính năng 'Rê tay khám phá', người khiếm thị di ngón tay đến đâu sẽ nghe tiếng sáo trúc vút cao theo đỉnh núi, điện thoại rung bần bật khi gặp vách dốc nguy hiểm, nghe tiếng sóng vỗ khi chạm vào sông hồ, và tiếng chuông ngân thiêng liêng khi chạm tới quần đảo Hoàng Sa và Trường Sa. Lần đầu tiên, người khiếm thị có thể 'sờ' thấy hình hài non sông đất nước.",
            "qa": [
                ("Màn hình điện thoại hoàn toàn phẳng, làm sao người khiếm thị định vị được ngón tay?",
                 "Ngay khi ngón tay lướt qua một vùng mới, giọng đọc sẽ thông báo ngay tên địa danh, độ cao mét và độ dốc; đồng thời rung Haptic thay đổi cường độ theo độ dốc dưới đầu ngón tay tạo cảm giác gờ nổi xúc giác như đang sờ vào sa bàn thật."),
                ("Việc tải dữ liệu địa hình và phát âm thanh liên tục có gây lag giật trên máy cấu hình yếu không?",
                 "Bọn em đã giải mã trước ô độ cao vào RAM và thực hiện nội suy toạ độ bilinear cực nhanh dưới 16 mili-giây, bảo đảm tốc độ 60 khung hình/giây mượt mà và hoạt động tốt ngay cả trên máy tính bảng hoặc điện thoại phổ thông.")
            ]
        },
        {
            "num": 5,
            "title": "THÀNH VIÊN 5: PHỤ TRÁCH PHÂN HỆ F2 — KHÁM PHÁ VŨ TRỤ & TRÒ CHƠI TRỢ NĂNG",
            "role": "F2 Space Exploration & Gamification Lead",
            "modules": "app/lib/features/space/planets.dart, planet_facts.dart, planet_games.dart, live/apod.dart, live/nasa_sounds.dart, assets/data/planets_nasa.json",
            "what": [
                "Xây dựng không gian 3D tương tác Hệ Mặt Trời: Quỹ đạo 8 hành tinh quay quanh Mặt Trời kèm âm thanh tần số không gian đặc trưng cho từng thiên thể.",
                "Chuẩn hóa thông số hệ mét 10 thiên thể (Mặt Trời, 8 hành tinh, Mặt Trăng) từ NASA NSSDCA, cập nhật số lượng mặt trăng chuẩn mốc năm 2026.",
                "Biên soạn kho 135 sự thật thú vị (fun_facts) từ NASA Space Place và bộ 35 câu Hỏi - Đáp kiểm chứng khoa học, đính chính 12 hiểu lầm phổ biến.",
                "Tích hợp 10 bản ghi âm lịch sử thật của NASA (Apollo 11, Apollo 13, Sputnik 1, sóng vô tuyến Sao Thổ, gió Sao Hỏa Perseverance...).",
                "Chuẩn hóa mô tả ảnh thiên văn vũ trụ sâu theo Chuẩn Mục 508 (Section 508) và tích hợp API NASA APOD (Ảnh thiên văn mỗi ngày) dịch nghĩa tiếng Việt tự động.",
                "Thiết kế bộ 4 minigame trợ năng tương tác giọng nói 100%: Đố vui vũ trụ, 'Tôi là ai', Đoán hành tinh bằng âm thanh, Đố âm thanh NASA."
            ],
            "how": "Tổ chức dữ liệu JSON phân loại minh bạch 3 nhãn audio_kind (recording, nasa_sonification, app_sonification); xây dựng máy trạng thái hữu hạn (State Machine) quản lý phiên chơi game, xử lý nhận diện giọng nói và lưu điểm kỷ lục offline.",
            "tech": "NASA NSSDCA Planetary Fact Sheet, NASA Space Place, NASA Historical Sounds API, Section 508 Standard.",
            "pitch": "Em phụ trách mở cánh cửa vũ trụ cho cộng đồng khiếm thị qua phân hệ F2. Bọn em không chỉ đưa thông số chuẩn xác của NASA tính đến năm 2026 mà còn mang đến 10 bản ghi âm lịch sử thật như giọng nói của phi hành gia Apollo 11 hay tiếng gió trên Sao Hỏa. Đặc biệt, bộ 4 minigame tương tác hoàn toàn bằng giọng nói giúp các em nhỏ khiếm thị vừa chơi vừa tiếp thu kiến thức thiên văn, biến khoa học không gian thành niềm đam mê không rào cản.",
            "qa": [
                ("Mô tả hình ảnh thiên văn cho người khiếm thị tuân thủ theo tiêu chuẩn quốc tế nào?",
                 "Bọn em áp dụng nghiêm ngặt Chuẩn Mục 508 (Section 508) của NASA: câu ngắn dưới 20 từ, so sánh với các vật thể quen thuộc đời thường, miêu tả bằng cảm giác âm thanh và phân định rõ ràng giữa âm thanh thu thật và âm thanh mô phỏng số liệu."),
                ("Các câu hỏi đố vui trong trò chơi lấy từ nguồn nào để bảo đảm tính chuẩn xác?",
                 "Toàn bộ câu hỏi và đáp án được trích xuất trực tiếp từ kho NASA Space Place và NSSDCA; hệ thống có 12 câu hỏi chuyên đính chính các hiểu lầm khoa học phổ biến như thuyết Trái Đất phẳng hay nguyên nhân sinh ra các mùa.")
            ]
        },
        {
            "num": 6,
            "title": "THÀNH VIÊN 6: KỸ SƯ TRÍ TUỆ NHÂN TẠO & XỬ LÝ GIỌNG NÓI NGOẠI TUYẾN",
            "role": "AI Engineer & Offline Speech Processing Lead",
            "modules": "app/lib/speech/piper_voice.dart, speech/voice_listener.dart, live/gemini_assistant.dart, live/earth_rag.dart, features/globe/world_commands.dart",
            "what": [
                "Tích hợp hệ sinh thái giọng nói ngoại tuyến hoàn chỉnh (Offline Speech Engine):",
                "  • Nhận diện giọng nói tiếng Việt bằng Sherpa-ONNX Zipformer kết hợp Silero VAD (nhận diện rảnh tay, tự ngắt khi dứt câu).",
                "  • Giọng đọc Neural TTS tiếng Việt offline chất lượng cao Piper (vi_VN-vais1000).",
                "Lập trình bộ xử lý ngôn ngữ tự nhiên (NLP) thông minh: Khử dội âm loa ngoài (barge-in protection), lọc sạch từ đệm ('ừ, à, hả'), nhận diện câu sửa đổi ('không phải Huế mà là Đà Nẵng'), câu hỏi ngữ cảnh nối tiếp ('thế còn ngày mai?').",
                "Tích hợp Trợ lý AI Google Gemma 4 26B (gemma-4-26b-a4b-it) kết hợp mô hình Local Earth RAG: Neo dữ liệu NASA thật vào prompt để triệt tiêu 100% hiện tượng bịa đặt số liệu (hallucination).",
                "Xây dựng tầng bảo mật Vercel Serverless Function (/api/gemini) và cơ chế chuyển đổi dự phòng mô hình Flash-Lite khi mất mạng hoặc quá tải."
            ],
            "how": "Luồng xử lý âm thanh: Mic input -> VAD phát hiện giọng nói -> Sherpa-ONNX chuyển văn bản -> Chuẩn hóa phương ngữ -> Phân loại ý định -> Nếu hỏi số liệu khoa học: trích xuất RAG từ JSON đưa vào ngữ cảnh Gemma 4; nếu là lệnh điều khiển: gọi WorldCommands thực thi tức thì.",
            "tech": "Sherpa-ONNX Zipformer, Silero VAD, Piper Neural TTS, Google Gemma 4 26B MoE, Local Earth RAG Architecture.",
            "pitch": "Em phụ trách bộ não AI và giọng nói của Lắng. Điểm đột phá nhất là hệ thống có thể lắng nghe và trò chuyện mượt mà ngay cả khi hoàn toàn mất mạng nhờ bộ đôi Sherpa-ONNX và Piper TTS. Khi có mạng, Trợ lý AI Gemma 4 được trang bị cơ chế Local Earth RAG: AI bị ràng buộc tuyệt đối phải trích dẫn số liệu thật từ 6 kho dữ liệu NASA đóng gói kèm theo, ngăn chặn hoàn toàn nguy cơ ảo giác bịa số, bảo đảm độ chính xác khoa học tuyệt đối.",
            "qa": [
                ("Làm sao bạn chứng minh được mô hình AI không tự bịa đặt số liệu khí hậu (hallucination)?",
                 "Hệ thống của em hoạt động theo nguyên tắc RAG cục bộ: AI không được tự do sinh số liệu. Trước khi gửi câu hỏi đến Gemma 4, hệ thống tự động lọc số liệu chuẩn từ các file JSON NASA và đưa vào prompt; nếu trong dữ liệu không có, AI được lập trình để trả lời trung thực là chưa có dữ liệu."),
                ("Khi loa ngoài của máy tính/điện thoại đang phát nhạc to, làm sao mic nghe được lệnh ngắt 'dừng lại' của người dùng?",
                 "Bọn em đã lập trình bộ lọc dội âm (Acoustic Echo Cancellation) kết hợp Silero VAD phân tích năng lượng giọng người nói; câu nói phát ra từ loa sẽ bị hệ thống nhận dạng và loại trừ, giúp người dùng ngắt lời app bất cứ lúc nào.")
            ]
        }
    ]

    for m in members_detail:
        # Title of member
        p_m = doc.add_paragraph()
        p_m.paragraph_format.space_before = Pt(14)
        p_m.paragraph_format.space_after = Pt(4)
        r_mt = p_m.add_run(m["title"])
        r_mt.font.name = "Segoe UI"
        r_mt.font.size = Pt(12)
        r_mt.font.bold = True
        r_mt.font.color.rgb = RGBColor(0x1A, 0x2B, 0x4C)

        # Info Box Table
        tbl_m = doc.add_table(rows=6, cols=2)
        tbl_m.alignment = WD_TABLE_ALIGNMENT.CENTER
        
        info_rows = [
            ("Vai trò thi đấu tiếng Anh:", m["role"]),
            ("Mã nguồn & Module sở hữu:", m["modules"]),
            ("Nguyên lý hoạt động cốt lõi:", m["how"]),
            ("Công nghệ & Dữ liệu sử dụng:", m["tech"]),
            ("Kịch bản thuyết trình Demo (60-90s):", m["pitch"]),
        ]

        for idx, (label, val) in enumerate(info_rows):
            c_lbl = tbl_m.cell(idx, 0)
            c_val = tbl_m.cell(idx, 1)
            set_cell_background(c_lbl, "F1F5F9")
            set_cell_margins(c_lbl, top=60, bottom=60, left=100, right=100)
            set_cell_margins(c_val, top=60, bottom=60, left=100, right=100)
            
            p_l = c_lbl.paragraphs[0]
            r_l = p_l.add_run(label)
            r_l.font.name = "Segoe UI"
            r_l.font.size = Pt(9)
            r_l.font.bold = True
            
            p_v = c_val.paragraphs[0]
            r_v = p_v.add_run(val)
            r_v.font.name = "Segoe UI"
            r_v.font.size = Pt(9)
            if idx == 4:
                r_v.font.italic = True
                r_v.font.bold = True

        # What was done in row 5
        c_wlbl = tbl_m.cell(5, 0)
        c_wval = tbl_m.cell(5, 1)
        set_cell_background(c_wlbl, "F1F5F9")
        set_cell_margins(c_wlbl, top=60, bottom=60, left=100, right=100)
        set_cell_margins(c_wval, top=60, bottom=60, left=100, right=100)
        
        p_wl = c_wlbl.paragraphs[0]
        r_wl = p_wl.add_run("Các hạng mục công việc cụ thể:")
        r_wl.font.name = "Segoe UI"
        r_wl.font.size = Pt(9)
        r_wl.font.bold = True
        
        p_wv = c_wval.paragraphs[0]
        for w_item in m["what"]:
            p_item = c_wval.add_paragraph()
            p_item.paragraph_format.space_before = Pt(1)
            p_item.paragraph_format.space_after = Pt(1)
            r_wi = p_item.add_run(f"• {w_item}")
            r_wi.font.name = "Segoe UI"
            r_wi.font.size = Pt(8.5)

        # Set widths for columns
        for row in tbl_m.rows:
            row.cells[0].width = Inches(2.2)
            row.cells[1].width = Inches(4.8)

        # Q&A Box
        p_qa_h = doc.add_paragraph()
        p_qa_h.paragraph_format.space_before = Pt(6)
        p_qa_h.paragraph_format.space_after = Pt(2)
        r_qah = p_qa_h.add_run("CÂU HỎI BAN GIÁM KHẢO HAY HỎI (Q&A) & GỢI Ý TRẢ LỜI:")
        r_qah.font.name = "Segoe UI"
        r_qah.font.size = Pt(9.5)
        r_qah.font.bold = True
        r_qah.font.color.rgb = RGBColor(0x2B, 0x4C, 0x7E)

        for q_text, a_text in m["qa"]:
            p_q = doc.add_paragraph()
            p_q.paragraph_format.space_before = Pt(2)
            p_q.paragraph_format.space_after = Pt(1)
            r_q = p_q.add_run(f"❓ Hỏi: {q_text}")
            r_q.font.name = "Segoe UI"
            r_q.font.size = Pt(9)
            r_q.font.bold = True
            
            p_a = doc.add_paragraph()
            p_a.paragraph_format.space_before = Pt(1)
            p_a.paragraph_format.space_after = Pt(4)
            r_a = p_a.add_run(f"💡 Đáp: {a_text}")
            r_a.font.name = "Segoe UI"
            r_a.font.size = Pt(9)

        doc.add_paragraph()

    # Save Word doc
    docx_path = r"d:\user\Desktop\Github\sense\docs\PHAN_CONG_NHIEM_VU_6_THANH_VIEN.docx"
    doc.save(docx_path)
    print(f"Word document generated successfully at: {docx_path}")

    # -------------------------------------------------------------
    # GENERATE MARKDOWN DOCUMENT (.md)
    # -------------------------------------------------------------
    md_content = """# LẮNG · KẾ HOẠCH PHÂN CÔNG NHIỆM VỤ 6 THÀNH VIÊN & CẨM NANG THI ĐẤU
> **NASA Space Apps Challenge 2026** — Thử thách **#14: *The Earth Information Jukebox***  
> **Dự án:** Lắng — Quả Địa Cầu Biết Nói & Âm Thanh Hóa Dữ Liệu Khoa Học NASA  
> **Đội ngũ:** 6 Thành viên · Phân công nhiệm vụ độc lập, chuyên sâu và sẵn sàng bảo vệ trước Ban Giám Khảo.

---

## 1. BẢNG TỔNG QUAN PHÂN CÔNG 6 THÀNH VIÊN

| STT | Thành viên | Vai trò thi đấu | Phân hệ phụ trách | Sản phẩm chính & Trách nhiệm lõi |
|:---:|---|---|---|---|
| **1** | **Thành viên 1** *(Trưởng nhóm)* | **Kiến trúc sư Hệ thống & Trợ năng Chuyên sâu** *(System Architecture & Accessibility Lead)* | Core Trợ năng & Đa nền tảng Flutter | Kiến trúc đa nền tảng (Web/Windows/Mobile), triết lý 100% giọng nói rảnh tay, chuẩn WCAG AAA, cử chỉ Z-gesture thoát hiểm, hệ thống CrashGuard Safe Mode. |
| **2** | **Thành viên 2** | **Kỹ sư Xử lý Dữ liệu Khoa học NASA & Pipeline** *(Data Engineering & NASA Pipeline Lead)* | Data Engineering & NASA Pipeline | Pipeline Python tự động hóa, cắt lưới 0.1° (2.849 ô VN), lượng tử hóa uint8 (300 tháng), chuẩn hóa 6 bộ JSON NASA, 7 cổng kiểm định chất lượng, sai số < 0.058°C. |
| **3** | **Thành viên 3** | **Phụ trách Phân hệ F1: Thời tiết, Khí hậu & Âm thanh Dân tộc** *(F1 Climate & Sonification Lead)* | F1 Khí hậu & Âm thanh hóa Nhạc cụ | Giải thuật âm thanh hóa: Đàn Bầu uốn nhiệt độ T2M & 146 năm GISTEMP, Đàn T'rưng gõ nhịp mưa, lửa khô FIRMS, phát lại lịch sử thời tiết & tái hiện bão Yagi / lũ miền Trung. |
| **4** | **Thành viên 4** | **Phụ trách Phân hệ F3: Địa lý & Bản đồ Chạm Xúc giác Haptic** *(F3 Geospatial & Haptic Sense Lead)* | F3 Bản đồ Rê tay Haptic & Địa hình | Tính năng "Rê tay khám phá" bản đồ 2.4×2.4km, tiếng sáo theo độ cao SRTM 30m, rung Haptic theo độ dốc, âm thanh sóng/rừng/xe cộ, quét mặt cắt 8km, khẳng định chủ quyền Hoàng Sa - Trường Sa. |
| **5** | **Thành viên 5** | **Phụ trách Phân hệ F2: Khám phá Vũ trụ & Trò chơi Trợ năng** *(F2 Space & Gamification Lead)* | F2 Khám phá Vũ trụ, NASA Sounds & Game | Mô hình 3D Hệ Mặt Trời, thông số 10 thiên thể chuẩn NASA 2026, kho 135 sự thật thú vị, 35 hỏi-đáp kiểm chứng, 10 bản ghi âm thật NASA, mô tả ảnh Mục 508, bộ 4 minigame giọng nói. |
| **6** | **Thành viên 6** | **Kỹ sư Trí tuệ Nhân tạo & Xử lý Giọng nói Ngoại tuyến** *(AI Engineer & Speech Processing Lead)* | AI Gemma 4, Local Earth RAG & Speech | Trọn bộ giọng nói offline Sherpa-ONNX + Piper TTS, bộ lọc dội âm loa ngoài & tiếng ậm ừ, Trợ lý AI Google Gemma 4 MoE kết hợp Local Earth RAG chống ảo giác số liệu 100%. |

---

## 2. NỘI DUNG CHI TIẾT THEO TỪNG THÀNH VIÊN

### THÀNH VIÊN 1 (TRƯỞNG NHÓM): KIẾN TRÚC SƯ HỆ THỐNG & TRỢ NĂNG CHUYÊN SÂU
- **Vai trò thi đấu:** System Architecture & Accessibility Lead
- **Mã nguồn sở hữu:** `app/lib/main.dart`, `app_state.dart`, `ui/theme.dart`, `core/crash_guard.dart`, `core/z_gesture.dart`, `features/blind/`, `features/help/`
- **Hạng mục đã xây dựng:**
  1. Kiến trúc ứng dụng đa nền tảng Flutter (chạy đồng bộ Web Vercel, Windows Desktop, Android, iOS).
  2. Triết lý thiết kế *"100% Giọng nói - Rảnh tay hoàn toàn - Không cần nhìn - Không bao giờ bị kẹt"*.
  3. Chuẩn Trợ năng quốc tế WCAG AAA & Mục 508: Giao diện Sơn Mài tương phản cao (`#0A0D14` / `#FFD54F`), Semantic Tree tự động kích hoạt cho TalkBack, VoiceOver và NVDA.
  4. Cơ chế thoát hiểm khẩn cấp: Cử chỉ vẽ chữ Z (< 1 giây) và khẩu lệnh phổ quát (*"về màn hình chính"*, *"quay lại"*, *"dừng lại"*) hoạt động tại mọi màn hình.
  5. Hệ sinh thái CrashGuard: Tự động ghi log lỗi, phát hiện lỗi driver âm thanh/TTS và chuyển sang chế độ an toàn (Safe Mode) giải thích cho người dùng bằng lời nói.
- **Kịch bản Pitching (60-90s):**
  > *"Kính thưa Ban giám khảo, Lắng được sinh ra để xóa bỏ hoàn toàn rào cản thông tin khoa học NASA cho 1,2 triệu người khiếm thị Việt Nam. Em đảm nhiệm kiến trúc tổng thể và trợ năng cốt lõi. Khác với các ứng dụng thông thường, Lắng mang triết lý 100% giọng nói rảnh tay: người khiếm thị không cần nhìn màn hình, không cần bấm bất kỳ nút nào, và tuyệt đối không bao giờ bị kẹt nhờ cử chỉ Z-gesture phổ quát và cơ chế tự phục hồi CrashGuard Safe Mode."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Làm thế nào để người khiếm thị không bị lạc hay bối rối khi sử dụng ứng dụng?*  
    *💡 Đáp: Ứng dụng duy trì cơ chế phản hồi âm thanh kép: tiếng 'ding' báo nhận lệnh, tiếng nhạc cụ diễn tấu số liệu và giọng đọc Piper thuyết minh ngắn gọn. Đặc biệt, người dùng có thể nói 'về màn hình chính' hoặc vẽ chữ Z bất kỳ lúc nào để quay về toàn cảnh.*
  - *❓ Hỏi: Khi ứng dụng bị lỗi driver âm thanh hoặc giọng đọc hệ thống bị crash thì xử lý ra sao?*  
    *💡 Đáp: Hệ thống CrashGuard của em tự động ghi vết nguyên nhân sập. Khi mở lại, app tự bật Chế độ An toàn (Safe Mode), chuyển sang giọng đọc dự phòng hoặc tắt tạm nhạc cụ lỗi, đồng thời đọc to giải thích nguyên nhân bằng giọng nói cho người dùng an tâm.*

---

### THÀNH VIÊN 2: KỸ SƯ XỬ LÝ DỮ LIỆU KHOA HỌC NASA & PIPELINE TỰ ĐỘNG
- **Vai trò thi đấu:** Data Engineering & NASA Pipeline Lead
- **Mã nguồn sở hữu:** `pipeline/config.py`, `pipeline/build.py`, `pipeline/update.py`, `pipeline/validate.py`, `app/assets/data/credits.csv`, `docs/DATA_SOURCES.md`, `tests/`
- **Hạng mục đã xây dựng:**
  1. Toàn bộ Pipeline Python tự động hóa: Tải từ API/Archive, giải nén NetCDF/HDF5, cắt lưới không gian và lượng tử hóa `uint8`.
  2. Chuẩn hóa 6 bộ dữ liệu NASA đóng gói: GISTEMP v4 (146 năm), POWER (45 năm nhiệt/mưa 29 điểm), FIRMS MODIS C6.1, SEDAC GDIS (282 thiên tai VN), SRTM 30m, Planetary Fact Sheet.
  3. Cắt lưới 0.1° (100 × 153 ô, 2.849 ô đất liền Việt Nam) qua 300 tháng lịch sử (2001–2025). Nén dữ liệu từ hàng GB xuống còn 280KB.
  4. Khối siêu dữ liệu chuẩn `data_card` (12 trường) và bảng ghi công liêm chính `credits.csv` (6 cột).
  5. Quy trình kiểm định chất lượng tự động 7 cổng (7-Point Quality Gate) với sai số toán học cực nhỏ: nhiệt độ sai số max 0.058°C, mưa max 1.485 mm.
- **Kịch bản Pitching (60-90s):**
  > *"Em phụ trách trái tim khoa học của Lắng: Pipeline dữ liệu NASA. Thách thức lớn nhất của đề tài #14 là làm sao đưa khối dữ liệu vệ tinh khổng lồ vào một ứng dụng chạy offline siêu nhẹ. Em đã xây dựng pipeline lượng tử hóa uint8 cho 300 tháng dữ liệu khí hậu, nén toàn bộ lãnh thổ Việt Nam chỉ còn 280KB, vượt qua 7 cổng kiểm định chất lượng với sai số nhiệt độ dưới 0.058°C, bảo đảm tính Liêm chính Khoa học tuyệt đối."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Việc lượng tử hóa uint8 để giảm dung lượng có làm mất đi độ chính xác của dữ liệu NASA không?*  
    *💡 Đáp: Em đã viết riêng bộ kiểm thử validate.py đối chiếu từng ô lưới với dữ liệu gốc MERRA-2. Kết quả kiểm định cho thấy sai số nhiệt độ lớn nhất chỉ 0.058°C và sai số mưa dưới 1.48 mm/tháng, hoàn toàn nằm trong ngưỡng cho phép của Tổ chức Khí tượng Thế giới.*
  - *❓ Hỏi: Nếu sau cuộc thi NASA cập nhật dữ liệu mới thì pipeline có tự động cập nhật được không?*  
    *💡 Đáp: Dự án được tự động hóa hoàn toàn. Chỉ cần chạy một lệnh 'python -m pipeline.update', mã nguồn sẽ tự tải dữ liệu mới từ API NASA, chuẩn hóa, chạy kiểm định và đồng bộ ngay sang ứng dụng mà không cần sửa code bằng tay.*

---

### THÀNH VIÊN 3: PHỤ TRÁCH PHÂN HỆ F1 — THỜI TIẾT, KHÍ HẬU & ÂM THANH DÂN TỘC
- **Vai trò thi đấu:** F1 Climate & Sonification Lead
- **Mã nguồn sở hữu:** `app/lib/audio/synth.dart`, `audio_engine.dart`, `features/history/`, `live/nasa_power.dart`, `live/hazard_history.dart`, `features/timeline/`
- **Hạng mục đã xây dựng:**
  1. Giải thuật Âm thanh hóa số liệu bằng Nhạc cụ Dân tộc Việt Nam (Cultural Data Sonification):
     - **Đàn Bầu** *(mô hình Karplus-Strong)*: Uốn cao độ theo nhiệt độ `T2M` và chuỗi 146 năm ấm lên toàn cầu GISTEMP.
     - **Đàn T'rưng**: Gõ nhịp ống tre theo lượng mưa `PRECTOTCORR`, mưa lớn dồn dập có sấm chớp vang rền.
     - **Tiếng Lửa khô & Trống đồng**: Mô phỏng cháy rừng theo mùa NASA FIRMS và cảnh báo thời tiết cực đoan.
  2. Tính năng "Phát lại Lịch sử Thời tiết & Thiên tai": Timeline trực quan, âm thanh biến thiên mượt mà, chạm màn hình giải thích bản ghi chi tiết.
  3. Tái hiện 15 ngày 2 sự kiện lịch sử: Siêu bão Yagi (09/2024 tại miền Bắc) và Mưa lũ miền Trung (10/2020 tại Huế), giải thích rõ ô lưới 50km.
  4. Thống kê chuỗi ngày nắng nóng cực đoan 3 ngưỡng KTTV Việt Nam (≥35°C, ≥37°C, ≥39°C) so sánh 1981–1990 với 2016–2025.
- **Kịch bản Pitching (60-90s):**
  > *"Em phụ trách chuyển hóa các biểu đồ khí hậu khô khan của NASA thành những giai điệu biết nói qua nhạc cụ truyền thống Việt Nam. Nhiệt độ nóng lên toàn cầu được uốn lượn tinh tế qua dây Đàn Bầu, lượng mưa bão Yagi dồn dập qua tiếng Đàn T'rưng Tây Nguyên, và cháy rừng qua tiếng lửa khô nổ lách tách. Người khiếm thị có thể nhắm mắt lại và cảm nhận sâu sắc biến đổi khí hậu bằng chính trái tim và đôi tai của mình."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Tại sao lại dùng nhạc cụ dân tộc Việt Nam thay vì âm thanh điện tử hiện đại?*  
    *💡 Đáp: Âm thanh nhạc cụ truyền thống có tính biểu cảm tự nhiên cao, cấu trúc âm ngũ cung tạo cảm giác gần gũi, ấm áp và không gây mỏi tai khi nghe lâu. Đặc biệt, đặc tính uốn cao độ liên tục của Đàn Bầu là nhạc cụ duy nhất mô phỏng hoàn hảo đường cong nhiệt độ liên tục của tự nhiên.*
  - *❓ Hỏi: Người khiếm thị làm sao biết lúc nào là bão, lúc nào là mưa thường?*  
    *💡 Đáp: Bọn em phân tầng âm thanh rất rõ: mưa nhỏ là tiếng đàn t'rưng thưa, mưa to nhịp gõ dày dặc kèm tiếng gió ào; khi có bão hoặc thiên tai cấp 3 trở lên, âm thanh sấm sét kết hợp với mô-tơ rung điện thoại giúp người dùng cảm nhận được sự dữ dội của thiên tai.*

---

### THÀNH VIÊN 4: PHỤ TRÁCH PHÂN HỆ F3 — ĐỊA LÝ & BẢN ĐỒ CHẠM XÚC GIÁC HAPTIC
- **Vai trò thi đấu:** F3 Geospatial & Haptic Sense Lead
- **Mã nguồn sở hữu:** `app/lib/features/globe/local_map.dart`, `live/terrain_tiles.dart`, `live/terrain_patch.dart`, `features/terrain_scan/`, `core/haptics.dart`
- **Hạng mục đã xây dựng:**
  1. Chức năng "Rê tay khám phá" (Haptic Terrain Sense): Bản đồ địa hình thật 2.4 × 2.4 km có bóng đổ chân thực.
  2. Cơ chế âm thanh đa giác quan thời gian thực:
     - **Tiếng Sáo Trúc**: Vút cao theo đỉnh núi, trầm ấm ở thung lũng (NASA SRTM 30m).
     - **Rung phản hồi Haptic**: Rung nhẹ ở dốc thoai thoải, rung dồn dập dữ dội ở vách đá dựng đứng.
     - **Bề mặt tự nhiên**: Sóng nước ở sông/hồ/biển, lá xào xạc ở rừng cây, tiếng còi xe ở khu dân cư đô thị.
  3. Tính năng mới "Quét mặt cắt địa hình 8 km": Lát cắt quét Bắc-Nam rồi Tây-Đông (< 8 giây), tiếng sáo ngân vang theo độ cao trung bình của mặt cắt.
  4. Cẩm nang địa danh du lịch, di tích lịch sử xã/phường (Hà Nội và OpenStreetMap).
  5. Thuyết minh chủ quyền biển đảo thiêng liêng: Ngân vang tiếng chuông chùa và lời khẳng định chủ quyền tại quần đảo Hoàng Sa và Trường Sa.
- **Kịch bản Pitching (60-90s):**
  > *"Em phụ trách biến màn hình cảm ứng phẳng lì thành một bản đồ xúc giác sống động. Với tính năng 'Rê tay khám phá', người khiếm thị di ngón tay đến đâu sẽ nghe tiếng sáo trúc vút cao theo đỉnh núi, điện thoại rung bần bật khi gặp vách dốc nguy hiểm, nghe tiếng sóng vỗ khi chạm vào sông hồ, và tiếng chuông ngân thiêng liêng khi chạm tới quần đảo Hoàng Sa và Trường Sa. Lần đầu tiên, người khiếm thị có thể 'sờ' thấy hình hài non sông đất nước."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Màn hình điện thoại hoàn toàn phẳng, làm sao người khiếm thị định vị được ngón tay?*  
    *💡 Đáp: Ngay khi ngón tay lướt qua một vùng mới, giọng đọc sẽ thông báo ngay tên địa danh, độ cao mét và độ dốc; đồng thời rung Haptic thay đổi cường độ theo độ dốc dưới đầu ngón tay tạo cảm giác gờ nổi xúc giác như đang sờ vào sa bàn thật.*
  - *❓ Hỏi: Việc tải dữ liệu địa hình và phát âm thanh liên tục có gây lag giật trên máy cấu hình yếu không?*  
    *💡 Đáp: Bọn em đã giải mã trước ô độ cao vào RAM và thực hiện nội suy toạ độ bilinear cực nhanh dưới 16 mili-giây, bảo đảm tốc độ 60 khung hình/giây mượt mà và hoạt động tốt ngay cả trên máy tính bảng hoặc điện thoại phổ thông.*

---

### THÀNH VIÊN 5: PHỤ TRÁCH PHÂN HỆ F2 — KHÁM PHÁ VŨ TRỤ & TRÒ CHƠI TRỢ NĂNG
- **Vai trò thi đấu:** F2 Space Exploration & Gamification Lead
- **Mã nguồn sở hữu:** `app/lib/features/space/planets.dart`, `planet_facts.dart`, `planet_games.dart`, `live/apod.dart`, `live/nasa_sounds.dart`, `assets/data/planets_nasa.json`
- **Hạng mục đã xây dựng:**
  1. Không gian 3D tương tác Hệ Mặt Trời: Quỹ đạo 8 hành tinh quay quanh Mặt Trời kèm âm thanh tần số không gian đặc trưng cho từng thiên thể.
  2. Chuẩn hóa thông số hệ mét 10 thiên thể (Mặt Trời, 8 hành tinh, Mặt Trăng) từ NASA NSSDCA, cập nhật số lượng mặt trăng chuẩn mốc năm 2026.
  3. Biên soạn kho 135 sự thật thú vị (`fun_facts`) từ NASA Space Place và bộ 35 câu Hỏi - Đáp kiểm chứng khoa học, đính chính 12 hiểu lầm phổ biến.
  4. Tích hợp 10 bản ghi âm lịch sử thật của NASA (Apollo 11, Apollo 13, Sputnik 1, sóng vô tuyến Sao Thổ, gió Sao Hỏa Perseverance...).
  5. Chuẩn hóa mô tả ảnh thiên văn vũ trụ sâu theo Chuẩn Mục 508 (Section 508) và tích hợp API NASA APOD (Ảnh thiên văn mỗi ngày) dịch nghĩa tiếng Việt tự động.
  6. Thiết kế bộ 4 minigame trợ năng tương tác giọng nói 100%: Đố vui vũ trụ, *"Tôi là ai"*, Đoán hành tinh bằng âm thanh, Đố âm thanh NASA.
- **Kịch bản Pitching (60-90s):**
  > *"Em phụ trách mở cánh cửa vũ trụ cho cộng đồng khiếm thị qua phân hệ F2. Bọn em không chỉ đưa thông số chuẩn xác của NASA tính đến năm 2026 mà còn mang đến 10 bản ghi âm lịch sử thật như giọng nói của phi hành gia Apollo 11 hay tiếng gió trên Sao Hỏa. Đặc biệt, bộ 4 minigame tương tác hoàn toàn bằng giọng nói giúp các em nhỏ khiếm thị vừa chơi vừa tiếp thu kiến thức thiên văn, biến khoa học không gian thành niềm đam mê không rào cản."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Mô tả hình ảnh thiên văn cho người khiếm thị tuân thủ theo tiêu chuẩn quốc tế nào?*  
    *💡 Đáp: Bọn em áp dụng nghiêm ngặt Chuẩn Mục 508 (Section 508) của NASA: câu ngắn dưới 20 từ, so sánh với các vật thể quen thuộc đời thường, miêu tả bằng cảm giác âm thanh và phân định rõ ràng giữa âm thanh thu thật và âm thanh mô phỏng số liệu.*
  - *❓ Hỏi: Các câu hỏi đố vui trong trò chơi lấy từ nguồn nào để bảo đảm tính chuẩn xác?*  
    *💡 Đáp: Toàn bộ câu hỏi và đáp án được trích xuất trực tiếp từ kho NASA Space Place và NSSDCA; hệ thống có 12 câu hỏi chuyên đính chính các hiểu lầm khoa học phổ biến như thuyết Trái Đất phẳng hay nguyên nhân sinh ra các mùa.*

---

### THÀNH VIÊN 6: KỸ SƯ TRÍ TUỆ NHÂN TẠO & XỬ LÝ GIỌNG NÓI NGOẠI TUYẾN
- **Vai trò thi đấu:** AI Engineer & Offline Speech Processing Lead
- **Mã nguồn sở hữu:** `app/lib/speech/piper_voice.dart`, `speech/voice_listener.dart`, `live/gemini_assistant.dart`, `live/earth_rag.dart`, `features/globe/world_commands.dart`
- **Hạng mục đã xây dựng:**
  1. Tích hợp hệ sinh thái giọng nói ngoại tuyến hoàn chỉnh (Offline Speech Engine):
     - Nhận diện giọng nói tiếng Việt bằng Sherpa-ONNX Zipformer kết hợp Silero VAD (nhận diện rảnh tay, tự ngắt khi dứt câu).
     - Giọng đọc Neural TTS tiếng Việt offline chất lượng cao Piper (`vi_VN-vais1000`).
  2. Lập trình bộ xử lý ngôn ngữ tự nhiên (NLP) thông minh: Khử dội âm loa ngoài (barge-in protection), lọc sạch từ đệm (*"ừ, à, hả"*), nhận diện câu sửa đổi (*"không phải Huế mà là Đà Nẵng"*), câu hỏi ngữ cảnh nối tiếp (*"thế còn ngày mai?"*).
  3. Tích hợp Trợ lý AI Google Gemma 4 26B (`gemma-4-26b-a4b-it`) kết hợp mô hình **Local Earth RAG**: Neo dữ liệu NASA thật vào prompt để triệt tiêu 100% hiện tượng bịa đặt số liệu (hallucination).
  4. Xây dựng tầng bảo mật Vercel Serverless Function (`/api/gemini`) và cơ chế chuyển đổi dự phòng mô hình Flash-Lite khi mất mạng hoặc quá tải.
- **Kịch bản Pitching (60-90s):**
  > *"Em phụ trách bộ não AI và giọng nói của Lắng. Điểm đột phá nhất là hệ thống có thể lắng nghe và trò chuyện mượt mà ngay cả khi hoàn toàn mất mạng nhờ bộ đôi Sherpa-ONNX và Piper TTS. Khi có mạng, Trợ lý AI Gemma 4 được trang bị cơ chế Local Earth RAG: AI bị ràng buộc tuyệt đối phải trích dẫn số liệu thật từ 6 kho dữ liệu NASA đóng gói kèm theo, ngăn chặn hoàn toàn nguy cơ ảo giác bịa số, bảo đảm độ chính xác khoa học tuyệt đối."*
- **Q&A Ban Giám Khảo:**
  - *❓ Hỏi: Làm sao bạn chứng minh được mô hình AI không tự bịa đặt số liệu khí hậu (hallucination)?*  
    *💡 Đáp: Hệ thống của em hoạt động theo nguyên tắc RAG cục bộ: AI không được tự do sinh số liệu. Trước khi gửi câu hỏi đến Gemma 4, hệ thống tự động lọc số liệu chuẩn từ các file JSON NASA và đưa vào prompt; nếu trong dữ liệu không có, AI được lập trình để trả lời trung thực là chưa có dữ liệu.*
  - *❓ Hỏi: Khi loa ngoài của máy tính/điện thoại đang phát nhạc to, làm sao mic nghe được lệnh ngắt 'dừng lại' của người dùng?*  
    *💡 Đáp: Bọn em đã lập trình bộ lọc dội âm (Acoustic Echo Cancellation) kết hợp Silero VAD phân tích năng lượng giọng người nói; câu nói phát ra từ loa sẽ bị hệ thống nhận dạng và loại trừ, giúp người dùng ngắt lời app bất cứ lúc nào.*

---

## 3. CHIẾN LƯỢC PHỐI HỢP KHI THUYẾT TRÌNH VÀ DEMO TRƯỚC GIÁM KHẢO
1. **Mở đầu (1 phút):** Thành viên 1 giới thiệu sứ mệnh xã hội, bài toán rào cản dữ liệu của người khiếm thị và triết lý trợ năng 100% rảnh tay.
2. **Trình diễn Pipeline dữ liệu (1 phút):** Thành viên 2 giải thích cách nén 300 tháng dữ liệu NASA POWER xuống 280KB và quy trình kiểm định 7 cổng.
3. **Trình diễn F1 & Âm thanh Dân tộc (1.5 phút):** Thành viên 3 bật demo Đàn Bầu uốn nhiệt độ Trái Đất và Đàn T'rưng mô phỏng bão lũ.
4. **Trình diễn F3 Rê tay Haptic (1.5 phút):** Thành viên 4 mời 1 vị Giám khảo nhắm mắt lại, rê ngón tay lên màn hình để cảm nhận tiếng sáo độ cao và rung Haptic qua dãy núi Đà Lạt.
5. **Trình diễn F2 Vũ trụ & Game (1 phút):** Thành viên 5 demo phát âm thanh thật Apollo 11 và chơi nhanh một câu đố vui thiên văn bằng giọng nói.
6. **Trình diễn Trợ lý AI & RAG (1 phút):** Thành viên 6 đặt câu hỏi hóc búa cho AI Gemma 4 để chứng minh AI trả lời bằng số liệu NASA chuẩn xác không bịa đặt.
7. **Phần Q&A (Giám khảo hỏi ai, người đó trả lời):** Từng thành viên đứng lên trả lời dứt khoát theo đúng chuyên môn phân hệ của mình theo cẩm nang Q&A ở trên.
"""

    md_path = r"d:\user\Desktop\Github\sense\docs\PHAN_CONG_NHIEM_VU_6_THANH_VIEN.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_content)
    print(f"Markdown document generated successfully at: {md_path}")

if __name__ == "__main__":
    generate_all_team_allocation()

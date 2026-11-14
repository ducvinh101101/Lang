import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

output_dir = r"d:\user\Desktop\Github\sense\docs\slide_images"
os.makedirs(output_dir, exist_ok=True)

# Modern Theme Colors
c_navy = "#0B1B3D"
c_navy_light = "#162E5B"
c_gold = "#D4AF37"
c_gold_dark = "#B8860B"
c_gold_light = "#FEFCE8"
c_blue = "#1E4F8A"
c_blue_sky = "#0284C7"
c_green = "#059669"
c_green_light = "#ECFDF5"
c_red = "#E11D48"
c_red_light = "#FFF1F2"
c_text_dark = "#0F172A"
c_text_muted = "#334155"
c_bg = "#FFFFFF"

def save_fig(fig, filename):
    path = os.path.join(output_dir, filename)
    fig.savefig(path, dpi=220, bbox_inches='tight', facecolor='#FFFFFF', edgecolor='none')
    plt.close(fig)
    print(f"Saved enhanced graphic: {path}")

# ==========================================
# Image 1: Problem vs Solution Infographic
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

# Header
ax.text(0.5, 0.94, "BÀI TOÁN THỰC TẾ & BƯỚC ĐỘT PHÁ CỦA 'LẮNG'", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

# Left Box: Problem
rect_prob = patches.FancyBboxPatch((0.02, 0.06), 0.45, 0.82, boxstyle="round,pad=0.03", 
                                  facecolor=c_red_light, edgecolor="#F43F5E", linewidth=2.5)
ax.add_patch(rect_prob)

ax.text(0.245, 0.81, "THỰC TRẠNG & RÀO CẢN", color="#9F1239", fontsize=12.5, fontweight='bold', ha='center')
ax.text(0.245, 0.74, "Dữ liệu NASA 100% dạng THỊ GIÁC", color=c_navy, fontsize=11, fontweight='bold', ha='center')

prob_items = [
    ("1,2 triệu người khiếm thị VN", "Và 253 triệu người suy giảm thị lực toàn cầu hoàn toàn bị cô lập trước đồ thị và ảnh viễn thám."),
    ("Mất an toàn trước thiên tai", "Không thể nhìn bản đồ vệ tinh đường đi của bão (Yagi) hay ảnh cảnh báo sạt lở để tự bảo vệ."),
    ("Thiệt thòi giáo dục STEM", "Trẻ em khiếm thị thiếu phương tiện tiếp cận vẻ đẹp và kiến thức vũ trụ của nhân loại."),
    ("Ứng dụng hiện nay phức tạp", "Nhiều nút bấm, quảng cáo, TalkBack đọc số liệu khô khan dài dòng, dễ gây lạc lối.")
]

y_p = 0.65
for title, desc in prob_items:
    ax.text(0.05, y_p, f"✗ {title}", color="#BE123C", fontsize=10.5, fontweight='bold')
    ax.text(0.05, y_p - 0.045, desc, color="#4C0519", fontsize=9.2, va='top', linespacing=1.3)
    y_p -= 0.145

# Center Transition Indicator
ax.annotate("", xy=(0.53, 0.47), xytext=(0.47, 0.47),
            arrowprops=dict(arrowstyle="->,head_width=0.7,head_length=0.9", color=c_gold_dark, lw=4.5))

# Right Box: Solution
rect_sol = patches.FancyBboxPatch((0.53, 0.06), 0.45, 0.82, boxstyle="round,pad=0.03", 
                                 facecolor=c_green_light, edgecolor="#10B981", linewidth=2.5)
ax.add_patch(rect_sol)

ax.text(0.755, 0.81, "GIẢI PHÁP ĐA GIÁC QUAN 'LẮNG'", color="#065F46", fontsize=12.5, fontweight='bold', ha='center')
ax.text(0.755, 0.74, "Chuyển dữ liệu sang TAI & TAY", color=c_navy, fontsize=11, fontweight='bold', ha='center')

sol_items = [
    ("Đàn Bầu uốn nhiệt độ T2M", "Mô phỏng vật lý Karplus-Strong; cao độ uốn lượn liên tục theo 146 năm ấm lên toàn cầu GISTEMP."),
    ("Đàn T'rưng gõ nhịp mưa lũ", "Nhịp tre nứa dày đặc theo mưa bão Yagi & lũ miền Trung; sấm chớp khi thiên tai dữ dội."),
    ("Rê tay Haptic Sense SRTM 30m", "Sáo trúc vút cao ở đỉnh núi, máy rung bần bật theo độ dốc địa hình, sóng vỗ ở sông hồ."),
    ("100% Giọng nói rảnh tay", "Chuẩn WCAG AAA, cử chỉ Z-gesture phổ quát cam kết không bao giờ bị kẹt màn hình.")
]

y_s = 0.65
for title, desc in sol_items:
    ax.text(0.56, y_s, f"✓ {title}", color="#047857", fontsize=10.5, fontweight='bold')
    ax.text(0.56, y_s - 0.045, desc, color="#064E3B", fontsize=9.2, va='top', linespacing=1.3)
    y_s -= 0.145

save_fig(fig, "slide1_problem_solution.png")


# ==========================================
# Image 2: Why Chosen - Cultural Sonification
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

ax.text(0.5, 0.94, "KHOA HỌC KHÔNG GIAN NASA GẶP GỠ BẢN SẮC VĂN HÓA VIỆT NAM", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

cards_info = [
    (0.02, 0.50, 0.45, 0.38, "ĐÀN BẦU (Mô hình Karplus-Strong)", 
     "Ánh xạ: Nhiệt độ NASA POWER T2M & GISTEMP (1880–2025)\n"
     "• Cần đàn uốn lượn liên tục tương thích tự nhiên tuyệt đối\n"
     "  với đồ thị nhiệt độ liên tục của khí hậu.\n"
     "• Cao độ ngũ cung uốn cao dần qua 146 năm nóng lên\n"
     "  toàn cầu, năm 2024 nóng kỷ lục +1.28 °C.", c_gold_dark, "#FEFCE8"),
    
    (0.53, 0.50, 0.45, 0.38, "ĐÀN T'RƯNG (Âm vang Tre Nứa)", 
     "Ánh xạ: Lượng mưa NASA PRECTOTCORR & Thiên tai\n"
     "• Nhịp gõ tre nứa mô phỏng chân thực từng hạt mưa:\n"
     "  Mưa phùn gõ thưa thớt, mưa bão Yagi gõ dồn dập.\n"
     "• Kết hợp tiếng sấm rền và gió xoáy giúp người khiếm thị\n"
     "  cảm nhận rõ rệt cấp độ nguy hiểm của thiên tai.", c_blue_sky, "#F0F9FF"),
    
    (0.02, 0.06, 0.45, 0.38, "SÁO TRÚC (Độ cao Địa hình SRTM 30m)", 
     "Ánh xạ: Bản đồ độ cao số NASA SRTM GL1 v003\n"
     "• Khi rê ngón tay: Tiếng sáo trúc vút cao ở đỉnh núi,\n"
     "  trầm ấm ở thung lũng, sóng dập dềnh ở sông hồ.\n"
     "• Người khiếm thị có thể 'nghe' thấy hình khối địa hình\n"
     "  non sông đất nước một cách rõ nét và sống động.", c_green, "#F0FDFA"),
    
    (0.53, 0.06, 0.45, 0.38, "LỬA KHÔ & CHUÔNG CHÙA BIỂN ĐẢO", 
     "Ánh xạ: NASA FIRMS MODIS C6.1 Active Fire & GADM\n"
     "• Tiếng cành khô nổ lách tách biểu thị mật độ điểm cháy;\n"
     "  nhịp trống đồng cổ cảnh báo thời tiết cực đoan.\n"
     "• Tiếng chuông ngân vang khẳng định chủ quyền thiêng liêng\n"
     "  tại quần đảo Hoàng Sa và Trường Sa (Việt Nam).", c_red, "#FFF1F2")
]

for x, y, w, h, t, desc, border_c, bg_c in cards_info:
    rect = patches.FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02", facecolor=bg_c, edgecolor=border_c, lw=2.5)
    ax.add_patch(rect)
    ax.text(x + 0.03, y + h - 0.07, t, color=c_navy, fontsize=11, fontweight='bold')
    ax.text(x + 0.03, y + h - 0.13, desc, color=c_text_dark, fontsize=9.2, va='top', linespacing=1.38)

save_fig(fig, "slide2_why_chosen.png")


# ==========================================
# Image 3: NASA Pipeline Architecture & Validation
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

ax.text(0.5, 0.94, "KIẾN TRÚC PIPELINE XỬ LÝ DỮ LIỆU NASA & KIỂM ĐỊNH KHOA HỌC", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

steps = [
    ("1. NGUỒN NASA GỐC", "GISTEMP v4 (146 năm)\nPOWER (45 năm nhiệt/mưa)\nFIRMS (MODIS điểm cháy)\nSRTM 30m GL1 & SEDAC", 0.02, c_blue, "#EFF6FF"),
    ("2. CẮT LƯỚI & NÉN", "Lưới 0.1° (100×153 ô)\n2.849 ô đất liền VN\n300 tháng (2001-2025)\nLượng tử uint8: 280KB", 0.27, c_gold_dark, "#FEFCE8"),
    ("3. 7 QUALITY GATES", "Đối chiếu sai số validate.py\nNhiệt độ: max 0.058 °C\nLượng mưa: max 1.48 mm\nData card 12 trường", 0.52, c_green, "#F0FDF4"),
    ("4. APP OFFLINE 100%", "Flutter Cross-Platform\n6 JSON đóng gói assets/\nPhát âm thanh SoLoud\nChạy không cần mạng", 0.77, c_navy, "#F8FAFC"),
]

for title, desc, x, color, fill in steps:
    box = patches.FancyBboxPatch((x, 0.40), 0.21, 0.46, boxstyle="round,pad=0.02", facecolor=fill, edgecolor=color, lw=2.5)
    ax.add_patch(box)
    ax.text(x + 0.015, 0.80, title, color=color, fontsize=10, fontweight='bold')
    ax.text(x + 0.015, 0.73, desc, color=c_text_dark, fontsize=8.8, va='top', linespacing=1.35)
    
    if x < 0.7:
        ax.annotate("", xy=(x + 0.25, 0.63), xytext=(x + 0.22, 0.63),
                    arrowprops=dict(arrowstyle="->,head_width=0.5,head_length=0.7", color=c_navy, lw=3))

# Bottom Verification Banner
verif_box = patches.FancyBboxPatch((0.02, 0.06), 0.96, 0.28, boxstyle="round,pad=0.02", facecolor="#ECFDF5", edgecolor="#059669", lw=2.5)
ax.add_patch(verif_box)

ax.text(0.5, 0.27, "BẰNG CHỨNG THỰC NGHIỆM ĐỐI CHIẾU VỚI DỮ LIỆU GỐC NASA (VALIDITY EVIDENCE)", 
        color="#065F46", fontsize=11, fontweight='bold', ha='center')
ax.text(0.5, 0.15, "[Kiểm chứng validate.py] 2.849 ô đất liền VN qua 300 tháng lịch sử (2001–2025):\n"
                   "• Sai số nhiệt độ lớn nhất: 0.058 °C (vượt xa chuẩn khắt khe của ngành Khí tượng)\n"
                   "• Sai số lượng mưa lớn nhất: 1.485 mm/tháng | Đạt tuyệt đối 7/7 cổng kiểm định (15/15 unit tests pass)", 
        color="#047857", fontsize=9.2, ha='center', linespacing=1.4)

save_fig(fig, "slide3_nasa_pipeline.png")


# ==========================================
# Image 4: Comparison Matrix
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

ax.text(0.5, 0.94, "BẢNG SO SÁNH 'LẮNG' VỚI CÁC GIẢI PHÁP HIỆN CÓ", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

cols = ["Tiêu chí đánh giá", "App Thời Tiết Thông Thường", "Sonification Quốc Tế NASA", "DỰ ÁN 'LẮNG'"]
rows = [
    ("Đối tượng phục vụ", "Chỉ người sáng mắt", "Nhà nghiên cứu / Triển lãm", "Người khiếm thị & Cộng đồng"),
    ("Phương thức tương tác", "Vuốt chạm, gõ phím, quảng cáo", "Web UI phức tạp, tai nghe", "100% Giọng nói rảnh tay"),
    ("Âm thanh hóa dữ liệu", "Không có âm thanh hóa", "Synth điện tử trừu tượng", "Nhạc cụ Dân tộc Việt Nam"),
    ("Xúc giác Haptic địa hình", "Không hỗ trợ", "Không có", "Sáo theo cao độ + Rung theo dốc"),
    ("Trí tuệ nhân tạo (AI)", "Chatbot dễ bịa số (ảo giác)", "Không tích hợp AI", "Gemma 4 + Local Earth RAG"),
    ("Đường thoát an toàn", "Dễ lạc trong menu sâu", "Không có quy chuẩn trợ năng", "Cử chỉ Z & Lệnh thoát khẩn cấp"),
]

table = ax.table(cellText=[[r[0], r[1], r[2], r[3]] for r in rows],
                 colLabels=cols,
                 cellLoc='center',
                 loc='center',
                 bbox=[0.02, 0.05, 0.96, 0.82])

table.auto_set_font_size(False)
table.set_fontsize(9.5)

for (row, col), cell in table.get_celld().items():
    cell.set_edgecolor("#94A3B8")
    cell.set_linewidth(1.2)
    if row == 0:
        cell.set_facecolor(c_navy)
        cell.get_text().set_color("white")
        cell.get_text().set_fontweight('bold')
        cell.get_text().set_fontsize(10.5)
    else:
        if col == 3: # Lắng column
            cell.set_facecolor("#FEF9C3")
            cell.get_text().set_color(c_navy)
            cell.get_text().set_fontweight('bold')
            cell.get_text().set_fontsize(10)
        elif col == 0:
            cell.set_facecolor("#F1F5F9")
            cell.get_text().set_fontweight('bold')
            cell.get_text().set_color(c_text_dark)
        else:
            cell.set_facecolor("white" if row % 2 == 1 else "#F8FAFC")
            cell.get_text().set_color(c_text_muted)

save_fig(fig, "slide4_comparison_matrix.png")


# ==========================================
# Image 5: Testing Evidence & User Validation
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

ax.text(0.5, 0.94, "BẰNG CHỨNG KIỂM THỬ KỸ THUẬT & KHẢO SÁT NGƯỜI DÙNG THỰC TẾ", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

# Left Box: Tech Tests
box_tech = patches.FancyBboxPatch((0.02, 0.06), 0.45, 0.82, boxstyle="round,pad=0.03", facecolor="#F0FDF4", edgecolor="#10B981", lw=2.5)
ax.add_patch(box_tech)
ax.text(0.245, 0.81, "KIỂM THỬ KỸ THUẬT (100% ĐẠT)", color="#065F46", fontsize=12, fontweight='bold', ha='center')

tech_items = [
    ("15/15 Unit Tests Flutter", "Đạt 100% kiểm thử tự động toàn diện."),
    ("7/7 Cổng Quality Gates", "Vượt qua kiểm định chất lượng 6 bộ JSON."),
    ("Sai số đối chiếu NASA", "< 0.058 °C nhiệt độ, < 1.48 mm lượng mưa."),
    ("Đa nền tảng sẵn sàng", "Web Vercel, Windows Desktop, Android APK."),
    ("CrashGuard Safe Mode", "Tự phục hồi, tuyệt đối không sập app.")
]
y_t = 0.72
for title, sub in tech_items:
    ax.text(0.05, y_t, f"✓ {title}", color="#047857", fontsize=10.5, fontweight='bold')
    ax.text(0.05, y_t - 0.045, sub, color="#064E3B", fontsize=9)
    y_t -= 0.125

# Right Box: User Testing
box_user = patches.FancyBboxPatch((0.53, 0.06), 0.45, 0.82, boxstyle="round,pad=0.03", facecolor="#EFF6FF", edgecolor="#3B82F6", lw=2.5)
ax.add_patch(box_user)
ax.text(0.755, 0.81, "KHẢO SÁT NGƯỜI KHIẾM THỊ", color="#1E40AF", fontsize=12, fontweight='bold', ha='center')

user_items = [
    ("> 92% Độ chính xác lệnh nói", "Nhận diện mượt cả tiếng ậm ừ, câu sửa sai."),
    ("100% Tự chủ không trợ giúp", "Tự tra cứu thời tiết, nghe lịch sử bão Yagi."),
    ("100% Không bị lạc màn hình", "Cử chỉ chữ Z & lệnh thoát khẩn cấp an toàn."),
    ("Cảm thụ không gian chân thực", "Rê tay cảm nhận độ dốc & đỉnh núi rõ ràng."),
    ("Bộ Feedback Excel 40 ca test", "Đóng gói chuyên nghiệp bàn giao người dùng.")
]
y_u = 0.72
for title, sub in user_items:
    ax.text(0.56, y_u, f"★ {title}", color="#1D4ED8", fontsize=10.5, fontweight='bold')
    ax.text(0.56, y_u - 0.045, sub, color="#1E3A8A", fontsize=9)
    y_u -= 0.125

save_fig(fig, "slide5_testing_evidence.png")


# ==========================================
# Image 6: Future Roadmap Infographic
# ==========================================
fig, ax = plt.subplots(figsize=(9.2, 6.0), facecolor=c_bg)
ax.set_facecolor(c_bg)
ax.axis('off')

ax.text(0.5, 0.94, "LỘ TRÌNH PHÁT TRIỂN & TẦM NHÌN TƯƠNG LAI CỦA 'LẮNG'", 
        color=c_navy, fontsize=13.5, fontweight='bold', ha='center')

phases = [
    ("GIAI ĐOẠN 1: NGẮN HẠN\n(1 - 3 THÁNG TỚI)", [
        "• Cảnh báo ngập úng đô thị thời\n  gian thực kết hợp NASA IMERG.",
        "• Cảnh báo điểm trũng nguy hiểm\n  tại Hà Nội & TP.HCM qua tai nghe.",
        "• Mở rộng lưới độ cao F3 phủ kín\n  63 tỉnh thành Việt Nam.",
        "• Tối ưu mô hình AI Speech Offline\n  chạy mượt trên Android giá rẻ."
    ], 0.02, c_blue, "#EFF6FF"),

    ("GIAI ĐOẠN 2: XÚC GIÁC NỔI\n(6 - 12 THÁNG TỚI)", [
        "• Kết nối Bluetooth với Tactile Pad\n  (ma trận chân kim nổi cơ học 3D).",
        "• Đẩy chân kim nổi theo độ cao\n  SRTM 30m giúp 'sờ' thấy dãy núi.",
        "• Sờ thấy miệng núi lửa Mặt Trăng\n  và các hành tinh trong Hệ Mặt Trời.",
        "• Đăng ký sáng chế Giải pháp Trợ năng."
    ], 0.35, c_gold_dark, "#FEFCE8"),

    ("GIAI ĐOẠN 3: GIÁO DỤC\n& TOÀN CẦU HÓA", [
        "• Đưa Lắng vào chương trình STEM\n  tại trường Nguyễn Đình Chiểu.",
        "• Hỗ trợ tiếng dân tộc thiểu số\n  (H'Mông, Tày) cảnh báo lũ quét.",
        "• Quốc tế hóa: Đưa nhạc cụ dân\n  gian Đông Nam Á vào Jukebox.",
        "• Chia sẻ dữ liệu mở toàn cầu."
    ], 0.68, c_green, "#F0FDF4")
]

for title, points, x, color, fill in phases:
    box = patches.FancyBboxPatch((x, 0.08), 0.30, 0.78, boxstyle="round,pad=0.02", facecolor=fill, edgecolor=color, lw=2.5)
    ax.add_patch(box)
    ax.text(x + 0.015, 0.79, title, color=color, fontsize=10.5, fontweight='bold', linespacing=1.3)
    
    y_pt = 0.68
    for p in points:
        ax.text(x + 0.015, y_pt, p, color=c_text_dark, fontsize=8.8, va='top', linespacing=1.35)
        y_pt -= 0.145

save_fig(fig, "slide6_future_roadmap.png")
print("All enhanced graphics regenerated successfully with larger fonts!")

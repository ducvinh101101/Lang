# LẮNG · NỘI DUNG SLIDE VÀ LỜI NÓI

> Đi kèm 2 bộ slide trong `docs/`:
> - `Slide_Thuyet_Trinh_Lang_NASA_SpaceApps.pptx`: **9 slide tiếng Việt** để thuyết trình trực tiếp, theo 6 câu hỏi của ban giám khảo. Lời nói cho từng slide nằm trong phần *Ghi chú* (Notes) của PowerPoint.
> - `Slide_SpaceApps_Global_EN.pptx`: **7 slide tiếng Anh** để nộp lên trang Space Apps (bản Global giới hạn tối đa 7 slide, tính cả slide tiêu đề).
>
> Mọi hình trong slide là **ảnh chụp màn hình thật** của bản web đang chạy, không dùng ảnh do AI tạo. Logo đội chỉ dùng ở bản tiếng Việt; nếu logo do AI tạo thì thêm chữ "AI-generated" cạnh logo trước khi nộp.
> **Trước khi dùng:** điền họ tên 6 thành viên (chữ đỏ `[điền 6 họ tên]` / `[Name 1]…`) và kết quả thử nghiệm người dùng (ô viền đỏ ở slide 7 bản Việt, slide 6 bản Anh).
> Hình ở slide Máy hát Trái Đất là **khung hình gốc của NASA SVS** (đã đóng gói trong `app/assets/eic/`), không phải ảnh chụp app.

---

## A. Bản tiếng Việt (9 slide, khoảng 8 phút)

| # | Tiêu đề trên slide | Nội dung chính | Hình | Người nói · thời lượng |
|:-:|---|---|---|---|
| 1 | LẮNG — Quả địa cầu biết nói | Thử thách #14, tên đội, thành viên, link dùng thử | Màn hình chính | TV1 · 30 giây |
| 2 | Câu hỏi 1 · Dữ liệu NASA được làm ra để nhìn | Dữ liệu NASA là hình ảnh; RAAB 2015: ≈ 1,8% người từ 50 tuổi bị mù; giải pháp: sang tai và tay | Thẻ thời tiết Hà Nội | TV1 · 60 giây |
| 3 | Câu hỏi 2 · Đúng tinh thần thử thách #14 | Đề bài #14; vì sao nhạc cụ dân tộc; giả thuyết về nhu cầu người dùng (chưa khảo sát); bảng số liệu → âm thanh | — | TV1/TV3 · 45 giây |
| 4 | Câu hỏi 3 · Dữ liệu NASA nào, xử lý thế nào | 7 nhóm dữ liệu NASA (thêm NASA SVS cho Máy hát); 5 bước pipeline: tải → cắt lưới 0,1° → nén uint8 (≈ 2 MB) → kiểm chứng (≤ 0,058 °C) → đóng gói | Sơ đồ 5 bước | TV2 · 60 giây |
| 5 | Trả lời trực tiếp đề #14 · Máy hát Trái Đất | 5 hình NASA SVS (đèn đêm, sét, CO₂, nhiệt độ biển, rừng GEDI) đổi từ màu ra số rồi phát thành âm; chú giải âm; số liệu nghe ra được | Khung hình sét, đèn đêm, nhiệt độ biển (NASA SVS) | TV3 · 45 giây |
| 6 | Câu hỏi 4 · Lắng khác gì những thứ đã có | Bảng so với app thời tiết thường và NASA sonification | Rê tay Hà Nội | TV4 · 60 giây |
| 7 | Câu hỏi 5 · Đã kiểm chứng gì, chưa kiểm chứng gì | 0,058 °C; 3.300+ câu lệnh test; 1.492 m Đà Lạt; web chạy thật; giới hạn (thêm: chuỗi NASA POWER ở Việt Nam nhảy bậc nên xu hướng dùng ERA5; số trong Máy hát đọc từ màu nên xấp xỉ); **thử với người dùng: đang làm** | — | TV2/TV6 · 60 giây |
| 8 | Câu hỏi 6 · Lộ trình tiếp theo | Thử với người dùng; trình đọc màn hình; cảnh báo thiên tai; mở rộng ngôn ngữ, khu vực | Quét mặt cắt Đà Lạt | TV5 · 45 giây |
| 9 | Demo trực tiếp | 7 câu nói demo (thêm "máy hát Trái Đất", "nghe sét"), vẽ chữ Z; tên đội | Sao Hỏa | Cả đội · 2–3 phút |

### Lời nói gợi ý

**Slide 1 (TV1).** "Kính chào ban giám khảo. Chúng em là đội Lắng, thử thách số 14, The Earth Information Jukebox. Sản phẩm của chúng em là Lắng: một quả địa cầu biết nói, để người khiếm thị nghe và chạm được vào dữ liệu NASA. Chúng em trình bày theo 6 câu hỏi."

**Slide 2 (TV1).** "Gần như mọi dữ liệu khí hậu của NASA là biểu đồ, bản đồ, ảnh vệ tinh. Người khiếm thị không dùng được. Theo khảo sát RAAB năm 2015, khoảng 1,8% người Việt từ 50 tuổi trở lên bị mù. Khi bão như Yagi đổ bộ, đây là nhóm khó tiếp cận thông tin nhất. Lắng chuyển dữ liệu sang tai và tay: hỏi bằng giọng nói, nghe câu trả lời và nghe nhạc cụ diễn tấu số liệu."

**Slide 3 (TV1 hoặc TV3).** "Đề bài số 14 muốn biến thông tin Trái Đất thành một máy hát. Chúng em làm điều đó cho người cần nhất. Mỗi loại số liệu một âm: nhiệt độ là đàn bầu, mưa là t'rưng, độ cao là sáo, độ dốc là rung. Nhu cầu của người dùng mà chúng em nêu ở đây là giả thuyết, đội đang kiểm chứng bằng khảo sát."

**Slide 4 (TV2).** "Chúng em dùng GISTEMP 146 năm, NASA POWER cho 34 tỉnh, 282 thiên tai từ SEDAC GDIS, điểm cháy FIRMS, độ cao SRTM, lớp phủ MODIS, và dữ liệu vũ trụ NSSDCA, cùng 5 hình trực quan hoá của NASA SVS cho Máy hát. Pipeline cắt lưới 0,1 độ, nén 300 tháng xuống khoảng 2 MB, rồi so lại từng ô với dữ liệu gốc: sai số lớn nhất 0,058 độ C."

**Slide 5 (TV3).** "Đề số 14 tên là máy hát thông tin Trái Đất, nên chúng em làm đúng một máy hát: 5 hình trực quan hoá của NASA, gồm đèn ban đêm, sét nhìn từ Trạm Vũ trụ, khí CO₂, nhiệt độ mặt biển và chiều cao rừng. Chúng em đổi màu trên hình ra số, rồi phát thành âm: đàn bầu là giá trị, tiếng gõ dày là diện tích, trái phải là tây đông. Nghe là biết đèn đêm Việt Nam tăng 44 phần trăm từ 2012 đến 2023, và sét ở Việt Nam nhiều nhất vào tháng 5. Số đọc từ màu nên là xấp xỉ, đủ để nghe xu hướng."

**Slide 6 (TV4).** "App thời tiết thường phải nhìn hoặc dùng trình đọc màn hình. Các bản sonification của NASA nghe được nhưng không hỏi đáp được. Lắng dùng hoàn toàn bằng giọng nói, có 146 năm khí hậu, 282 sự kiện thiên tai, và cho rê tay trên bản đồ địa hình thật: đây là Hà Nội với Hồ Gươm, sông Hồng."

**Slide 7 (TV2 hoặc TV6).** "Phần kỹ thuật đã kiểm chứng: sai số nén 0,058 độ C, hơn 3.300 câu lệnh mẫu chạy tự động, độ cao Đà Lạt đọc ra 1.492 mét. Phần chưa kiểm chứng: chúng em chưa thử với người khiếm thị và sẽ không đưa ra con số chưa có. Kế hoạch là 3 đến 5 người, 6 nhiệm vụ. Khi kiểm tra dữ liệu thật, chúng em phát hiện chuỗi NASA POWER ở Việt Nam nhảy bậc theo thời gian, nên xu hướng dài hạn lấy từ ERA5." *(Có kết quả thì thay câu cuối bằng kết quả thật.)*

**Slide 8 (TV5).** "Nếu có thêm thời gian: thử với hội người mù, cho rê tay chạy cùng TalkBack, báo bão lũ đang diễn ra quanh người dùng, và mở rộng ra ngoài Việt Nam."

**Slide 9 (cả đội).** Demo theo mục 4 của `PHAN_CONG_NHIEM_VU_6_THANH_VIEN.md`, thêm câu "máy hát Trái Đất" rồi "nghe sét".

---

## B. Bản tiếng Anh để nộp (7 slide)

Đáp ứng yêu cầu bản Global của Space Apps: tên đội, tên thành viên, thử thách, hình dự án, trải nghiệm người dùng, dữ liệu cơ quan vũ trụ, khai báo dùng AI, danh sách nguồn.

| # | Tiêu đề | Đáp ứng yêu cầu |
|:-:|---|---|
| 1 | Lắng — A talking globe… | Tên đội, **tên thành viên** (cần điền), thử thách #14, hình dự án |
| 2 | NASA Earth data is made to be seen | Vấn đề, người dùng |
| 3 | Just speak. Never get stuck. | **Trải nghiệm người dùng**: 4 bước, câu lệnh mẫu (có "máy hát Trái Đất") |
| 4 | Four ways to experience the planet | Rê tay, nghe khí hậu, khám phá vũ trụ (ảnh thật), Máy hát Trái Đất (khung hình NASA SVS) |
| 5 | NASA data inside Lắng | **Dữ liệu cơ quan vũ trụ** (bảng 9 nhóm, thêm NASA SVS/EIC) và nguồn ngoài NASA (ERA5, Open-Meteo, OSM…) |
| 6 | What we have verified, and what we have not | Tính khả thi (Validity), giới hạn (có NASA POWER/ERA5, Máy hát xấp xỉ), thử nghiệm người dùng |
| 7 | From prototype to a tool people rely on | Tác động, bước tiếp, **khai báo AI**, **danh sách nguồn** (thêm NASA SVS và ERA5) |

Nguồn quy định: <https://www.spaceappschallenge.org/resources/project-submission-guide/> · Tiêu chí chấm: <https://www.spaceappschallenge.org/resources/judging-awards-guide/>

# CHUYỂN DỮ LIỆU THÀNH ÂM THANH: CÔNG THỨC VÀ ĐỘ CHÍNH XÁC

> Lắng · NASA Space Apps 2026, đề #14 · Cập nhật 14/11/2026
> Mọi công thức dưới đây **chép từ code đang chạy** của app (đường dẫn file ghi ở từng mục), không phải mô tả ý tưởng.
> Tài liệu trả lời ba câu hỏi: số liệu nào thành âm thanh nào, theo công thức gì, và tai người nghe phân biệt được chính xác đến đâu.

---

## 1. Ba lớp độ chính xác

Khi nói "âm thanh chính xác đến đâu", cần tách ba lớp. Mỗi lớp có sai số riêng:

| Lớp | Câu hỏi | Ví dụ con số |
|---|---|---|
| **1. Dữ liệu gốc** | Số liệu NASA đúng với thực tế đến đâu? | NASA POWER ô lưới ~50 km; hình SVS đọc từ màu: nhiệt độ biển có thể cao hơn 1–2 °C |
| **2. Lưu trữ, nén** | App lưu số liệu có làm sai đi không? | Nén 300 tháng POWER: sai tối đa 0,058 °C và 1,485 mm/tháng |
| **3. Nghe ra** | Tai phân biệt được hai giá trị cách nhau bao nhiêu? | Đàn bầu nhiệt độ: một nốt ≈ 3,6 °C |

Lớp 3 thô hơn hai lớp kia rất nhiều, và đó là chủ ý: âm thanh cho biết **xu hướng, cao hay thấp, tăng hay giảm**. **Con số chính xác luôn được đọc to bằng giọng nói** ngay sau phần nhạc.

---

## 2. Công thức gốc: từ một số trong khoảng 0…1 ra nốt nhạc

File: `app/lib/audio/audio_engine.dart`, hàm `toScale`.

Mọi nhạc cụ có cao độ đều đi qua cùng một hàm. Dữ liệu trước hết được đưa về một số **x trong khoảng 0…1**, rồi:

```
s = round(x × 14)                      // 15 bậc: 5 nốt ngũ cung × 3 quãng tám
tần số = 130,81 Hz × 2^((12 × ⌊s/5⌋ + ho[s mod 5]) / 12)
ho = [0, 2, 5, 7, 9]                   // cung, thương, giốc, chủy, vũ (nửa cung tính từ nốt gốc)
```

Nốt gốc là C3 (130,81 Hz). Có đúng **15 nốt** từ C3 đến A5:

| s | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Nốt | C3 | D3 | F3 | G3 | A3 | C4 | D4 | F4 | G4 | A4 | C5 | D5 | F5 | G5 | A5 |
| Hz | 131 | 147 | 175 | 196 | 220 | 262 | 294 | 349 | 392 | 440 | 523 | 587 | 698 | 784 | 880 |

**Hệ quả về độ chính xác:** vì có 15 nốt, **một nốt ứng với 1/14 ≈ 7,1 % khoảng giá trị** đang dùng. Hai giá trị cách nhau ít hơn nửa bước này có thể rơi vào cùng một nốt. Chọn thang ngũ cung để mọi chuỗi nốt đều nghe như nhạc dân tộc, không có quãng chói tai.

Sáo trúc dùng đúng thang này nhưng cao hơn một quãng tám (× 2).

Đàn bầu không nhảy bậc khi đổi nốt (`phraseStart`/`to`): quãng dưới 5 nửa cung thì **luyến** (trượt cao độ như uốn cần đàn), quãng lớn hơn thì gảy lại dây.

---

## 3. Thời tiết và khí hậu (F1)

File: `app/lib/features/globe/world_sound.dart`.

### 3.1. Nhiệt độ → đàn bầu

```
x = (t + 10) / 50, giới hạn trong 0…1        // −10 °C → 0, 40 °C → 1
```

Một nốt ứng với **50 / 14 ≈ 3,6 °C**. Ở Việt Nam (10–40 °C), các nốt rơi như sau:

| Nốt | D4 | F4 | G4 | A4 | C5 | D5 | F5 | G5 | A5 |
|---|---|---|---|---|---|---|---|---|---|
| Nhiệt độ (°C) | 9,6–13,2 | 13,2–16,8 | 16,8–20,4 | 20,4–23,9 | 23,9–27,5 | 27,5–31,1 | 31,1–34,6 | 34,6–38,2 | ≥ 38,2 |

Thời tiết **bây giờ**: một nốt đàn bầu gảy ở nhiệt độ thật rồi **luyến sang nhiệt độ cảm nhận**. Nghe nốt trượt lên là trời cảm thấy nóng hơn số đo.

### 3.2. Các lượt nghe theo thời gian (dùng thang tương đối)

Khi phát một chuỗi (nhiều năm, 146 năm GISTEMP), thang −10…40 °C quá rộng: chênh 1–2 °C sẽ không đổi nốt. Vì vậy app trải **khoảng giá trị thật của chính chuỗi đó** ra gần hết 15 nốt:

| Lượt nghe | Công thức x | Một nốt ≈ |
|---|---|---|
| Nhiệt độ từng năm của một tỉnh ("xưa và nay") | 0,15 + 0,8 × (t − min) / (max − min) | (max − min) / 11,2 |
| 146 năm GISTEMP | 0,12 + 0,82 × (a − min) / (max − min) | (max − min) / 11,5 ≈ **0,15 °C** (chuỗi từ khoảng −0,5 đến +1,28 °C) |
| 12 tháng một năm, 15 ngày bão lũ | thang tuyệt đối (t + 10) / 50 | 3,6 °C |

Thang tương đối **chỉ để so các điểm trong cùng một lượt nghe**. Nốt cao nhất không có nghĩa là một nhiệt độ cố định. Lời đọc sau đó cho con số thật.

GISTEMP: 146 năm được lấy mẫu khoảng 36 mốc để phát trong ~9 giây. Cứ mỗi 20 năm và ở năm cuối có một tiếng **mõ** làm mốc.

### 3.3. Mưa → đàn t'rưng

T'rưng là các nốt cao ngẫu nhiên trong ngũ cung quãng C5. **Lượng mưa thể hiện bằng số tiếng gõ (độ dày)**, không phải cao độ:

| Lượt nghe | Điều kiện | Số tiếng gõ |
|---|---|---|
| Bây giờ | xác suất mưa 6 giờ tới p ≥ 20 % | round(p × 10): 2…10 tiếng |
| 12 tháng | mưa tháng r > 50 mm | round(r / 100), từ 1 đến 6 → một tiếng ≈ **100 mm/tháng** |
| Từng năm | mưa năm > 1,1 × trung bình | round((r / tb − 1) × 12), từ 1 đến 4 |
| 15 ngày bão lũ (NASA POWER Daily) | mưa ngày ≥ 5 mm | round(√mưa × 0,75), từ 1 đến 9; âm lượng 0,12 + mưa/600 (tối đa 0,34) |

Ngày bão lũ dùng **căn bậc hai** để mưa 20 mm và 150 mm vẫn khác nhau mà không vượt quá 9 tiếng (9 tiếng từ khoảng 136 mm/ngày trở lên).

### 3.4. Gió, nắng, không khí, cháy

| Dữ liệu | Âm thanh | Công thức |
|---|---|---|
| Gió (km/h) | tiếng sóng/gió | bây giờ: từ 8 km/h, âm lượng gió/60 (0,12–0,6); ngày bão: từ 14 km/h, gió/55 (0,14–0,65) |
| Chỉ số UV | chiêng | từ UV 6: âm lượng 0,12 + (UV − 6) × 0,04 (tối đa 0,4) |
| Chất lượng không khí AQI | lách tách | từ AQI 100: âm lượng (AQI − 100)/150 (0,2–0,8), 8 tiếng |
| Điểm cháy theo tháng | lửa lách tách | tỉ lệ = √(số điểm / tháng nhiều nhất); 1 + 7 × tỉ lệ tiếng (1…8); âm lượng 0,18 + 0,62 × tỉ lệ. *Số cháy hiện là số minh hoạ theo mùa.* |

### 3.5. Thời gian → trái/phải

Mọi chuỗi theo thời gian đi **từ tai trái sang tai phải**:

```
pan = −0,85 + 1,7 × k / (n − 1)        // k = thứ tự điểm, n = số điểm; −1 trái hẳn, +1 phải hẳn
```

Mỗi nốt dài 220–380 ms tuỳ lượt nghe, nên 12 tháng nghe hết trong khoảng 9 giây.

### 3.6. Phát lại "lịch sử thời tiết" và "lịch sử thiên tai" (phối âm theo loại thời tiết)

File: `app/lib/features/history/history_player.dart`, `history_records.dart`. Đây là chế độ khác với các lượt đàn bầu ở trên: mỗi tháng (hoặc năm) được **phối âm** theo loại thời tiết chiếm ưu thế.

```
lệch = nhiệt độ tháng − trung bình của tháng đó
nóng = (nhiệt độ − 25) / 7 + 0,15 × lệch          (giới hạn 0…1)
lạnh = (18 − nhiệt độ) / 12 − 0,1 × lệch           (giới hạn 0…1)
mưa  = √(lượng mưa tháng / 420)                    (giới hạn 0…1; với năm: dùng mưa năm / 12)
chủ đạo = loại lớn nhất; nếu cả ba < 0,22 → "ôn hoà"
```

| Loại chủ đạo | Âm thanh | Âm lượng |
|---|---|---|
| Nóng | âm nền nắng; nếu nóng > 0,6 thêm round(nóng × 6) tiếng lách tách khô | chủ đạo: 0,16 + 0,2 × mức; loại phụ (mức > 0,25): 0,05 + 0,08 × mức |
| Lạnh | gió | như trên |
| Mưa | âm nền mưa + round(mưa × 10) giọt t'rưng; mưa > 0,85 thêm sấm | như trên |
| Ôn hoà | một nốt đàn bầu: x = (nhiệt độ − 5) / 30, nốt = toScale(0,2 + 0,6 × x) | 0,18 |

Mỗi tháng 1 có tiếng **mõ** làm mốc năm.

**Thiên tai suy ra từ số liệu tháng** (rồi phát âm riêng, kèm rung với loại nặng):

| Thiên tai | Điều kiện trong tháng | Âm thanh, rung |
|---|---|---|
| Mưa lớn bất thường | mưa ≥ 1,8 × trung bình **và** ≥ 250 mm | mưa + sấm |
| Hạn | trung bình ≥ 80 mm **và** mưa ≤ 25 % trung bình | gió khô |
| Nắng nóng | nóng hơn trung bình ≥ 1,5 °C **và** ≥ 28 °C | nắng |
| Rét đậm | lạnh hơn trung bình ≥ 1,8 °C **và** ≤ 15 °C | gió trầm |
| Bão, lũ, sạt lở, động đất, núi lửa, cháy (từ SEDAC GDIS, EONET, USGS) | theo sự kiện ghi nhận | gió + mưa + sấm, sóng, đất rung, lửa…; rung dồn dập 2–7 nhịp theo mức nặng |

Âm lượng thiên tai: 0,18 + 0,05 × mức nặng (thang 1…5).

### 3.7. Âm nền khi đọc thời tiết hiện tại

Trước khi đọc, app phát một âm nền theo mã thời tiết: **sấm** nếu có giông trong 2 giờ tới; **mưa** nếu đang mưa; **gió** nếu gió ≥ 25 km/h (hoặc ≥ 12 km/h khi không có loại khác); **nắng** nếu trời quang và UV ≥ 3. Có cảnh báo thiên tai gần người dùng thì phát **còi** kèm ba nhịp rung mạnh.

---

## 4. Địa hình (F3)

### 4.1. Độ cao → sáo trúc

**Toàn cầu và quét mặt cắt** (`terrain_scan/terrain_sense.dart`, `globe/terrain_data.dart`):

```
tone = √(min(1, độ cao / 8000))        (độ cao ≤ 0 → 0)
tần số = 2 × toScale(0,06 + 0,9 × tone)
```

Dùng căn bậc hai để **vùng thấp nghe rõ hơn**: phần lớn đất liền thấp dưới 2.000 m. Ngưỡng đổi nốt:

| Nốt | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Độ cao (m) | 0–22 | 22–139 | 139–357 | 357–675 | 675–1.094 | 1.094–1.614 | 1.614–2.235 | 2.235–2.957 | 2.957–3.779 | 3.779–4.702 |

Đồng bằng sông Hồng, sông Cửu Long ở nốt 1–2. Đà Lạt (~1.500 m) ở nốt 6. Phan Xi Păng (3.143 m) ở nốt 9.

**Quét mặt cắt:** mỗi lượt Bắc→Nam rồi Tây→Đông dài tối đa 8 giây. Lượt Tây→Đông thì âm lệch từ trái sang phải. Dưới mực nước biển thì sáo nhỏ lại và có tiếng sóng. Mỗi lần **sang dải độ cao khác** thì máy rung nhẹ.

**Bản đồ rê tay một nơi** (`globe/local_map.dart`), khoảng 2,4 × 2,4 km, dùng **thang tương đối của chính bản đồ**:

```
ex = (độ cao − thấp nhất) / max(1, cao nhất − thấp nhất)
tần số = 2 × toScale(0,1 + 0,8 × ex)
```

Một nốt ≈ (chênh cao của bản đồ) / 11,2. Ví dụ: bản đồ chênh 300 m thì một nốt ≈ **27 m**. Nếu vùng quá phẳng (chênh dưới 15 m), app nói rõ "vùng này khá bằng phẳng" để người dùng không hiểu nhầm các nốt.

Vị trí ngón tay → trái/phải: pan = x / bán kính bản đồ (tây trái, đông phải).

### 4.2. Độ dốc → rung

```
dz/dx = (cao phía đông − cao phía tây) / (2 × bước)
dz/dy = (cao phía bắc − cao phía nam) / (2 × bước)
độ dốc (độ) = atan(√(dz/dx² + dz/dy²)) × 180 / π
```

Bước lấy mẫu là 60 m trên bản đồ rê tay. Mức rung (`core/haptics.dart`):

| Độ dốc | < 2° | 2–6° | 6–12° | 12–22° | ≥ 22° |
|---|---|---|---|---|---|
| Rung | không | rất nhẹ (10 ms) | nhẹ (25 ms) | vừa (45 ms) | mạnh (80 ms) |

Trên bản web, chỉ điện thoại Android rung được.

### 4.3. Loại đất dưới ngón tay → âm nền

| Lớp phủ (MODIS / OpenStreetMap) | Âm thanh |
|---|---|
| Nước, sông, biển, bãi biển | tiếng sóng (âm lượng 0,18) |
| Rừng / công viên | t'rưng trầm 392 Hz / t'rưng cao 784 Hz |
| Khu dân cư | tiếng xe cộ (tối đa một lần mỗi 1,6 giây) |
| Ruộng | trống nhẹ |
| Đường | lách tách nhẹ |

---

## 5. Máy hát Trái Đất (đề #14)

Gồm hai bước: pipeline (`pipeline/build_eic.py`) đọc mỗi khung hình NASA SVS ra số, rồi app (`features/eic/eic_player.dart`) phát số đó.

### 5.1. Từ màu ra số (pipeline)

Mỗi khung hình được đổi thành một trường giá trị f(vĩ độ, kinh độ) trong khoảng 0…1 (NaN là không có số liệu). Cách đọc khác nhau theo từng bộ:

| Bộ | Cách đọc |
|---|---|
| Đèn đêm (Black Marble) | độ sáng vượt nền tối; chia cho phân vị 99,5 %, lấy căn bậc hai; chỉ tính trên đất liền |
| Khí CO₂ (GEOS) | video tổng hợp **trừ** video nền; chia cho phân vị 99,5 % |
| Nhiệt độ biển (ECCO2) | tự tìm thang màu trong video, rồi khớp mỗi điểm với màu gần nhất trên thang |
| Sét (LIS trên ISS) | lọc các điểm màu vàng của sét; gán tháng nhờ thời điểm tỉ lệ sét ở Bắc bán cầu vượt lên 0,5 (≈ giữa tháng 3), rồi gộp cùng tháng của 2017–2023 |
| Rừng (GEDI) | chiếu ngược quả cầu xoay về bản đồ phẳng bằng cách khớp đường bờ biển |

Từ trường giá trị f, pipeline tính 5 con số cho mỗi khung:

| Số | Ý nghĩa | Công thức |
|---|---|---|
| **v** | mức chung | trung bình f **có trọng số cos(vĩ độ)** (ô gần cực nhỏ hơn ô xích đạo) |
| **area** | diện tích | tỉ lệ diện tích (trọng số cos vĩ độ) có f > ngưỡng; ngưỡng: đèn 0,08 · CO₂ 0,10 · biển 0,50 · khác 0,12 |
| **cx** | hướng đông–tây | trung bình **trên vòng tròn kinh độ** của 10 % ô mạnh nhất, chia 180 → −1 (tây) … +1 (đông) |
| **vn** | vùng Việt Nam – Biển Đông | trung bình f trong khung Việt Nam – Biển Đông |
| **d** | mức thay đổi | trung bình \|f − f khung trước\| × 4, rồi đưa về 0…1 theo chính bộ đó |

v được nhân sao cho khung lớn nhất bằng 0,9. Cách nhân này **giữ nguyên tỉ lệ giữa các khung**, nên câu "tăng 17 %" vẫn đúng. Riêng bộ nhiệt độ biển giữ thang tuyệt đối.

Lưới rê tay của mỗi khung là **64 × 32 ô** (mỗi ô 5,6° × 5,6°, khoảng 600 km ở xích đạo). Mỗi ô lưu một byte 0…254, còn 255 là không có số liệu.

### 5.2. Từ số ra âm (app)

| Âm thanh | Theo số nào | Công thức |
|---|---|---|
| Cao độ giọng chính (đàn bầu; sáo với rừng) | v, hoặc vn với bộ biển | m = 0,1 + 0,85 × (giá trị − thấp nhất) / (cao nhất − thấp nhất), tính trên mọi khung của bộ → toScale(m); âm lượng 0,05 + 0,08 × m |
| Số tiếng gõ trong khung (t'rưng, trống, lách tách) | area | 0 nếu area ≤ 0,02; còn lại min(6, 1 + ⌊area × 8⌋) |
| Trái / phải | cx | pan = cx (tây trái, đông phải); các tiếng gõ lệch thêm ±0,25 cho rộng |
| Sấm / gió / mưa / sóng nổi lên | d | khi d > 0,6; âm lượng 0,1 + 0,15 × d |
| Chiêng nhỏ | vn | khi \|vn − vn khung trước\| > 0,06 |

Thời gian mỗi khung theo 5 mức tốc độ: 1.600 · 1.200 · **900** (mặc định) · 650 · 450 ms.

**Rê tay trên hình:**

```
giá trị t = byte / 254                      // tại ô dưới ngón tay
số thật = thấp + (cao − thấp) × t           // vd biển: 0…32 °C; rừng: 0…50 m
cao độ = toScale(t); pan = 2x − 1 (x là vị trí ngang)
mức đọc ra = ⌊t × 5⌋: rất thấp · thấp · vừa · cao · rất cao; đổi mức thì rung nhẹ
```

### 5.3. Độ chính xác của Máy hát

| Lớp | Sai số |
|---|---|
| Đọc từ màu (lớp 1) | **lớn nhất trong cả app.** Màu ảnh đã qua nén video và bảng màu của NASA. Nhiệt độ biển đọc từ hình có thể cao hơn thực tế 1–2 °C. Số liệu chỉ dùng để nghe xu hướng, so vùng, không dùng làm số đo. |
| Lưu lưới (lớp 2) | 1/254 khoảng giá trị: biển ≈ 0,13 °C, rừng ≈ 0,2 m. Nhỏ hơn rất nhiều so với sai số đọc màu. Ô lưới thô (~600 km) nên một ô gộp cả đất và biển gần bờ. |
| Nghe ra (lớp 3) | cao độ: 1/11,9 khoảng giá trị của bộ; số tiếng gõ: 7 mức; mức đọc khi rê tay: 5 mức. |

Các con số tóm tắt mà app đọc ra **tính từ v và vn**, không phải từ cao độ nốt: đèn đêm toàn cầu +17 % và Việt Nam +44 % (2012→2023), sét ở Việt Nam nhiều nhất tháng 5 còn toàn cầu tháng 7.

---

## 6. Tóm tắt độ phân giải "nghe ra" của từng âm

| Dữ liệu | Âm thanh | Một bước nghe ra ≈ | Con số chính xác |
|---|---|---|---|
| Nhiệt độ hiện tại, theo tháng, ngày bão | đàn bầu | 3,6 °C | đọc to sau tiếng đàn |
| Nhiệt độ qua các năm, GISTEMP | đàn bầu (thang tương đối) | khoảng chuỗi / 11,2–11,5 (GISTEMP ≈ 0,15 °C) | đọc to |
| Mưa tháng | t'rưng | 100 mm/tháng mỗi tiếng | đọc to |
| Mưa ngày bão | t'rưng | căn bậc hai, 9 mức | đọc to |
| Độ cao toàn cầu | sáo | 10 mức từ 0 đến ~4.700 m (dày ở vùng thấp) | đọc to khi dừng tay |
| Độ cao bản đồ rê tay | sáo (tương đối) | chênh cao bản đồ / 11,2 | đọc to khi dừng tay |
| Độ dốc | rung | 5 mức: 2°, 6°, 12°, 22° | đọc khi ≥ 8° |
| Hình NASA SVS | đàn bầu / sáo + tiếng gõ | 1/11,9 khoảng của bộ; 7 mức diện tích | đọc số tóm tắt và mức khi rê tay |

---

## 7. Kiểm thử

- `test/eic_jukebox_test.dart`:
  - kiểm tra cao độ trải từ 0,1 đến 0,95;
  - số tiếng gõ theo diện tích: 0 → 0, 0,1 → 1, 1 → 6;
  - đọc lưới, giá trị 255 là không có số liệu;
  - đổi byte ra số thật (vd 127/254 × 50 ≈ 25 m);
  - mọi bộ đã đóng gói có giá trị v, area, d, vn trong khoảng 0…1.
- `test/f3_terrain_sense_test.dart`, `test/touch_grid_test.dart`: độ dốc, mức rung, độ cao theo lưới.
- Sai số nén dữ liệu khí hậu (0,058 °C, 1,485 mm/tháng) đo trong pipeline bằng cách so lại từng ô với dữ liệu gốc. Xem `docs/HUONG_DAN_DU_LIEU_NASA.md`, mục 5.

**Chưa đo:** người dùng thật phân biệt được bao nhiêu nốt, bao nhiêu mức rung. Các con số "nghe ra" ở trên là **giới hạn do công thức** (số nốt, số mức), không phải kết quả thử với người dùng. Đây là một phần của kế hoạch thử nghiệm.


---

## 8. Mỗi âm thanh dùng ở đâu trong app

| Phần | Người dùng nói / bấm | Âm thanh phát ra | Code (hàm) |
|---|---|---|---|
| **F1 · Thời tiết** | "thời tiết Hà Nội", nút Hà Nội / Đà Nẵng / TP.HCM, "bản tin sáng", "nghe nhạc" | âm nền theo trời (3.7) → đàn bầu nhiệt độ luyến sang cảm nhận, t'rưng theo khả năng mưa, gió, chiêng UV, lách tách AQI (3.1, 3.3, 3.4) | `globe_page._goAndRead`, `_bulletin` → `WorldSound.now` |
| | "24 giờ tới", "từng giờ" | mỗi giờ một nốt đàn bầu, trái → phải, t'rưng khi có mưa | `WorldSound.hours` |
| | "tháng 7 năm 2024 ở Huế", "năm 2020 ở Đà Nẵng", "khí hậu Huế" (12 tháng bình thường) | 12 nốt đàn bầu (thang tuyệt đối), t'rưng theo mưa tháng | `_climate` → `WorldSound.months` |
| | "khí hậu Hà Nội nhiều năm", "Hà Nội xưa và nay" | mỗi năm một nốt (thang tương đối), t'rưng khi mưa năm cao | `_climate`, `_history` → `WorldSound.years` |
| | "ngày 15 tháng 10 năm 2020 ở Huế" | một nốt đàn bầu luyến từ thấp nhất lên cao nhất trong ngày, gió, t'rưng theo mưa | `_day` → `WorldSound.day` |
| | "lịch sử thời tiết Huế 3 năm qua", "lịch sử thiên tai Quảng Ngãi" | phối âm nóng / lạnh / mưa / ôn hoà từng tháng, mõ đầu năm, âm và rung thiên tai (3.6) | `HistoryPlayer` |
| | "bão Yagi", "lũ miền Trung 2020" | 15 ngày: đàn bầu nhiệt độ, sóng gió, t'rưng dồn theo √mưa | `_handleNasaNormalizedQuery` → `WorldSound.eventDays` |
| | "cháy rừng Tây Nguyên" | 12 tháng lửa lách tách theo √(số điểm cháy) *(số minh hoạ)* | `WorldSound.fireHotspots` |
| | "Trái Đất nóng lên bao nhiêu" | 146 năm GISTEMP, ~36 nốt trong 9 giây, mõ mỗi 20 năm | `WorldSound.gistempYears` |
| | "có bão không", cảnh báo gần người dùng | còi + ba nhịp rung mạnh | `_disasters`, `_alertNear` |
| **F3 · Địa lý** | "rê tay khám phá Đà Lạt", "rê tay quanh tôi" | sáo theo độ cao (thang của bản đồ), rung theo độ dốc, âm nền theo loại đất, rung theo loại đất (nước, rừng, khu dân cư) | `local_map.dart` |
| | "chạm địa hình" (rê tay trên quả địa cầu) | sáo theo độ cao (thang toàn cầu √), rung theo độ dốc, tiếng xe ở khu đông dân | `globe_page._terrainFinger` |
| | "quét mặt cắt địa hình Đà Lạt" | sáo theo độ cao Bắc→Nam rồi Tây→Đông (trái → phải), sóng dưới biển, rung khi đổi dải độ cao | `terrain_scan_view.dart` |
| | "đi dọc Việt Nam", "địa hình từ Hà Nội đến Sa Pa", "núi cao nhất", "Sa Pa cao bao nhiêu" | chuỗi nốt đàn bầu theo độ cao (cùng công thức √, thấp hơn sáo một quãng tám), sóng ở biển | `_terrainPath`, `_terrainTone` |
| **F2 · Vũ trụ** | "khám phá vũ trụ", "kể về Sao Hỏa", chọn một hành tinh | âm đặc trưng riêng của từng thiên thể (10 âm tổng hợp) — **không ánh xạ số liệu** | `audio.planet` |
| | "âm thanh thật của NASA" | bản ghi thật (Sputnik, Apollo 11…) — **không phải sonification** | `audio.playRecording` |
| | trò chơi | chuông mừng kỷ lục, âm đúng / sai | `audio.planet`, `earcon` |
| **Máy hát (#14)** | "máy hát Trái Đất", "nghe sét"… | mục 5 | `eic_player.dart` |
| **Chung** | mọi lệnh | **ding** khi nghe được lệnh, âm báo lỗi, âm "đang nghĩ" khi chờ AI, tiếng tách khi chạm nút | `audio.earcon` |

Hai chỗ **không** phải chuyển dữ liệu thành âm (chỉ là âm minh hoạ): âm riêng của các hành tinh và bản ghi âm thật của NASA.

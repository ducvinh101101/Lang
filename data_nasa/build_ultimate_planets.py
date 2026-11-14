import os
import json

OUTPUT_JSON = r"D:\NASA\assets\content\planets_extended.json"

# Kho dữ liệu bách khoa toàn thư 8 hành tinh (NSSDCA + NASA Space Place)
ULTIMATE_PLANETS_DB = [
    {
        "id": "mercury",
        "name_vi": "Sao Thủy",
        "name_en": "Mercury",
        "1_position_and_distance": {
            "order_from_sun": 1,
            "avg_distance_sun_km": "57.9 triệu km",
            "distance_to_earth_km": "77 triệu km - 222 triệu km",
            "orbital_period": "88 ngày Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 4879,
            "mass_10_24_kg": 0.330,
            "density_kg_m3": 5429,
            "earth_comparison": "Chỉ lớn hơn Mặt Trăng một chút, bằng 1/3 kích thước Trái Đất."
        },
        "3_motion": {
            "day_length": "59 ngày Trái Đất",
            "year_length": "88 ngày Trái Đất",
            "axial_tilt": "0.034 độ",
            "orbit_shape": "Hình elip rất dẹt (độ lệch tâm lớn nhất trong các hành tinh)."
        },
        "4_internal_structure": {
            "core": "Lõi kim loại khổng lồ (chủ yếu là sắt), chiếm tới 85% bán kính hành tinh.",
            "mantle": "Lớp phủ silicat mỏng.",
            "crust": "Lớp vỏ đá rắn chắc.",
            "composition_type": "Hành tinh đất đá (Terrestrial)."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "Chi chít hố va chạm giống Mặt Trăng, có những vách núi đứt gãy (lobate scarps) dài hàng trăm dặm do hành tinh đang nguội và co lại.",
            "geological_activity": "Đã ngừng hoạt động địa chất, không có núi lửa phun trào hiện tại."
        },
        "6_atmosphere": {
            "composition": "Không có khí quyển thực sự, chỉ có một lớp ngoại quyển (exosphere) rất mỏng chứa O, Na, H, He, K.",
            "pressure": "Gần như bằng 0 (chân không).",
            "weather": "Không có mây, gió hay bão.",
            "greenhouse_effect": "Hoàn toàn không có."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": 167,
            "min_max_temp_c": "Từ -180°C (ban đêm) đến 430°C (ban ngày).",
            "temperature_variance": "Biên độ nhiệt lớn nhất Hệ Mặt Trời (chênh lệch hơn 600°C).",
            "water_status": "Có băng nước ẩn sâu trong các miệng hố va chạm vĩnh cửu ở hai cực, nơi ánh sáng Mặt Trời không bao giờ chiếu tới."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Rất yếu, chỉ bằng 1% từ trường Trái Đất.",
            "radiation_belts": "Không có vành đai bức xạ rõ rệt.",
            "solar_wind_protection": "Yếu, gió Mặt Trời thường xuyên xé toạc và tương tác trực tiếp với bề mặt tạo ra các cơn bão từ nhỏ."
        },
        "9_moons_and_rings": {
            "moon_count": 0,
            "notable_moons": "Không có",
            "has_rings": False,
            "moon_influence": "Không có"
        },
        "10_special_phenomena": [
            "Hành tinh đang co ngót lại (shrinking) do lõi sắt đang nguội dần đi.",
            "Mặt Trời mọc lùi: Do quỹ đạo elip dẹt và tốc độ quay chậm, ở một số nơi trên Sao Thủy, Mặt Trời mọc lên, dừng lại, đi lùi xuống đường chân trời rồi lại mọc lên lần nữa.",
            "Năm ngắn hơn ngày: Khái niệm 'Ngày Mặt Trời' (từ bình minh đến bình minh) kéo dài tới 176 ngày Trái Đất, tương đương 2 'Năm' của Sao Thủy."
        ]
    },
    {
        "id": "venus",
        "name_vi": "Sao Kim",
        "name_en": "Venus",
        "1_position_and_distance": {
            "order_from_sun": 2,
            "avg_distance_sun_km": "108.2 triệu km",
            "distance_to_earth_km": "Gần nhất khoảng 38 triệu km (Hành tinh gần Trái Đất nhất).",
            "orbital_period": "225 ngày Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 12104,
            "mass_10_24_kg": 4.87,
            "density_kg_m3": 5243,
            "earth_comparison": "Được coi là 'chị em sinh đôi' của Trái Đất vì kích thước và khối lượng gần như tương đương (nhỏ hơn khoảng 5%)."
        },
        "3_motion": {
            "day_length": "243 ngày Trái Đất (tự quay rất chậm).",
            "year_length": "225 ngày Trái Đất.",
            "axial_tilt": "177.3 độ (Quay ngược chiều).",
            "orbit_shape": "Gần như là một vòng tròn hoàn hảo."
        },
        "4_internal_structure": {
            "core": "Lõi kim loại (sắt) có thể là lõi lỏng một phần.",
            "mantle": "Lớp phủ silicat dày.",
            "crust": "Lớp vỏ đá, chủ yếu là đá basalt.",
            "composition_type": "Hành tinh đất đá (Terrestrial)."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "Bề mặt khô cằn, có hàng ngàn ngọn núi lửa lớn nhỏ, những cánh đồng dung nham rộng lớn và núi non đứt gãy.",
            "geological_activity": "Có bằng chứng về hoạt động núi lửa gần đây. Không có kiến tạo mảng (plate tectonics) giống Trái Đất."
        },
        "6_atmosphere": {
            "composition": "Dày đặc, 96.5% Carbon dioxide (CO2), 3.5% Nitơ (N2).",
            "pressure": "Cực lớn, gấp 92 lần áp suất khí quyển Trái Đất (tương đương áp lực dưới độ sâu 1km dưới đại dương).",
            "weather": "Mây làm từ axit sulfuric (H2SO4) ăn mòn. Gió trên tầng mây cao di chuyển với vận tốc siêu bão (cuồng phong).",
            "greenhouse_effect": "Hiệu ứng nhà kính mất kiểm soát (runaway greenhouse effect) khủng khiếp nhất Hệ Mặt Trời."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": 464,
            "min_max_temp_c": "Luôn duy trì ở mức ~460°C - 470°C bất kể ngày hay đêm.",
            "temperature_variance": "Sự chênh lệch nhiệt độ ngày đêm gần như bằng không do lớp khí quyển dày đặc giữ nhiệt cực tốt.",
            "water_status": "Hoàn toàn không có nước lỏng. Bất kỳ giọt nước nào cũng sẽ bị đun sôi và bốc hơi ngay lập tức."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": False,
            "strength": "Không có từ trường nội tại do tốc độ tự quay quá chậm.",
            "radiation_belts": "Không có.",
            "solar_wind_protection": "Được bảo vệ một phần bởi tầng điện ly (ionosphere) tương tác với gió Mặt Trời."
        },
        "9_moons_and_rings": {
            "moon_count": 0,
            "notable_moons": "Không có",
            "has_rings": False,
            "moon_influence": "Không có"
        },
        "10_special_phenomena": [
            "Hành tinh nóng nhất Hệ Mặt Trời, nóng hơn cả Sao Thủy dù nằm xa Mặt Trời hơn.",
            "Quay ngược chiều (Retrograde rotation): Mặt Trời mọc ở đằng Tây và lặn ở đằng Đông.",
            "Nghiền nát tàu vũ trụ: Áp suất và nhiệt độ quá lớn khiến các tàu thăm dò của Liên Xô (Venera) chỉ tồn tại được vài chục phút trên bề mặt trước khi bị nấu chảy và nghiền nát."
        ]
    },
    {
        "id": "earth",
        "name_vi": "Trái Đất",
        "name_en": "Earth",
        "1_position_and_distance": {
            "order_from_sun": 3,
            "avg_distance_sun_km": "149.6 triệu km (1 AU).",
            "distance_to_earth_km": "0",
            "orbital_period": "365.25 ngày"
        },
        "2_size_and_mass": {
            "diameter_km": 12756,
            "mass_10_24_kg": 5.97,
            "density_kg_m3": 5514,
            "earth_comparison": "Hành tinh đất đá lớn nhất và đặc nhất trong Hệ Mặt Trời."
        },
        "3_motion": {
            "day_length": "23 giờ 56 phút",
            "year_length": "365.25 ngày",
            "axial_tilt": "23.4 độ",
            "orbit_shape": "Hình elip gần tròn."
        },
        "4_internal_structure": {
            "core": "Lõi trong rắn (sắt, niken) và lõi ngoài lỏng.",
            "mantle": "Lớp phủ silicat đặc quánh, có sự đối lưu nhiệt.",
            "crust": "Lớp vỏ mỏng, phân mảnh thành các mảng kiến tạo.",
            "composition_type": "Hành tinh đất đá (Terrestrial)."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "71% bề mặt là đại dương nước lỏng. Bề mặt đất liền đa dạng: núi, thung lũng, hẻm núi, đồng bằng.",
            "geological_activity": "Hành tinh duy nhất có hoạt động kiến tạo mảng (plate tectonics) rõ ràng, tạo ra động đất và núi lửa liên tục."
        },
        "6_atmosphere": {
            "composition": "78% Nitơ (N2), 21% Oxy (O2), 1% Argon và các khí khác.",
            "pressure": "1 atm ở mực nước biển.",
            "weather": "Vô cùng phức tạp với chu trình nước, mây, bão, tuyết, sấm sét.",
            "greenhouse_effect": "Hiệu ứng nhà kính tự nhiên giúp giữ ấm, nhưng đang bị gia tăng do hoạt động của con người."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": 15,
            "min_max_temp_c": "Từ -89°C (Nam Cực) đến 56°C (Thung lũng Chết).",
            "temperature_variance": "Ổn định, chênh lệch ngày đêm ôn hòa.",
            "water_status": "Hành tinh duy nhất có nước tồn tại ở cả 3 trạng thái: lỏng, rắn (băng) và khí (hơi nước) trên bề mặt."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Mạnh nhất trong số các hành tinh đất đá, tạo ra bởi lõi sắt lỏng xoay tròn (Dynamo effect).",
            "radiation_belts": "Vành đai bức xạ Van Allen.",
            "solar_wind_protection": "Lớp từ quyển đóng vai trò như lá chắn hoàn hảo chống lại bức xạ Mặt Trời và tia vũ trụ chết chóc."
        },
        "9_moons_and_rings": {
            "moon_count": 1,
            "notable_moons": "Mặt Trăng (The Moon) - vệ tinh tự nhiên rất lớn so với kích thước hành tinh chủ.",
            "has_rings": False,
            "moon_influence": "Tạo ra thủy triều, ổn định trục quay của Trái Đất giúp khí hậu duy trì ổn định."
        },
        "10_special_phenomena": [
            "Sự sống: Nơi duy nhất trong vũ trụ cho đến nay được biết là có tồn tại sự sống.",
            "Cực quang (Aurora): Ánh sáng rực rỡ ở hai cực do gió Mặt Trời va chạm với từ trường và khí quyển.",
            "Vùng Goldilocks: Nằm ở vị trí hoàn hảo, không quá nóng, không quá lạnh để nước lỏng tồn tại."
        ]
    },
    {
        "id": "mars",
        "name_vi": "Sao Hỏa",
        "name_en": "Mars",
        "1_position_and_distance": {
            "order_from_sun": 4,
            "avg_distance_sun_km": "228 triệu km",
            "distance_to_earth_km": "Tối thiểu 54.6 triệu km, tối đa 401 triệu km.",
            "orbital_period": "687 ngày Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 6792,
            "mass_10_24_kg": 0.642,
            "density_kg_m3": 3934,
            "earth_comparison": "Chỉ lớn bằng một nửa Trái Đất, khối lượng bằng 1/10 Trái Đất."
        },
        "3_motion": {
            "day_length": "24 giờ 37 phút (gọi là một Sol).",
            "year_length": "687 ngày Trái Đất.",
            "axial_tilt": "25.2 độ",
            "orbit_shape": "Hình elip khá dẹt."
        },
        "4_internal_structure": {
            "core": "Lõi sắt, niken và lưu huỳnh (có thể đã đông đặc một phần).",
            "mantle": "Lớp phủ silicat mỏng hơn Trái Đất.",
            "crust": "Lớp vỏ đá, đặc biệt chứa nhiều Sắt oxit (rỉ sét).",
            "composition_type": "Hành tinh đất đá (Terrestrial)."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "Sở hữu ngọn núi lửa cao nhất Hệ Mặt Trời (Olympus Mons - cao gấp 3 lần Everest) và hệ thống hẻm núi lớn nhất (Valles Marineris - dài 4000km).",
            "geological_activity": "Ít hoạt động địa chất, có các cơn 'động đất Sao Hỏa' (marsquakes) nhẹ do hành tinh đang co lại."
        },
        "6_atmosphere": {
            "composition": "Rất mỏng, 95% Carbon dioxide (CO2), 3% Nitơ, 1.6% Argon.",
            "pressure": "Chỉ bằng 1% áp suất khí quyển Trái Đất.",
            "weather": "Có mây bụi, gió cuốn cát (dust devils), và những trận bão bụi khổng lồ có thể bao trùm toàn bộ hành tinh trong nhiều tháng.",
            "greenhouse_effect": "Rất yếu do khí quyển quá mỏng."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -65,
            "min_max_temp_c": "Từ -153°C (hai cực mùa đông) đến 20°C (xích đạo mùa hè).",
            "temperature_variance": "Chênh lệch ngày đêm lớn vì khí quyển mỏng không giữ được nhiệt.",
            "water_status": "Có băng nước ở hai cực. Từng có nước lỏng chảy thành sông, hồ trên bề mặt vào hàng tỷ năm trước."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": False,
            "strength": "Không có từ trường toàn cầu (global magnetic field) như Trái Đất.",
            "radiation_belts": "Không.",
            "solar_wind_protection": "Bị tước đoạt khí quyển và nước nguyên thủy do gió Mặt Trời thổi bay vì không có lá chắn từ trường."
        },
        "9_moons_and_rings": {
            "moon_count": 2,
            "notable_moons": "Phobos (kích thước lớn hơn, di chuyển rất nhanh và đang rơi dần xuống Sao Hỏa) và Deimos (rất nhỏ).",
            "has_rings": False,
            "moon_influence": "Không đáng kể do khối lượng quá nhỏ."
        },
        "10_special_phenomena": [
            "Hành tinh Đỏ: Bề mặt bị bao phủ bởi lớp rỉ sét (sắt oxit) giống như một công trường sắt cũ kỹ.",
            "Hoàng hôn màu xanh lam: Trái ngược với Trái Đất, bụi trong khí quyển Sao Hỏa tán xạ ánh sáng khiến bầu trời lúc hoàng hôn có màu xanh lam nhạt.",
            "Bão bụi quy mô toàn cầu: Những cơn bão bụi ở đây có thể đủ lớn để che khuất hoàn toàn bề mặt hành tinh khỏi các kính viễn vọng."
        ]
    },
    {
        "id": "jupiter",
        "name_vi": "Sao Mộc",
        "name_en": "Jupiter",
        "1_position_and_distance": {
            "order_from_sun": 5,
            "avg_distance_sun_km": "778.5 triệu km (5.2 AU).",
            "distance_to_earth_km": "Khoảng 588 - 968 triệu km.",
            "orbital_period": "11.8 năm Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 142984,
            "mass_10_24_kg": 1898,
            "density_kg_m3": 1326,
            "earth_comparison": "Lớn nhất Hệ Mặt Trời. Khối lượng gấp 318 lần Trái Đất và gấp hơn 2.5 lần tổng khối lượng tất cả các hành tinh khác cộng lại."
        },
        "3_motion": {
            "day_length": "9 giờ 55 phút (Ngày ngắn nhất trong Hệ Mặt Trời).",
            "year_length": "11.8 năm.",
            "axial_tilt": "3.1 độ",
            "orbit_shape": "Gần tròn."
        },
        "4_internal_structure": {
            "core": "Có thể là lõi rắn (đá và băng) kích thước bằng Trái Đất.",
            "mantle": "Đại dương hydro kim loại lỏng (metallic hydrogen) khổng lồ sâu hàng chục ngàn dặm.",
            "crust": "Không có lớp vỏ phân định rõ ràng.",
            "composition_type": "Hành tinh khí khổng lồ (Gas Giant)."
        },
        "5_surface_and_terrain": {
            "solid_surface": False,
            "features": "Không có bề mặt rắn, khí quyển đặc dần thành chất lỏng cạn kiệt đáy.",
            "geological_activity": "Không có địa chất kiểu bề mặt rắn."
        },
        "6_atmosphere": {
            "composition": "90% Hydro (H2), 10% Heli (He), lẫn amoniac, metan.",
            "pressure": "Tăng lên hàng triệu atm khi đi sâu vào trong.",
            "weather": "Các dải mây đầy màu sắc (zones và belts) quay ngược chiều nhau. Bão tố khủng khiếp, sét đánh mạnh gấp ngàn lần Trái Đất.",
            "greenhouse_effect": "Bị lu mờ bởi nhiệt lượng nội tại của chính hành tinh."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -110,
            "min_max_temp_c": "-145°C ở đỉnh mây, nhưng lõi hành tinh có thể nóng tới 24,000°C.",
            "temperature_variance": "Sinh nhiệt từ bên trong, bức xạ nhiệt ra không gian nhiều hơn nhiệt nhận từ Mặt Trời.",
            "water_status": "Rất ít nước, chủ yếu dạng hơi trong khí quyển."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Mạnh nhất Hệ Mặt Trời (gấp 14-20.000 lần Trái Đất).",
            "radiation_belts": "Bức xạ ion hóa cực kỳ chết chóc, có thể làm hỏng mọi thiết bị điện tử nếu không bọc giáp chì.",
            "solar_wind_protection": "Từ quyển khổng lồ kéo dài tới tận quỹ đạo của Sao Thổ."
        },
        "9_moons_and_rings": {
            "moon_count": 95,
            "notable_moons": "Ganymede (lớn nhất Hệ Mặt Trời, có từ trường riêng), Io (núi lửa phun trào liên tục), Europa (đại dương ngầm chứa sự sống tiềm năng), Callisto.",
            "has_rings": True,
            "moon_influence": "Hệ thống vệ tinh giống như một Thái dương hệ thu nhỏ. Lực hấp dẫn của Sao Mộc bẻ cong quỹ đạo tiểu hành tinh, bảo vệ Trái Đất."
        },
        "10_special_phenomena": [
            "Vết Đỏ Lớn (Great Red Spot): Một siêu bão cuồng phong rộng hơn Trái Đất, đã cuộn xoáy suốt hơn 300 năm qua.",
            "Đại dương kim loại: Áp suất cực lớn ép Hydro biến thành dạng lỏng dẫn điện (hydro kim loại), tạo ra từ trường khổng lồ.",
            "Lực hấp dẫn vệ sĩ: Sao Mộc thường được coi là 'máy hút bụi' của Hệ Mặt Trời, hút hoặc đánh bật các sao chổi nguy hiểm có thể đâm vào Trái Đất."
        ]
    },
    {
        "id": "saturn",
        "name_vi": "Sao Thổ",
        "name_en": "Saturn",
        "1_position_and_distance": {
            "order_from_sun": 6,
            "avg_distance_sun_km": "1.4 tỷ km (9.5 AU).",
            "distance_to_earth_km": "Khoảng 1.2 tỷ km.",
            "orbital_period": "29.4 năm Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 120536,
            "mass_10_24_kg": 568,
            "density_kg_m3": 687,
            "earth_comparison": "Lớn thứ hai sau Sao Mộc. Nhẹ nổi: Hành tinh duy nhất nhẹ hơn nước (tỷ trọng < 1000 kg/m3)."
        },
        "3_motion": {
            "day_length": "10 giờ 33 phút",
            "year_length": "29.4 năm.",
            "axial_tilt": "26.7 độ",
            "orbit_shape": "Gần tròn."
        },
        "4_internal_structure": {
            "core": "Lõi đá và băng nhỏ.",
            "mantle": "Lớp phủ hydro kim loại lỏng.",
            "crust": "Không có bề mặt rắn.",
            "composition_type": "Hành tinh khí khổng lồ (Gas Giant)."
        },
        "5_surface_and_terrain": {
            "solid_surface": False,
            "features": "Chỉ là những lớp mây và khí ngày càng đặc khi đi sâu vào trung tâm.",
            "geological_activity": "Không có."
        },
        "6_atmosphere": {
            "composition": "96% Hydro, 4% Heli.",
            "pressure": "Tăng dần không giới hạn vào sâu bên trong.",
            "weather": "Gió siêu tốc trên xích đạo đạt tới 1,800 km/h.",
            "greenhouse_effect": "Sinh nhiệt từ bên trong tương tự Sao Mộc."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -140,
            "min_max_temp_c": "-175°C ở đỉnh mây.",
            "temperature_variance": "Rất lạnh ở lớp ngoài.",
            "water_status": "Hơi nước rất ít, nhưng vành đai và các mặt trăng của nó là những khối băng nước khổng lồ."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Yếu hơn Sao Mộc nhưng mạnh hơn Trái Đất nhiều lần.",
            "radiation_belts": "Có, nhưng trục từ trường trùng khớp hoàn hảo với trục quay (rất kỳ lạ).",
            "solar_wind_protection": "Tạo ra vùng từ quyển lớn."
        },
        "9_moons_and_rings": {
            "moon_count": 146,
            "notable_moons": "Titan (có bầu khí quyển dày đặc và hồ metan lỏng), Enceladus (phun trào mạch nước ngầm từ đại dương dưới băng).",
            "has_rings": True,
            "moon_influence": "Các 'Mặt trăng mục đồng' (shepherd moons) giúp giữ cho vành đai Sao Thổ vào hàng ngũ rõ ràng."
        },
        "10_special_phenomena": [
            "Hệ thống vành đai lộng lẫy nhất: Được tạo thành từ hàng tỷ cục băng và đá, trải rộng hàng trăm ngàn km nhưng chỉ dày khoảng 10 mét.",
            "Siêu bão lục giác (Hexagon storm): Một cơn bão xoáy khổng lồ có hình lục giác hoàn hảo nằm ở cực Bắc của hành tinh.",
            "Nổi trên nước: Nếu bạn có một bồn tắm đủ lớn để chứa Sao Thổ, hành tinh này sẽ nổi bồng bềnh vì mật độ của nó nhẹ hơn nước."
        ]
    },
    {
        "id": "uranus",
        "name_vi": "Sao Thiên Vương",
        "name_en": "Uranus",
        "1_position_and_distance": {
            "order_from_sun": 7,
            "avg_distance_sun_km": "2.9 tỷ km (19.2 AU).",
            "distance_to_earth_km": "Khoảng 2.6 - 3.1 tỷ km.",
            "orbital_period": "84 năm Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 51118,
            "mass_10_24_kg": 86.8,
            "density_kg_m3": 1270,
            "earth_comparison": "Lớn gấp 4 lần Trái Đất về đường kính. Khối lượng bằng 14.5 lần Trái Đất."
        },
        "3_motion": {
            "day_length": "17 giờ 14 phút (Quay lùi giống Sao Kim).",
            "year_length": "84 năm.",
            "axial_tilt": "97.7 độ (Lăn tròn trên quỹ đạo).",
            "orbit_shape": "Khá tròn."
        },
        "4_internal_structure": {
            "core": "Lõi đá nhỏ silicat/sắt.",
            "mantle": "Lớp manti băng nóng chứa 'chất lỏng siêu tới hạn' gồm nước, amoniac, metan.",
            "crust": "Không có bề mặt rắn.",
            "composition_type": "Hành tinh băng khổng lồ (Ice Giant)."
        },
        "5_surface_and_terrain": {
            "solid_surface": False,
            "features": "Bầu khí quyển hòa quyện trực tiếp vào một đại dương băng chất lỏng vô tận.",
            "geological_activity": "Không."
        },
        "6_atmosphere": {
            "composition": "82% Hydro, 15% Heli, 2% Metan (CH4).",
            "pressure": "Cao ở các lớp sâu.",
            "weather": "Trông rất tĩnh lặng màu xanh lơ, nhưng bên trong có những cơn gió giật tốc độ 900 km/h.",
            "greenhouse_effect": "Rất lạnh."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -195,
            "min_max_temp_c": "Nhiệt độ tối thiểu ở tầng bình lưu giảm xuống -224°C (Nơi lạnh nhất Hệ Mặt Trời).",
            "temperature_variance": "Do trục nghiêng, một cực sẽ chìm trong bóng tối 42 năm liên tục và đóng băng sâu sắc.",
            "water_status": "Chứa một lượng khổng lồ nước dạng băng nóng chảy (chất lỏng nén) trong lớp manti."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Trung bình.",
            "radiation_belts": "Có, nhưng từ trường cực kỳ dị thường, bị lệch hẳn khỏi tâm hành tinh và nghiêng 59 độ so với trục quay.",
            "solar_wind_protection": "Hoạt động không ổn định."
        },
        "9_moons_and_rings": {
            "moon_count": 28,
            "notable_moons": "Miranda, Titania, Oberon (đặt tên theo các nhân vật trong kịch của Shakespeare và thơ của Alexander Pope).",
            "has_rings": True,
            "moon_influence": "Hệ thống vành đai hẹp, tối màu, quay vuông góc với mặt phẳng Hệ Mặt Trời."
        },
        "10_special_phenomena": [
            "Hành tinh lăn tròn: Do trục nghiêng gần 98 độ, nó quay nghiêng trên mặt phẳng quỹ đạo như một quả bóng đang lăn thay vì xoay như con quay.",
            "Mùi trứng thối: Đám mây trên thượng tầng khí quyển chứa nhiều Hydro sulfide (H2S), mang mùi đặc trưng của trứng thối.",
            "Màu xanh lục ngọc mờ ảo: Khí metan trong thượng tầng hấp thụ ánh sáng đỏ, khiến hành tinh có màu xanh lam-lục đặc trưng."
        ]
    },
    {
        "id": "neptune",
        "name_vi": "Sao Hải Vương",
        "name_en": "Neptune",
        "1_position_and_distance": {
            "order_from_sun": 8,
            "avg_distance_sun_km": "4.5 tỷ km (30.1 AU).",
            "distance_to_earth_km": "Khoảng 4.3 - 4.7 tỷ km.",
            "orbital_period": "165 năm Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 49528,
            "mass_10_24_kg": 102,
            "density_kg_m3": 1638,
            "earth_comparison": "Kích thước tương tự Sao Thiên Vương (đường kính nhỏ hơn chút) nhưng đặc và nặng hơn."
        },
        "3_motion": {
            "day_length": "16 giờ 6 phút.",
            "year_length": "165 năm.",
            "axial_tilt": "28.3 độ",
            "orbit_shape": "Gần tròn."
        },
        "4_internal_structure": {
            "core": "Lõi rắn cỡ bằng Trái Đất (đá, sắt).",
            "mantle": "Lớp manti băng nóng chất lỏng đặc quánh (nước, metan, amoniac).",
            "crust": "Không có bề mặt rắn.",
            "composition_type": "Hành tinh băng khổng lồ (Ice Giant)."
        },
        "5_surface_and_terrain": {
            "solid_surface": False,
            "features": "Đại dương chất lỏng siêu áp suất thay thế cho bề mặt đất.",
            "geological_activity": "Không có."
        },
        "6_atmosphere": {
            "composition": "80% Hydro, 19% Heli, lượng nhỏ Metan.",
            "pressure": "Cực lớn khi đi sâu vào manti.",
            "weather": "Sở hữu những cơn gió nhanh nhất Hệ Mặt Trời (hơn 2,000 km/h) xé toạc các đám mây metan trắng đóng băng.",
            "greenhouse_effect": "Bức xạ nhiệt nội tại mạnh gấp 2.6 lần lượng năng lượng nhận được từ Mặt Trời mờ nhạt."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -200,
            "min_max_temp_c": "-214°C ở đỉnh mây.",
            "temperature_variance": "Lạnh thấu xương, nhưng lõi lại cực kỳ nóng (~7000°C).",
            "water_status": "Giống Thiên Vương, sở hữu lượng nước 'băng nóng' (hot ice) khổng lồ sâu bên dưới."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Gấp 27 lần Trái Đất.",
            "radiation_belts": "Từ trường bất thường, lệch khỏi tâm hành tinh và nghiêng 47 độ so với trục quay.",
            "solar_wind_protection": "Có tương tác phức tạp tạo cực quang thưa thớt."
        },
        "9_moons_and_rings": {
            "moon_count": 16,
            "notable_moons": "Triton (mặt trăng lớn nhất, quay ngược chiều, có mạch nước phun nitơ lỏng, dự kiến sẽ bị lực hấp dẫn xé nát trong tương lai).",
            "has_rings": True,
            "moon_influence": "Vành đai mờ nhạt dạng cung (arcs) đặc lưa thưa."
        },
        "10_special_phenomena": [
            "Mưa kim cương (Diamond rain): Ở sâu trong lớp manti, áp suất và nhiệt độ cao ép carbon (từ metan) kết tinh thành kim cương, rơi chìm xuống lõi hành tinh.",
            "Vết tối lớn (Great Dark Spot): Những cơn bão hố xoáy kích thước bằng Trái Đất xuất hiện rồi lại biến mất bí ẩn.",
            "Cơn gió siêu thanh: Khí quyển lạnh lẽo nhưng lại tạo ra sức gió đứt gãy vượt rào cản âm thanh, bí ẩn nhiệt động lực học lớn nhất của nó."
        ]
    }
    # ... (Tiếp nối sau ngoặc nhọn của Sao Hải Vương / Neptune) ...
    ,
    {
        "id": "pluto",
        "name_vi": "Sao Diêm Vương",
        "name_en": "Pluto",
        "1_position_and_distance": {
            "order_from_sun": "Hành tinh lùn (Vành đai Kuiper)",
            "avg_distance_sun_km": "5.9 tỷ km (39 AU).",
            "distance_to_earth_km": "Khoảng 4.2 - 7.5 tỷ km.",
            "orbital_period": "248 năm Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 2376,
            "mass_10_24_kg": 0.0130,
            "density_kg_m3": 1850,
            "earth_comparison": "Rất nhỏ, chỉ rộng bằng 2/3 bề ngang Mặt Trăng của Trái Đất."
        },
        "3_motion": {
            "day_length": "153 giờ (6.4 ngày Trái Đất).",
            "year_length": "248 năm.",
            "axial_tilt": "122.5 độ (Cũng quay lùi và nghiêng hẳn sang một bên).",
            "orbit_shape": "Hình elip cực dẹt, có lúc lấn vào quỹ đạo của Sao Hải Vương."
        },
        "4_internal_structure": {
            "core": "Lõi đá.",
            "mantle": "Lớp phủ nước đóng băng.",
            "crust": "Lớp vỏ băng nitơ và băng metan.",
            "composition_type": "Hành tinh lùn (Dwarf Planet) / Thiên thể băng đá."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "Sở hữu Tombaugh Regio - một sông băng khổng lồ hình trái tim làm từ nitơ, carbon monoxide và metan.",
            "geological_activity": "Có bằng chứng về hoạt động địa chất gần đây (vài triệu năm) và núi lửa phun băng (cryovolcanoes)."
        },
        "6_atmosphere": {
            "composition": "Nitơ, metan, carbon monoxide.",
            "pressure": "Cực kỳ loãng (chỉ bằng 1/100,000 Trái Đất).",
            "weather": "Khí quyển giãn nở khi Pluto đến gần Mặt Trời và đóng băng sụp đổ xuống bề mặt khi nó đi xa Mặt Trời.",
            "greenhouse_effect": "Hoàn toàn không có."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -225,
            "min_max_temp_c": "Dao động từ -223°C đến -233°C.",
            "temperature_variance": "Rất lạnh và tối. Mặt Trời nhìn từ Pluto chỉ giống như một ngôi sao rất sáng.",
            "water_status": "Có thể có một đại dương nước lỏng ẩn sâu dưới lớp vỏ băng."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": False,
            "strength": "Không có.",
            "radiation_belts": "Không.",
            "solar_wind_protection": "Không có, khí quyển liên tục bị gió Mặt Trời thổi bay vào không gian."
        },
        "9_moons_and_rings": {
            "moon_count": 5,
            "notable_moons": "Charon (to bằng nửa Pluto, tạo thành 'Hệ hành tinh đôi'), Nix, Hydra, Kerberos, Styx.",
            "has_rings": False,
            "moon_influence": "Charon và Pluto khóa thủy triều lẫn nhau, luôn hướng một mặt về phía nhau như hai người đang khiêu vũ."
        },
        "10_special_phenomena": [
            "Bị giáng cấp: Từng là hành tinh thứ 9, bị Liên đoàn Thiên văn Quốc tế (IAU) giáng cấp thành 'Hành tinh lùn' vào năm 2006 do không 'dọn dẹp' được quỹ đạo của mình.",
            "Bầu trời xanh: Tàu New Horizons phát hiện khí quyển Pluto cũng tán xạ ánh sáng tạo ra một lớp sương mù màu xanh lam tuyệt đẹp.",
            "Tuyết màu đỏ: Bề mặt có những khu vực phủ tuyết tholins (hợp chất hữu cơ phức tạp) mang màu đỏ thẫm."
        ]
    },
    {
        "id": "sun",
        "name_vi": "Mặt Trời",
        "name_en": "The Sun",
        "1_position_and_distance": {
            "order_from_sun": 0,
            "avg_distance_sun_km": "0",
            "distance_to_earth_km": "149.6 triệu km (1 AU).",
            "orbital_period": "230 triệu năm (Quay quanh tâm Ngân Hà)."
        },
        "2_size_and_mass": {
            "diameter_km": 1392700,
            "mass_10_24_kg": 1989000,
            "density_kg_m3": 1410,
            "earth_comparison": "Khối lượng gấp 330,000 lần Trái Đất, chứa 99.8% toàn bộ khối lượng của cả Hệ Mặt Trời. Có thể nhét 1.3 triệu Trái Đất vào bên trong."
        },
        "3_motion": {
            "day_length": "Khoảng 25 ngày Trái Đất ở xích đạo, 35 ngày ở hai cực (Quay vi sai).",
            "year_length": "N/A",
            "axial_tilt": "7.25 độ",
            "orbit_shape": "N/A"
        },
        "4_internal_structure": {
            "core": "Lõi phản ứng nhiệt hạch (tạo ra toàn bộ năng lượng).",
            "mantle": "Vùng bức xạ (Radiative zone) và vùng đối lưu (Convective zone).",
            "crust": "N/A",
            "composition_type": "Ngôi sao lùn vàng (Yellow Dwarf - G-type main-sequence star)."
        },
        "5_surface_and_terrain": {
            "solid_surface": False,
            "features": "Bề mặt quang quyển (Photosphere) liên tục sôi sục như nồi cháo do các hạt siêu nóng trồi lên từ vùng đối lưu.",
            "geological_activity": "N/A"
        },
        "6_atmosphere": {
            "composition": "73% Hydro, 25% Heli, còn lại là carbon, oxy, sắt.",
            "pressure": "N/A",
            "weather": "N/A",
            "greenhouse_effect": "N/A"
        },
        "7_temperature_and_environment": {
            "avg_temp_c": 5500,
            "min_max_temp_c": "5,500°C ở bề mặt. Lên tới 15 triệu °C ở vùng lõi.",
            "temperature_variance": "Lớp vành nhật hoa (Corona - khí quyển ngoài cùng) nóng một cách nghịch lý, lên tới 1 - 3 triệu °C.",
            "water_status": "Không thể tồn tại."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": True,
            "strength": "Cực kỳ mạnh mẽ và hỗn loạn.",
            "radiation_belts": "N/A",
            "solar_wind_protection": "Nguồn phát ra gió Mặt Trời bao trùm toàn bộ thái dương hệ tạo thành Nhật quyển (Heliosphere)."
        },
        "9_moons_and_rings": {
            "moon_count": 0,
            "notable_moons": "N/A",
            "has_rings": False,
            "moon_influence": "Hút toàn bộ 8 hành tinh và hàng triệu tiểu hành tinh xoay quanh nó."
        },
        "10_special_phenomena": [
            "Vết đen Mặt Trời (Sunspots): Những vùng từ trường hoạt động cực mạnh ngăn cản nhiệt nổi lên, tạo ra các chấm đen lạnh hơn phần còn lại của bề mặt.",
            "Bão Mặt Trời (Solar Flares): Những vụ nổ bức xạ khổng lồ có thể phóng ra các đám mây hạt (CME) gây nhiễu sóng vệ tinh và lưới điện trên Trái Đất.",
            "Vòng đời: Sẽ tiếp tục cháy sáng khoảng 5 tỷ năm nữa trước khi phồng to thành sao khổng lồ đỏ, nuốt chửng Sao Thủy, Sao Kim và có thể cả Trái Đất."
        ]
    },
    {
        "id": "moon",
        "name_vi": "Mặt Trăng",
        "name_en": "The Moon",
        "1_position_and_distance": {
            "order_from_sun": "Vệ tinh của Trái Đất",
            "avg_distance_sun_km": "149.6 triệu km",
            "distance_to_earth_km": "384,400 km.",
            "orbital_period": "27.3 ngày Trái Đất"
        },
        "2_size_and_mass": {
            "diameter_km": 3474,
            "mass_10_24_kg": 0.073,
            "density_kg_m3": 3344,
            "earth_comparison": "Đường kính bằng 1/4 Trái Đất. Trọng lực chỉ bằng 1/6 Trái Đất."
        },
        "3_motion": {
            "day_length": "27.3 ngày Trái Đất.",
            "year_length": "N/A",
            "axial_tilt": "1.54 độ (rất thẳng, không có các mùa).",
            "orbit_shape": "Elip quanh Trái Đất."
        },
        "4_internal_structure": {
            "core": "Lõi sắt nhỏ rắn ở trong, lỏng ở ngoài.",
            "mantle": "Lớp phủ đá cứng một phần.",
            "crust": "Lớp vỏ đá, đất mặt (regolith) mịn màng sắc lẹm.",
            "composition_type": "Vệ tinh tự nhiên (Terrestrial Moon)."
        },
        "5_surface_and_terrain": {
            "solid_surface": True,
            "features": "Bao phủ bởi hàng triệu hố thiên thạch, các vùng 'biển' (Maria) màu sẫm thực chất là dung nham đã đông cứng cổ đại.",
            "geological_activity": "Từng có núi lửa phun trào 3-4 tỷ năm trước, hiện tại đã chết về mặt địa chất (dù vẫn có các trận 'động đất mặt trăng' nhỏ do lực hấp dẫn từ Trái Đất)."
        },
        "6_atmosphere": {
            "composition": "Cực kỳ loãng (ngoại quyển), chủ yếu là argon, heli, neon, natri.",
            "pressure": "Gần như bằng 0 (chân không).",
            "weather": "Không có âm thanh, không có gió, cờ do phi hành gia cắm không tự bay bay.",
            "greenhouse_effect": "Không có."
        },
        "7_temperature_and_environment": {
            "avg_temp_c": -20,
            "min_max_temp_c": "Từ 127°C (chỗ có nắng) đến -173°C (chỗ khuất bóng).",
            "temperature_variance": "Biên độ nhiệt cực gắt ngay lập tức khi bước từ vùng sáng sang vùng tối do không có không khí phân bổ nhiệt.",
            "water_status": "Có băng nước dồi dào trong các hố va chạm vĩnh cửu ở cực Nam."
        },
        "8_magnetic_field_and_radiation": {
            "has_magnetic_field": False,
            "strength": "Không có từ trường toàn cầu (đã biến mất hàng tỷ năm trước).",
            "radiation_belts": "Không.",
            "solar_wind_protection": "Không có, phơi mình hoàn toàn trước bức xạ Mặt Trời."
        },
        "9_moons_and_rings": {
            "moon_count": 0,
            "notable_moons": "N/A",
            "has_rings": False,
            "moon_influence": "Khóa thủy triều với Trái Đất (Tidal locking) nên luôn chỉ hướng duy nhất một mặt về phía chúng ta."
        },
        "10_special_phenomena": [
            "Vùng tối của Mặt Trăng (Far side): Thực ra không tối, nó vẫn nhận được ánh sáng Mặt Trời nhưng Trái Đất không bao giờ nhìn thấy được mặt này.",
            "Sự hình thành bạo lực: Giả thuyết hàng đầu cho rằng nó được tạo ra khi một thiên thể kích thước bằng Sao Hỏa (Theia) đâm vào Trái Đất nguyên thủy.",
            "Khoảng cách hoàn hảo: Mặt Trăng nhỏ hơn Mặt Trời 400 lần nhưng lại nằm gần Trái Đất hơn 400 lần, khiến chúng có kích thước biểu kiến bằng nhau trên bầu trời, tạo ra hiện tượng Nhật thực toàn phần hoàn hảo."
        ]
    }
]

def build_extended_planets():
    os.makedirs(os.path.dirname(OUTPUT_JSON), exist_ok=True)
    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(ULTIMATE_PLANETS_DB, f, ensure_ascii=False, indent=4)
    print(f"✅ Đã đóng gói thành công {len(ULTIMATE_PLANETS_DB)} hành tinh cực chi tiết ra: {OUTPUT_JSON}")

if __name__ == "__main__":
    build_extended_planets()
"""Sự thật thú vị về từng thiên thể (F2) — nguồn: NASA Science Solar System (science.nasa.gov/<thiên thể>/facts)
và NSSDCA Planetary Fact Sheet. Mỗi mục: (vi, en). App chọn ngẫu nhiên một mục khi người dùng nói
"sự thật thú vị về <hành tinh>", và dùng làm nguồn cho trò đố vui / câu đố "Tôi là ai".
"""
from __future__ import annotations

FUN_FACTS: dict[str, list[tuple[str, str]]] = {
    "sun": [
        ("Mặt Trời chiếm khoảng 99,8 phần trăm khối lượng của cả Hệ Mặt Trời.", "The Sun holds about 99.8 percent of all the mass in the Solar System."),
        ("Khoảng 1,3 triệu Trái Đất mới lấp đầy được Mặt Trời.", "About 1.3 million Earths could fit inside the Sun."),
        ("Ánh sáng rời bề mặt Mặt Trời mất khoảng 8 phút 20 giây mới tới Trái Đất.", "Light leaving the surface of the Sun takes about 8 minutes 20 seconds to reach Earth."),
        ("Lõi Mặt Trời nóng khoảng 15 triệu độ C.", "The core of the Sun is about 15 million degrees Celsius."),
        ("Mặt Trời đã khoảng 4,6 tỉ năm tuổi và mới đi được nửa đời.", "The Sun is about 4.6 billion years old, roughly halfway through its life."),
    ],
    "mercury": [
        ("Sao Thủy là hành tinh nhỏ nhất, chỉ lớn hơn Mặt Trăng một chút.", "Mercury is the smallest planet, only a little bigger than the Moon."),
        ("Dù gần Mặt Trời nhất, Sao Thủy không phải hành tinh nóng nhất; Sao Kim mới nóng nhất.", "Although closest to the Sun, Mercury is not the hottest planet; Venus is."),
        ("Sao Thủy gần như không có không khí giữ nhiệt: ban ngày 430 độ C, ban đêm âm 180 độ C.", "With almost no air to hold heat, Mercury swings from 430 °C by day to minus 180 °C at night."),
        ("Tàu MESSENGER của NASA tìm thấy băng nước trong các hố luôn chìm trong bóng tối ở hai cực Sao Thủy.", "NASA's MESSENGER found water ice in permanently shadowed craters at the poles of Mercury."),
        ("Từ lúc mặt trời mọc đến lần mọc sau trên Sao Thủy mất 176 ngày Trái Đất, bằng hai năm của nó.", "From one sunrise to the next on Mercury takes 176 Earth days, two of its years."),
    ],
    "venus": [
        ("Sao Kim là hành tinh nóng nhất, khoảng 465 độ C, đủ làm chảy chì.", "Venus is the hottest planet, about 465 °C, hot enough to melt lead."),
        ("Sao Kim tự quay ngược chiều, nên mặt trời mọc ở hướng tây.", "Venus spins backwards, so the Sun rises in the west."),
        ("Sao Kim tự quay một vòng mất 243 ngày, lâu hơn cả một năm của nó là 225 ngày.", "Venus takes 243 days to spin once, longer than its 225-day year."),
        ("Áp suất trên mặt Sao Kim gấp khoảng 90 lần Trái Đất, như lặn sâu gần một ki-lô-mét dưới biển.", "Air pressure on Venus is about 90 times that of Earth, like being nearly a kilometre under the sea."),
        ("Mây trên Sao Kim chứa a-xít sun-phu-ric.", "The clouds of Venus contain sulfuric acid."),
    ],
    "earth": [
        ("Khoảng 71 phần trăm bề mặt Trái Đất là nước; đây là hành tinh duy nhất ta biết có nước lỏng trên mặt.", "About 71 percent of Earth is covered by water; it is the only planet known to have liquid water on its surface."),
        ("Không khí Trái Đất có khoảng 78 phần trăm khí ni-tơ và 21 phần trăm khí ô-xy.", "The air on Earth is about 78 percent nitrogen and 21 percent oxygen."),
        ("Trái Đất là hành tinh đặc nhất trong Hệ Mặt Trời.", "Earth is the densest planet in the Solar System."),
        ("Từ trường Trái Đất che chắn gió Mặt Trời và tạo ra cực quang.", "The magnetic field of Earth shields us from the solar wind and creates the auroras."),
        ("Trái Đất quay chậm dần rất ít, nên ngày dài thêm khoảng 1,7 phần nghìn giây mỗi thế kỷ.", "The spin of Earth is slowing very slightly, adding about 1.7 milliseconds to the day each century."),
    ],
    "moon": [
        ("Mặt Trăng đang rời xa Trái Đất khoảng 3,8 xăng-ti-mét mỗi năm.", "The Moon is moving away from Earth by about 3.8 centimetres a year."),
        ("Mặt Trăng luôn quay một mặt về phía Trái Đất.", "The Moon always shows the same face to Earth."),
        ("Từ năm 1969 đến 1972, 12 người đã đi bộ trên Mặt Trăng.", "Between 1969 and 1972, twelve people walked on the Moon."),
        ("Mặt Trăng không có gió, nên dấu chân phi hành gia có thể còn đó hàng triệu năm.", "With no wind on the Moon, the footprints of astronauts could last for millions of years."),
        ("Lực hút của Mặt Trăng tạo ra thủy triều lên xuống ở biển Trái Đất.", "The gravity of the Moon raises the tides in the oceans of Earth."),
    ],
    "mars": [
        ("Núi lửa Olympus trên Sao Hỏa cao khoảng 22 ki-lô-mét, gấp hai lần rưỡi đỉnh Everest.", "Olympus Mons on Mars is about 22 kilometres tall, two and a half times Mount Everest."),
        ("Hẻm núi Valles Marineris trên Sao Hỏa dài khoảng 4.000 ki-lô-mét, hơn gấp đôi chiều dài Việt Nam.", "The Valles Marineris canyon on Mars is about 4,000 kilometres long."),
        ("Hoàng hôn trên Sao Hỏa có màu xanh lam.", "Sunsets on Mars look blue."),
        ("Sao Hỏa có màu đỏ vì đất đá chứa nhiều gỉ sắt.", "Mars looks red because its soil is full of rusty iron."),
        ("Năm 2021, trực thăng Ingenuity của NASA bay trên Sao Hỏa, chuyến bay có động cơ đầu tiên trên một hành tinh khác.", "In 2021 the NASA Ingenuity helicopter made the first powered flight on another planet, on Mars."),
    ],
    "jupiter": [
        ("Vết Đỏ Lớn trên Sao Mộc là một cơn bão to hơn cả Trái Đất, đã thổi hơn 150 năm.", "The Great Red Spot on Jupiter is a storm bigger than Earth that has raged for over 150 years."),
        ("Hơn 1.300 Trái Đất mới lấp đầy được Sao Mộc.", "More than 1,300 Earths could fit inside Jupiter."),
        ("Sao Mộc có ngày ngắn nhất Hệ Mặt Trời, chỉ khoảng 10 giờ.", "Jupiter has the shortest day in the Solar System, about 10 hours."),
        ("Ganymede, mặt trăng của Sao Mộc, là mặt trăng lớn nhất Hệ Mặt Trời, to hơn cả Sao Thủy.", "Ganymede, a moon of Jupiter, is the largest moon in the Solar System, bigger than Mercury."),
        ("Sao Mộc cũng có vành đai mờ, được tàu Voyager 1 phát hiện năm 1979.", "Jupiter has faint rings too, discovered by Voyager 1 in 1979."),
    ],
    "saturn": [
        ("Sao Thổ nhẹ hơn nước; nếu có bồn đủ lớn, nó sẽ nổi.", "Saturn is less dense than water; in a big enough bathtub it would float."),
        ("Vành đai Sao Thổ rộng hàng trăm nghìn ki-lô-mét nhưng phần lớn chỉ dày khoảng 10 mét.", "The rings of Saturn stretch hundreds of thousands of kilometres yet are mostly only about 10 metres thick."),
        ("Titan, mặt trăng của Sao Thổ, có bầu khí dày và những hồ khí mê-tan lỏng.", "Titan, a moon of Saturn, has a thick atmosphere and lakes of liquid methane."),
        ("Ở cực bắc Sao Thổ có một cơn bão hình lục giác khổng lồ.", "A giant six-sided storm swirls over the north pole of Saturn."),
        ("Mặt trăng Enceladus của Sao Thổ phun những cột hơi nước từ đại dương ngầm dưới lớp băng.", "Enceladus, a moon of Saturn, sprays jets of water from an ocean under its ice."),
    ],
    "uranus": [
        ("Sao Thiên Vương nghiêng khoảng 98 độ, như lăn tròn quanh Mặt Trời.", "Uranus is tilted about 98 degrees, so it rolls around the Sun on its side."),
        ("Mỗi cực Sao Thiên Vương có khoảng 42 năm liền ban ngày, rồi 42 năm liền đêm tối.", "Each pole of Uranus gets about 42 years of daylight, then 42 years of darkness."),
        ("Sao Thiên Vương là hành tinh đầu tiên được tìm ra bằng kính thiên văn, năm 1781.", "Uranus was the first planet found with a telescope, in 1781."),
        ("Sao Thiên Vương có bầu khí lạnh nhất trong các hành tinh, tới âm 224 độ C.", "Uranus has the coldest atmosphere of any planet, down to minus 224 °C."),
        ("Giống Sao Kim, Sao Thiên Vương tự quay ngược chiều.", "Like Venus, Uranus spins backwards."),
    ],
    "neptune": [
        ("Gió trên Sao Hải Vương mạnh tới khoảng 2.000 ki-lô-mét một giờ, mạnh nhất Hệ Mặt Trời.", "Winds on Neptune reach about 2,000 kilometres per hour, the fastest in the Solar System."),
        ("Sao Hải Vương được tìm ra năm 1846 nhờ tính toán toán học trước khi nhìn thấy.", "Neptune was found in 1846 by mathematics before anyone saw it."),
        ("Một năm trên Sao Hải Vương dài 165 năm Trái Đất; năm 2011 nó mới đi hết vòng đầu tiên kể từ khi được tìm ra.", "A year on Neptune lasts 165 Earth years; it finished its first orbit since discovery in 2011."),
        ("Triton, mặt trăng lớn nhất của Sao Hải Vương, quay ngược chiều và có mạch phun khí ni-tơ.", "Triton, the largest moon of Neptune, orbits backwards and has nitrogen geysers."),
        ("Chỉ một tàu vũ trụ từng ghé Sao Hải Vương: Voyager 2, năm 1989.", "Only one spacecraft has visited Neptune: Voyager 2, in 1989."),
    ],
}

FACT_SOURCE = {
    "sun": "https://science.nasa.gov/sun/facts/",
    "moon": "https://science.nasa.gov/moon/facts/",
}


def fact_source(body_id: str) -> str:
    return FACT_SOURCE.get(body_id, f"https://science.nasa.gov/{body_id}/facts/")

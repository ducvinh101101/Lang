"""F2 · Bản ghi âm THẬT của NASA (NASA Historical Sounds) → app/assets/sounds/nasa/ + catalog.json.

Nguồn file: data_nasa/assets/content/nasa/*.mp3 (+ credits.csv). Lời giới thiệu song ngữ viết theo thông tin NASA
đã công bố về từng bản ghi (https://www.nasa.gov/historical-sounds/). Thời lượng đo bằng cách đọc khung MP3.
"""
from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path

# MPEG audio: bảng bitrate (kbps) và tần số lấy mẫu
_BR = {
    (1, 1): [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
    (1, 2): [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    (1, 3): [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    (2, 1): [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    (2, 2): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
    (2, 3): [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}
_SR = {1: [44100, 48000, 32000], 2: [22050, 24000, 16000], 25: [11025, 12000, 8000]}


def mp3_duration(data: bytes) -> float:
    """Thời lượng (giây) = tổng số mẫu của mọi khung MPEG / tần số lấy mẫu. Bỏ qua thẻ ID3v2 ở đầu."""
    i = 0
    if data[:3] == b"ID3" and len(data) > 10:
        size = (data[6] & 0x7F) << 21 | (data[7] & 0x7F) << 14 | (data[8] & 0x7F) << 7 | (data[9] & 0x7F)
        i = 10 + size
    total = 0.0
    n = len(data)
    while i + 4 <= n:
        b1, b2, b3 = data[i + 1], data[i + 2], data[i + 3]
        if data[i] != 0xFF or (b1 & 0xE0) != 0xE0:
            i += 1
            continue
        ver_bits, layer_bits = (b1 >> 3) & 3, (b1 >> 1) & 3
        br_idx, sr_idx, pad = (b2 >> 4) & 0xF, (b2 >> 2) & 3, (b2 >> 1) & 1
        if ver_bits == 1 or layer_bits == 0 or br_idx in (0, 15) or sr_idx == 3:
            i += 1
            continue
        ver = {3: 1, 2: 2, 0: 25}[ver_bits]
        layer = 4 - layer_bits
        br = _BR[(1 if ver == 1 else 2, layer)][br_idx] * 1000
        sr = _SR[ver][sr_idx]
        if layer == 1:
            size, samples = (12 * br // sr + pad) * 4, 384
        else:
            samples = 1152 if (layer == 2 or ver == 1) else 576
            size = samples // 8 * br // sr + pad
        if size <= 4:
            i += 1
            continue
        total += samples / sr
        i += size
        _ = b3
    return round(total, 2)


# id → lời giới thiệu (viết theo NASA Historical Sounds), từ khoá nhận lệnh (đã bỏ dấu), thiên thể liên quan
INFO = {
    "sputnik_beep": dict(
        title_vi="Tiếng bíp của vệ tinh Sputnik 1", title_en="Sputnik 1 beep",
        intro_vi="Năm 1957, Sputnik 1 là vệ tinh nhân tạo đầu tiên bay quanh Trái Đất. Nó phát tín hiệu vô tuyến bíp bíp, "
                 "người ở mặt đất bắt được bằng máy thu thanh, mở đầu thời đại vũ trụ.",
        intro_en="In 1957 Sputnik 1 became the first artificial satellite to orbit Earth. Its radio beeps could be picked up "
                 "on the ground and marked the start of the space age.",
        keys=["sputnik", "xput nich", "ve tinh dau tien", "first satellite"], body=3),
    "apollo11_step": dict(
        title_vi="Apollo 11: một bước nhỏ của con người", title_en="Apollo 11: one small step",
        intro_vi="Ngày 20 tháng 7 năm 1969, phi hành gia Neil Armstrong của Apollo 11 bước xuống Mặt Trăng và nói: "
                 "đó là một bước nhỏ của một người, nhưng là bước nhảy vĩ đại của nhân loại.",
        intro_en="On 20 July 1969 Apollo 11 astronaut Neil Armstrong stepped onto the Moon and said: that's one small step "
                 "for man, one giant leap for mankind.",
        keys=["apollo 11", "apollo muoi mot", "armstrong", "buoc chan len mat trang", "small step"], body=4),
    "apollo13_problem": dict(
        title_vi="Apollo 13: Houston, chúng tôi gặp sự cố", title_en="Apollo 13: Houston, we've had a problem",
        intro_vi="Năm 1970, một bình ô-xy trên tàu Apollo 13 phát nổ trên đường tới Mặt Trăng. Câu báo về trung tâm Houston "
                 "trở nên nổi tiếng; cả ba phi hành gia đã trở về Trái Đất an toàn.",
        intro_en="In 1970 an oxygen tank exploded on Apollo 13 on the way to the Moon. The call to Houston became famous, "
                 "and all three astronauts returned safely.",
        keys=["apollo 13", "apollo muoi ba", "houston", "we have a problem"], body=4),
    "saturn_radio": dict(
        title_vi="Sóng vô tuyến của Sao Thổ (tàu Cassini)", title_en="Saturn radio emissions (Cassini)",
        intro_vi="Tàu Cassini ghi lại sóng vô tuyến phát ra từ Sao Thổ, gắn với cực quang của hành tinh này. "
                 "Sóng vô tuyến không nghe được bằng tai, nên NASA đổi chúng thành âm thanh.",
        intro_en="The Cassini spacecraft recorded radio emissions from Saturn, linked to its auroras. "
                 "We cannot hear radio waves, so NASA turned them into sound.",
        keys=["song vo tuyen sao tho", "radio sao tho", "cassini", "saturn radio", "tieng hat sao tho"], body=7),
    "enceladus_sound": dict(
        title_vi="Âm thanh từ mặt trăng Enceladus (tàu Cassini)", title_en="Sound from Enceladus (Cassini)",
        intro_vi="Tàu Cassini bay qua Enceladus, mặt trăng băng của Sao Thổ có những cột hơi nước phun ra từ đại dương ngầm. "
                 "Tín hiệu thiết bị ghi được khi bay qua đã được NASA chuyển thành âm thanh.",
        intro_en="Cassini flew past Enceladus, an icy moon of Saturn that sprays water from an ocean under its ice. "
                 "NASA turned the signals its instruments recorded into sound.",
        keys=["enceladus", "en xe la dut", "mach nuoc ngam"], body=7),
    "jupiter_lightning": dict(
        title_vi="Sấm sét trên Sao Mộc (tàu Voyager)", title_en="Lightning on Jupiter (Voyager)",
        intro_vi="Tàu Voyager ghi được sóng vô tuyến do sét trên Sao Mộc tạo ra. Khi đổi thành âm thanh, chúng nghe như "
                 "tiếng huýt trượt xuống, nên các nhà khoa học gọi là tiếng huýt sáo.",
        intro_en="Voyager recorded radio waves made by lightning on Jupiter. Turned into sound they slide downward like "
                 "whistles, so scientists call them whistlers.",
        keys=["set sao moc", "sam set sao moc", "tieng sam sao moc", "tia set sao moc", "jupiter lightning", "voyager sao moc"], body=6),
    "interstellar_plasma": dict(
        title_vi="Sóng plasma ngoài vùng ảnh hưởng của Mặt Trời (tàu Voyager 1)", title_en="Interstellar plasma (Voyager 1)",
        intro_vi="Tàu Voyager 1 đã vượt ra khỏi bong bóng gió Mặt Trời vào không gian giữa các vì sao. Thiết bị sóng plasma "
                 "ghi được dao động của lớp khí loãng nhiễm điện ở đó; tiếng cao dần cho biết khí càng lúc càng dày.",
        intro_en="Voyager 1 has left the bubble of the solar wind for interstellar space. Its plasma wave instrument recorded "
                 "the ringing of the thin charged gas there; the rising pitch shows the gas getting denser.",
        keys=["lien sao", "giua cac vi sao", "voyager", "plasma", "interstellar"], body=0),
    "juno_morse": dict(
        title_vi="Lời chào HI bằng mã Morse gửi tàu Juno", title_en="HI in Morse code to Juno",
        intro_vi="Năm 2013, khi tàu Juno bay ngang Trái Đất để lấy đà tới Sao Mộc, những người chơi vô tuyến nghiệp dư khắp "
                 "thế giới cùng gửi chữ HI bằng mã Morse, và tàu Juno đã nhận được.",
        intro_en="In 2013, as Juno swung past Earth on its way to Jupiter, radio amateurs around the world sent HI in Morse code, "
                 "and Juno received it.",
        keys=["juno", "morse", "ma mooc", "ma moc xo"], body=6),
    "kepler_light_curve": dict(
        title_vi="Ánh sáng các ngôi sao thành âm thanh (kính Kepler)", title_en="Starlight as sound (Kepler)",
        intro_vi="Kính thiên văn Kepler đo độ sáng của các ngôi sao rất đều đặn. Độ sáng lên xuống được đổi thành âm thanh: "
                 "nhịp dao động của ngôi sao cho biết bên trong nó ra sao.",
        intro_en="The Kepler telescope measured the brightness of stars very precisely. The ups and downs were turned into sound; "
                 "a star's rhythm tells us about its insides.",
        keys=["kepler", "duong cong anh sang", "anh sang ngoi sao", "light curve"], body=0),
    "stardust_tempel1": dict(
        title_vi="Bụi sao chổi Tempel 1 va vào tàu Stardust", title_en="Comet Tempel 1 dust hitting Stardust",
        intro_vi="Năm 2011, tàu Stardust bay qua sao chổi Tempel 1. Máy đo bụi ghi lại từng hạt bụi va vào tấm chắn của tàu, "
                 "mỗi tiếng lách tách là một cú va.",
        intro_en="In 2011 the Stardust spacecraft flew past comet Tempel 1. Its dust detector recorded each grain hitting the "
                 "shield; every crackle is one impact.",
        keys=["stardust", "tempel", "sao choi", "bui sao choi", "comet"], body=0),
}


# Trò "Đố âm thanh NASA" (theo khung kịch bản của data_nasa: dẫn chuyện → nghe bản ghi thật → câu hỏi 2 lựa chọn →
# đúng / sai / hết giờ). Đáp án đúng luôn đứng đầu ở đây; app xáo thứ tự khi hỏi.
QUIZ = {
    "sputnik_beep": ("Sputnik 1 là gì?", "What was Sputnik 1?",
                     ["Vệ tinh nhân tạo đầu tiên của loài người", "Con tàu đưa người lên Mặt Trăng"],
                     ["The first artificial satellite", "The ship that took people to the Moon"]),
    "apollo11_step": ("Câu nói này vang lên ở đâu?", "Where was this said?",
                      ["Trên Mặt Trăng", "Trên Sao Hỏa"], ["On the Moon", "On Mars"]),
    "apollo13_problem": ("Sau sự cố, ba phi hành gia Apollo 13 ra sao?", "What happened to the Apollo 13 crew?",
                         ["Trở về Trái Đất an toàn", "Ở lại trên Mặt Trăng"], ["They returned safely to Earth", "They stayed on the Moon"]),
    "saturn_radio": ("Tàu vũ trụ nào ghi được sóng vô tuyến này của Sao Thổ?", "Which spacecraft recorded these Saturn radio waves?",
                     ["Tàu Cassini", "Tàu Apollo 11"], ["Cassini", "Apollo 11"]),
    "enceladus_sound": ("Enceladus là mặt trăng của hành tinh nào?", "Enceladus is a moon of which planet?",
                        ["Sao Thổ", "Sao Hỏa"], ["Saturn", "Mars"]),
    "jupiter_lightning": ("Tiếng huýt trượt xuống này do đâu mà có?", "What makes these falling whistles?",
                          ["Sét trên Sao Mộc", "Gió trên Sao Kim"], ["Lightning on Jupiter", "Wind on Venus"]),
    "interstellar_plasma": ("Tàu Voyager 1 ghi âm thanh này ở đâu?", "Where did Voyager 1 record this?",
                            ["Ngoài vùng gió Mặt Trời, giữa các vì sao", "Trên mặt đất Sao Hỏa"],
                            ["Beyond the solar wind, between the stars", "On the ground on Mars"]),
    "juno_morse": ("Người trên Trái Đất gửi chữ gì cho tàu Juno?", "What did people on Earth send to Juno?",
                   ["Chữ HI, lời chào", "Chữ SOS, lời kêu cứu"], ["HI, a greeting", "SOS, a call for help"]),
    "kepler_light_curve": ("Kính thiên văn Kepler đo điều gì của các ngôi sao?", "What did the Kepler telescope measure in stars?",
                           ["Độ sáng lên xuống của chúng", "Cân nặng của chúng bằng một cái cân"],
                           ["How their brightness rises and falls", "Their weight, using scales"]),
    "stardust_tempel1": ("Mỗi tiếng lách tách trong bản ghi là gì?", "What is each crackle in the recording?",
                         ["Một hạt bụi sao chổi va vào tàu", "Một tia sét trên sao chổi"],
                         ["A grain of comet dust hitting the spacecraft", "A lightning bolt on the comet"]),
}


def build(data_nasa: Path, app: Path) -> dict:
    src = data_nasa / "assets" / "content"
    out_dir = app / "assets" / "sounds" / "nasa"
    out_dir.mkdir(parents=True, exist_ok=True)
    credits = {}
    with open(src / "credits.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            credits[Path(row["file"]).stem] = row
    items = []
    for sid, info in INFO.items():
        fp = src / "nasa" / f"{sid}.mp3"
        if not fp.exists():
            continue
        shutil.copyfile(fp, out_dir / fp.name)
        c = credits.get(sid, {})
        items.append({
            "id": sid,
            "file": fp.name,
            "duration_s": mp3_duration(fp.read_bytes()),
            "title_vi": info["title_vi"],
            "title_en": info["title_en"],
            "intro_vi": info["intro_vi"],
            "intro_en": info["intro_en"],
            "keys": info["keys"],
            "body": info["body"],
            "credit": c.get("ghi_cong", "NASA"),
            "source_name": c.get("nguon", "NASA Historical Sounds"),
            "source_url": c.get("link", "https://www.nasa.gov/historical-sounds/"),
            "audio_kind": "nasa_recording",
            "quiz": {"q_vi": QUIZ[sid][0], "q_en": QUIZ[sid][1], "opts_vi": QUIZ[sid][2], "opts_en": QUIZ[sid][3], "answer": 0},
        })
    catalog = {
        "data_card": {
            "dataset": "NASA Historical Sounds",
            "provider": "NASA",
            "url": "https://www.nasa.gov/historical-sounds/",
            "processing": "Giữ nguyên file mp3 của NASA; thời lượng đo bằng cách đọc khung MP3; lời giới thiệu song ngữ viết lại cho người nghe.",
            "audio_kind": "nasa_recording",
        },
        "items": items,
    }
    (out_dir / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"F2: {len(items)} bản ghi âm NASA → {out_dir}")
    return catalog

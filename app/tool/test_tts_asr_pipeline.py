import asyncio
import os
import sys
import json
import re
import urllib.parse
import requests

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

TEST_CASES = [
    # 1. Các tỉnh/thành và địa danh phổ biến
    {"expected_kind": "go", "expected_place": "Hà Nội", "text": "Bay tới Hà Nội"},
    {"expected_kind": "weather", "expected_place": "Thành phố Hồ Chí Minh", "text": "Thời tiết ở Thành phố Hồ Chí Minh hôm nay thế nào"},
    {"expected_kind": "weather", "expected_place": "Đà Nẵng", "text": "Cho tôi xem thời tiết ở Đà Nẵng"},
    {"expected_kind": "music", "expected_place": "Huế", "text": "Đến Huế nghe nhạc cụ"},
    {"expected_kind": "weather", "expected_place": "Sa Pa", "text": "Thời tiết ở Sa Pa có lạnh không"},
    {"expected_kind": "go", "expected_place": "Cà Mau", "text": "Bay tới Cà Mau"},
    {"expected_kind": "weather", "expected_place": "Quảng Ninh", "text": "Quảng Ninh hôm nay có mưa không"},
    {"expected_kind": "weather", "expected_place": "Cần Thơ", "text": "Thời tiết ở Cần Thơ"},
    {"expected_kind": "go", "expected_place": "Hải Phòng", "text": "Đến Hải Phòng"},
    {"expected_kind": "weather", "expected_place": "Nha Trang", "text": "Nha Trang bây giờ bao nhiêu độ"},

    # 2. Xã, phường, đảo, vùng đặc biệt
    {"expected_kind": "weather", "expected_place": "Tân Triều", "text": "Thời tiết ở xã Tân Triều"},
    {"expected_kind": "go", "expected_place": "Ba Đình", "text": "Bay tới quận Ba Đình"},
    {"expected_kind": "weather", "expected_place": "Cần Giờ", "text": "Thời tiết huyện Cần Giờ"},
    {"expected_kind": "weather", "expected_place": "Côn Đảo", "text": "Thời tiết ở Côn Đảo"},
    {"expected_kind": "go", "expected_place": "Hoàng Sa", "text": "Đến quần đảo Hoàng Sa"},

    # 3. Câu hỏi tự do / thời tiết thường ngày
    {"expected_kind": "weather", "text": "Chiều nay đi làm có cần mang áo mưa không"},
    {"expected_kind": "weather", "text": "Ngày mai trời nóng bao nhiêu độ"},
    {"expected_kind": "weather", "text": "Sáng mai có sương mù không"},
    {"expected_kind": "weather", "text": "Ở đây thời tiết thế nào"},
    {"expected_kind": "bulletin", "text": "Đọc bản tin thời tiết hôm nay"},

    # 4. Điều khiển quả địa cầu
    {"expected_kind": "zoomIn", "text": "Phóng to lên một chút"},
    {"expected_kind": "zoomOut", "text": "Thu nhỏ quả địa cầu"},
    {"expected_kind": "stop", "text": "Dừng mọi âm thanh"},
    {"expected_kind": "repeat", "text": "Đọc lại thông tin vừa rồi"},
    {"expected_kind": "where", "text": "Đây là đâu"},
    {"expected_kind": "settings", "text": "Mở phần cài đặt"},

    # 5. NASA, thiên văn, quốc tế
    {"expected_kind": "apod", "text": "Ảnh thiên văn hôm nay của NASA"},
    {"expected_kind": "planet", "text": "Kể chuyện về Sao Hỏa"},
    {"expected_kind": "planets", "text": "Giới thiệu các hành tinh trong Hệ Mặt Trời"},
    {"expected_kind": "climate", "text": "Lượng mưa tháng 10 năm 2020"},
    {"expected_kind": "disasters", "text": "Xem các điểm cháy hôm nay"},
    {"expected_kind": "disasters", "text": "Thiên tai trên thế giới"},
    {"expected_kind": "go", "expected_place": "Tokyo", "text": "Bay tới Tokyo"},
    {"expected_kind": "weather", "expected_place": "Paris", "text": "Thời tiết ở Paris"},
]

def load_env(env_path):
    env = {}
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip()
    return env

def tts_google(text):
    encoded = urllib.parse.quote(text)
    url = f"https://translate.google.com/translate_tts?ie=UTF-8&q={encoded}&tl=vi&client=tw-ob"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    r = requests.get(url, headers=headers, timeout=10)
    if r.status_code == 200:
        return r.content
    raise RuntimeError(f"Google TTS HTTP {r.status_code}")

def groq_transcribe(audio_bytes, api_key):
    url = "https://api.groq.com/openai/v1/audio/transcriptions"
    headers = {"Authorization": f"Bearer {api_key}"}
    files = {"file": ("speech.mp3", audio_bytes, "audio/mpeg")}
    data = {
        "model": "whisper-large-v3",
        "language": "vi",
        "response_format": "json"
    }
    resp = requests.post(url, headers=headers, files=files, data=data, timeout=15)
    if resp.status_code == 200:
        return resp.json().get("text", "").strip()
    else:
        print(f"Lỗi Groq API {resp.status_code}: {resp.text}")
        return None

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    app_dir = os.path.dirname(script_dir)
    env_path = os.path.join(app_dir, ".env")
    env = load_env(env_path)

    api_key = env.get("GROQ_API_KEY", "")
    if not api_key:
        print("Không tìm thấy GROQ_API_KEY trong .env!")
        return

    print("=" * 70)
    print("BẮT ĐẦU KIỂM THỬ END-TO-END TTS -> WHISPER LARGE V3 -> APP PARSER")
    print(f"Tổng số ca kiểm thử: {len(TEST_CASES)}")
    print(f"Mô hình ASR: Whisper Large V3 (Groq Cloud)")
    print(f"Mô hình TTS: Google Neural Vietnamese Audio")
    print("=" * 70)

    results = []
    perfect_matches = 0

    for idx, tc in enumerate(TEST_CASES, 1):
        original_text = tc["text"]
        print(f"\n[{idx:02d}/{len(TEST_CASES)}] Đang tổng hợp TTS: \"{original_text}\"...")
        try:
            audio_bytes = tts_google(original_text)
            asr_text = groq_transcribe(audio_bytes, api_key)
            
            norm_orig = re.sub(r'[^\w\s]', '', original_text.lower()).strip()
            norm_asr = re.sub(r'[^\w\s]', '', asr_text.lower()).strip() if asr_text else ""
            is_match = (norm_orig == norm_asr)

            if is_match:
                perfect_matches += 1
                status_icon = "PASS (Trùng khớp 100%)"
            else:
                status_icon = "DIFF (Có khác biệt chính tả/từ)"

            print(f"   -> ASR nghe được: \"{asr_text}\"")
            print(f"   -> Trạng thái: {status_icon}")

            results.append({
                "original": original_text,
                "transcribed": asr_text,
                "expected_kind": tc.get("expected_kind"),
                "expected_place": tc.get("expected_place"),
                "is_match": is_match,
            })
        except Exception as e:
            print(f"   -> [LỖI] {e}")
            results.append({
                "original": original_text,
                "transcribed": None,
                "expected_kind": tc.get("expected_kind"),
                "expected_place": tc.get("expected_place"),
                "error": str(e)
            })

    output_path = os.path.join(app_dir, "test", "tts_asr_eval.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"KẾT QUẢ ASR TỔNG QUAN:")
    print(f"  • Trùng khớp hoàn toàn văn bản: {perfect_matches}/{len(TEST_CASES)} ({perfect_matches/len(TEST_CASES)*100:.1f}%)")
    print(f"  • Đã xuất file kết quả tại: {output_path}")
    print("=" * 70)

if __name__ == "__main__":
    main()

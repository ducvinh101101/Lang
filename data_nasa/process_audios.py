import os
import subprocess

RAW_DIR = "raw"
OUTPUT_DIR = os.path.join("assets", "content", "nasa")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Tìm vị trí file ffmpeg.exe
def get_ffmpeg_path():
    possible_paths = [
        os.path.join(os.getcwd(), "ffmpeg.exe"),
        os.path.join(os.getcwd(), "bin", "ffmpeg.exe"),
        "ffmpeg"
    ]
    for path in possible_paths:
        if os.path.exists(path):
            return path
    return "ffmpeg"

FFMPEG_EXE = get_ffmpeg_path()

def process_audio(filename):
    input_path = os.path.join(RAW_DIR, filename)
    output_path = os.path.join(OUTPUT_DIR, filename)

    print(f"🔊 Đang chuẩn hóa âm thanh: {filename}...")

    cmd = [
        FFMPEG_EXE, "-y",
        "-i", input_path,
        "-t", "30",
        "-ac", "1",
        "-ar", "22050",
        "-filter:a", "loudnorm=I=-16:LRA=11:TP=-1.5",
        output_path
    ]

    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        print(f"✅ Đã xuất thành phẩm: {output_path}")
    except Exception as e:
        print(f"❌ Lỗi khi xử lý {filename}: {e}")

def main():
    print(f"🔍 Đang sử dụng FFmpeg tại: {FFMPEG_EXE}")
    
    if not os.path.exists(RAW_DIR):
        print(f"❌ Không tìm thấy thư mục: {RAW_DIR}")
        return

    mp3_files = [f for f in os.listdir(RAW_DIR) if f.endswith(".mp3")]
    
    if not mp3_files:
        print("⚠️ Không có file .mp3 nào trong thư mục raw/")
        return

    print(f"🚀 Bắt đầu chuẩn hóa {len(mp3_files)} file âm thanh...\n")
    for mp3 in mp3_files:
        process_audio(mp3)

    print("\n🎉 Hoàn thành chuẩn hóa toàn bộ âm thanh sang assets/content/nasa/")

if __name__ == "__main__":
    main()
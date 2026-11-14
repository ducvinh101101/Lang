#!/usr/bin/env bash
# Vercel (bước Build): build bản web Lắng vào build/web.
set -euo pipefail
export PATH="$PWD/.flutter-sdk/bin:$PATH"
flutter build web --release
# Mô hình giọng đọc + nhận giọng của bản máy tính (~140 MB) không dùng trên web
# (web dùng giọng và nhận giọng của trình duyệt) → bỏ khỏi bản deploy cho nhẹ.
rm -rf build/web/assets/assets/voices build/web/assets/assets/asr
du -sh build/web || true
# Bộ nghe tiếng Anh (~132 MB, 5 phần) KHÔNG đóng gói trong app cài trên máy nữa → app tải từ đây khi người dùng
# chuyển sang tiếng Anh lần đầu (lib/speech/voice_listener_io.dart, EN_MODEL_URL)
mkdir -p build/web/models/en_parakeet
cp assets/asr/en_parakeet/model.int8.onnx.part* assets/asr/en_parakeet/tokens.txt build/web/models/en_parakeet/
du -sh build/web/models || true

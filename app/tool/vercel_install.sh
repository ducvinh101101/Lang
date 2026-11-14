#!/usr/bin/env bash
# Vercel (bước Install): tải Flutter SDK vào ./.flutter-sdk — máy build của Vercel không có sẵn Flutter.
# Đổi phiên bản: đặt biến môi trường FLUTTER_VERSION trên Vercel (vd 3.44.0); mặc định nhánh stable.
set -euo pipefail
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
if ! command -v unzip >/dev/null 2>&1; then
  (dnf install -y unzip xz >/dev/null 2>&1 || yum install -y unzip xz >/dev/null 2>&1) || true
fi
if [ ! -x .flutter-sdk/bin/flutter ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git .flutter-sdk
fi
export PATH="$PWD/.flutter-sdk/bin:$PATH"
flutter config --no-analytics --enable-web >/dev/null
flutter --version
flutter precache --web
flutter pub get
# thư viện cho hàm máy chủ api/tts.mjs (giọng tiếng Việt cho trình duyệt không có giọng Việt)
npm install --omit=dev --no-audit --no-fund

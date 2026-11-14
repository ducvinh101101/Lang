# Deploy bản web Lắng lên Vercel TỪ MÁY NÀY (dùng đúng Flutter đang cài, nhanh nhất).
# Cần: Node.js + Vercel CLI (npm i -g vercel), đã đăng nhập (vercel login).
#   Thử:   powershell -ExecutionPolicy Bypass -File tool\deploy_vercel.ps1
#   Chính thức: powershell -ExecutionPolicy Bypass -File tool\deploy_vercel.ps1 -Prod
param([switch]$Prod)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter build web --release
# mô hình giọng / nhận giọng của bản máy tính không dùng trên web
Remove-Item -Recurse -Force build\web\assets\assets\voices, build\web\assets\assets\asr -ErrorAction SilentlyContinue
Copy-Item tool\vercel.static.json build\web\vercel.json -Force
# API trên Vercel: trợ lý AI (giữ khoá Gemini trên máy chủ) + thống kê lượt dùng
New-Item -ItemType Directory -Force build\web\api | Out-Null
Copy-Item api\*.mjs build\web\api\ -Force
# giọng tiếng Việt chạy trên máy chủ (api/tts.mjs) cho Chrome/Firefox không có giọng Việt: thư viện + mô hình
Copy-Item package.json build\web\ -Force
New-Item -ItemType Directory -Force build\web\_tts | Out-Null
Copy-Item -Recurse -Force assets\voices\vi build\web\_tts\

if ($Prod) { vercel deploy build\web --prod } else { vercel deploy build\web }

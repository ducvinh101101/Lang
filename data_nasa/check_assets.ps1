# Script kiểm tra tính hợp lệ trước khi build App (Theo Mục 5)
$assets = ".\assets\content"
$nasaDir = "$assets\nasa"
$creditsFile = "$assets\credits.csv"
$planetsFile = "$assets\planets.json"
$indexFile = "$assets\index.json"

Write-Host "--- BẮT ĐẦU KIỂM TRA MỤC 5: ĐÓNG GÓI APP ---" -ForegroundColor Cyan
$errors = 0

# 1. Kiểm tra các file bắt buộc
foreach ($f in @($creditsFile, $planetsFile, $indexFile)) {
    if (Test-Path $f) {
        Write-Host "[OK] Tìm thấy: $f" -ForegroundColor Green
    } else {
        Write-Host "[LỖI] Thiếu file bắt buộc: $f" -ForegroundColor Red
        $errors++
    }
}

# 2. Kiểm tra credits.csv đối chiếu với thư mục nasa/
if (Test-Path $creditsFile) {
    $credits = Import-Csv -Path $creditsFile
    $creditedFiles = $credits | ForEach-Object { $_.file.Replace("\", "/") }
    
    $nasaFiles = Get-ChildItem -Path $nasaDir -Filter "*.mp3"
    foreach ($nf in $nasaFiles) {
        $rel = "nasa/$($nf.Name)"
        if ($creditedFiles -contains $rel) {
            Write-Host "[OK] Đã ghi công: $rel" -ForegroundColor Green
        } else {
            Write-Host "[CẢNH BÁO] File $rel chưa có trong credits.csv!" -ForegroundColor Yellow
            $errors++
        }
    }
}

if ($errors -eq 0) {
    Write-Host "`n>>> TẤT CẢ DỮ LIỆU ĐÃ HỢP LỆ VÀ SẴN SÀNG ĐÓNG GÓI! <<<" -ForegroundColor Cyan
} else {
    Write-Host "`n>>> PHÁT HIỆN $errors CẢNH BÁO/LỖI CẦN XỬ LÝ <<<" -ForegroundColor Red
}
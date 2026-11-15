@echo off
rem Thu build APK tren may va ghi toan bo log ra kiem_tra_build.log (de Claude doc va sua loi)
cd /d "%~dp0"
echo Dang build... (log: %CD%\kiem_tra_build.log)
> kiem_tra_build.log (
  echo ===== flutter --version
  call flutter --version 2>&1
  echo ===== java -version
  java -version 2>&1
  echo ===== flutter pub get
  call flutter pub get 2>&1
  echo ===== flutter build apk --release --split-per-abi
  call flutter build apk --release --split-per-abi -v 2>&1
  echo ===== EXIT %ERRORLEVEL%
)
echo Xong. Ket qua cuoi log:
powershell -NoProfile -Command "Get-Content kiem_tra_build.log -Tail 25"

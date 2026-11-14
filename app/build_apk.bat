@echo off
rem ============================================================================
rem  Build APK Android cho Lang (chay trong thu muc app\).
rem
rem    build_apk.bat          APK KHONG mang khoa API (an toan de chia se).
rem                           Tro ly AI va anh APOD di qua may chu Vercel cua app.
rem    build_apk.bat khoa     APK NHUNG khoa tu .env hoac keys.json (chi de thu noi bo,
rem                           KHONG chia se: khoa co the bi trich ra tu file APK).
rem
rem  Ky bang khoa rieng cua doi: dat truoc cac bien moi truong
rem    ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
rem  Khong dat thi ky bang khoa debug (van cai thu duoc).
rem  Ket qua: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk (da so dien thoai)
rem ============================================================================
setlocal
cd /d "%~dp0"

set "KEYARG="
if /I not "%~1"=="khoa" goto build
if exist .env (
    set "KEYARG=--dart-define-from-file=.env"
    goto warn
)
if exist keys.json (
    set "KEYARG=--dart-define-from-file=keys.json"
    goto warn
)
echo Khong tim thay .env hoac keys.json - build APK khong co khoa.
goto build

:warn
echo.
echo [CANH BAO] APK nay CO NHUNG KHOA API. Chi dung thu noi bo, KHONG gui len nhom chung hay GitHub.
echo.

:build
call flutter pub get || goto fail
call flutter build apk --release --split-per-abi %KEYARG% || goto fail
echo.
echo Xong. File APK nam o: %CD%\build\app\outputs\flutter-apk\
echo   - Da so dien thoai: app-arm64-v8a-release.apk
echo   - May 32-bit cu:    app-armeabi-v7a-release.apk
if exist build\app\outputs\flutter-apk explorer build\app\outputs\flutter-apk
exit /b 0

:fail
echo.
echo Build loi. Xem thong bao phia tren (thuong do thieu Android SDK: chay "flutter doctor").
exit /b 1

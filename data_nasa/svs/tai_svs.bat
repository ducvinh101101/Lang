@echo off
REM Tai day du cac video NASA SVS cho "May hat Trai Dat" (thu thach #14) vao data_nasa\svs\full\
REM Dung curl.exe co san tren Windows 10/11: tu noi lai khi rot mang (-C -), thu lai 5 lan.
chcp 65001 >nul
cd /d "%~dp0"
if not exist full mkdir full
set B=https://svs.gsfc.nasa.gov/vis/a000000
call :get %B%/a005400/a005475/nightlights_2012-2024_KSC_04_plus2_2048x1024_30p_sos.mp4 nightlights_2012-2024_KSC_04_plus2_2048x1024_30p_sos.mp4
call :get %B%/a005400/a005436/soscomp_1-29-2025a_1024p30.mp4 soscomp_1-29-2025a_1024p30.mp4
call :get %B%/a003900/a003912/flat_global_ecco2_2028x1024_comp_p30.mp4 flat_global_ecco2_2028x1024_comp_p30.mp4
call :get %B%/a005000/a005011/iss_lightning_sos_yearly_07312023_2048p60.mp4 iss_lightning_sos_yearly_07312023_2048p60.mp4
echo.
echo ===== XONG. Kich thuoc cac file: =====
dir /-c full\*.mp4
echo Bao lai cho Claude la "tai xong".
pause
exit /b

:get
set NAME=%2
echo.
echo === Dang tai %NAME% ...
curl.exe -L --fail --retry 5 --retry-delay 3 -C - -o "full\%NAME%" %1
if errorlevel 1 (
  echo   Loi lan 1, thu lai...
  curl.exe -L --fail --retry 5 --retry-delay 5 -C - -o "full\%NAME%" %1
)
exit /b

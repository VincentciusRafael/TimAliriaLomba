@echo off
REM ============================================================
REM  Pakai versi DESAIN DASHBOARD (statistik) pada halaman Lomba.
REM  Melawan: balik-seperti-semula.cmd (versi lama / daftar).
REM ============================================================
setlocal
set SRC=%~dp0versi-redesign-dashboard
set DST=%~dp0dionisiusnp.github.io-main

if not exist "%SRC%\lomba.html" (
  echo [ERROR] Folder versi dashboard tidak ditemukan: %SRC%
  exit /b 1
)

copy /Y "%SRC%\lomba.html"          "%DST%\lomba.html"          >nul
copy /Y "%SRC%\todolist\index.html" "%DST%\todolist\index.html" >nul
copy /Y "%SRC%\todolist\SETUP.md"   "%DST%\todolist\SETUP.md"   >nul

echo.
echo [OK] Versi DASHBOARD (statistik) dipasang:
echo   - lomba.html
echo   - todolist/index.html
echo   - todolist/SETUP.md
echo.
echo Untuk kembali ke versi daftar: jalankan balik-seperti-semula.cmd
echo.
pause

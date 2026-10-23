@echo off
REM ============================================================
REM  KEMBALIKAN ke tampilan SEBELUM redesign dashboard
REM  (lomba.html, todolist/index.html, todolist/SETUP.md)
REM  Jalankan file ini dari folder ini.
REM ============================================================
setlocal
set SRC=%~dp0backup-sebelum-redesign
set DST=%~dp0dionisiusnp.github.io-main

if not exist "%SRC%\lomba.html" (
  echo [ERROR] Folder backup tidak ditemukan: %SRC%
  exit /b 1
)

copy /Y "%SRC%\lomba.html"          "%DST%\lomba.html"          >nul
copy /Y "%SRC%\todolist\index.html" "%DST%\todolist\index.html" >nul
copy /Y "%SRC%\todolist\SETUP.md"   "%DST%\todolist\SETUP.md"   >nul

echo.
echo [OK] Tampilan sudah dikembalikan seperti semula:
echo   - lomba.html
echo   - todolist/index.html
echo   - todolist/SETUP.md
echo.
pause

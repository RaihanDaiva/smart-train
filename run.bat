@echo off
chcp 65001 >nul
cls

echo ╔════════════════════════════════════════╗
echo ║     Smart Train - Auto Run Script     ║
echo ╚════════════════════════════════════════╝
echo.

REM Cek apakah Dart tersedia
where dart >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo DART TIDAK DITEMUKAN!
    echo - Install Flutter terlebih dahulu
    echo.
    pause
    exit /b 1
)

REM Cek apakah Flutter tersedia
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo FLUTTER TIDAK DITEMUKAN!
    echo - Install Flutter terlebih dahulu
    echo.
    pause
    exit /b 1
)

REM Cek apakah file scripts/generate_env.dart ada
if not exist "scripts\generate_env.dart" (
    echo FILE scripts/generate_env.dart TIDAK DITEMUKAN!
    echo - Pastikan file script ada di folder scripts/
    echo.
    pause
    exit /b 1
)

REM Step 1: Generate .env
echo o Step 1: Auto-detecting IP Address...
echo.
call dart run scripts/generate_env.dart

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo GAGAL GENERATE .env
    echo - Pastikan laptop terhubung ke WiFi/Ethernet
    echo.
    pause
    exit /b 1
)

echo.
echo ════════════════════════════════════════
echo.

REM Step 2: Tampilkan pilihan
echo o Step 2: Pilih mode run:
echo   1^) Flutter Run - Debug Mode ^(Recommended^)
echo   2^) Flutter Run - Release Mode
echo   3^) Flutter Build APK
echo   4^) Exit
echo.

set /p choice="Pilih (1-4): "

if "%choice%"=="1" (
    echo.
    echo Menjalankan Flutter Run - Debug Mode...
    echo.
    call flutter run
    goto end
) else if "%choice%"=="2" (
    echo.
    echo Menjalankan Flutter Run - Release Mode...
    echo.
    call flutter run --release
    goto end
) else if "%choice%"=="3" (
    echo.
    echo Building APK - Release Mode...
    echo.
    call flutter build apk --release
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo APK BERHASIL DIBUAT!
        echo - Lokasi: build\app\outputs\flutter-apk\app-release.apk
    )
    goto end
) else if "%choice%"=="4" (
    echo Bye!
    timeout /t 2 >nul
    exit /b 0
) else (
    echo.
    echo PILIHAN TIDAK VALID!
    echo.
    pause
    exit /b 1
)

:end
echo.
echo ════════════════════════════════════════
echo.
pause
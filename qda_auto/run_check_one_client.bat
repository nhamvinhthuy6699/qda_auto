@echo off
title QDA Check One Client Status

cd /d "%~dp0"

echo ==========================================
echo          QDA CHECK ONE CLIENT
echo ==========================================
echo.

set /p TARGET_IP=Nhap IP client can check: 

if "%TARGET_IP%"=="" (
    echo [LOI] Chua nhap IP.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_client_status.ps1" -IP "%TARGET_IP%"

echo.
echo ==========================================
echo          QDA CHECK ONE FINISHED
echo ==========================================
echo.

echo File ket qua:
echo %~dp0status\%TARGET_IP%.json
echo.

if exist "%~dp0status\%TARGET_IP%.json" (
    type "%~dp0status\%TARGET_IP%.json"
) else (
    echo Khong thay file ket qua.
)

echo.
echo Doc ket qua xong thi bam phim bat ky de dong cua so.
pause >nul
exit
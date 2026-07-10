@echo off
title QDA Check All Clients Status

cd /d "%~dp0"

echo ==========================================
echo          QDA CHECK ALL CLIENTS
echo ==========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_client_status.ps1" -All

echo.
echo ==========================================
echo          QDA CHECK ALL FINISHED
echo ==========================================
echo.

echo File thanh cong:
echo %~dp0check_status_success.txt
echo.
echo File that bai:
echo %~dp0check_status_failed.txt
echo.
echo Thu muc status:
echo %~dp0status
echo.

echo ===== NOI DUNG FILE THAT BAI NEU CO =====
if exist "%~dp0check_status_failed.txt" (
    type "%~dp0check_status_failed.txt"
) else (
    echo Khong co file that bai.
)
echo ==========================================
echo.

echo Doc ket qua xong thi bam phim bat ky de dong cua so.
pause >nul
exit
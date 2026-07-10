@echo off
title Shutdown Tasks HP + Dell - QDA Room Control

cd /d "%~dp0"

echo ==========================================
echo        QDA ROOM CONTROL START
echo ==========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_shutdown_tasks.ps1"

echo.
echo ==========================================
echo        QDA ROOM CONTROL FINISHED
echo ==========================================
echo.

echo File thanh cong:
echo %~dp0shutdown_tasks_success.txt
echo.
echo File that bai:
echo %~dp0shutdown_tasks_failed.txt
echo.

echo ===== NOI DUNG FILE THAT BAI NEU CO =====
if exist "%~dp0shutdown_tasks_failed.txt" (
    type "%~dp0shutdown_tasks_failed.txt"
) else (
    echo Khong co file that bai.
)
echo ==========================================
echo.

echo Doc ket qua xong thi bam phim bat ky de dong cua so.
pause >nul

exit
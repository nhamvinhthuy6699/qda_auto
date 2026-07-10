@echo off
title QDA Exam Mode - Hide C / WiFi Control

cd /d "%~dp0"

echo ==========================================
echo             QDA EXAM MODE
echo ==========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_exam_mode.ps1"

echo.
echo ==========================================
echo           QDA EXAM MODE FINISHED
echo ==========================================
echo.

echo File thanh cong:
echo %~dp0exam_mode_success.txt
echo.
echo File that bai:
echo %~dp0exam_mode_failed.txt
echo.

echo ===== NOI DUNG FILE THAT BAI NEU CO =====
if exist "%~dp0exam_mode_failed.txt" (
    type "%~dp0exam_mode_failed.txt"
) else (
    echo Khong co file that bai.
)
echo ==========================================
echo.

echo Doc ket qua xong thi bam phim bat ky de dong cua so.
pause >nul

exit
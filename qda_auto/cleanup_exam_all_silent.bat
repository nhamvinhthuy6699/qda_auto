@echo off
title QDA Cleanup Exam Silent Throttle
setlocal

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup_exam_all_silent.ps1"

exit /b %errorlevel%
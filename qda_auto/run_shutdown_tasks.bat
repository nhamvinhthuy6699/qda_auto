@echo off
title Shutdown Tasks HP + Dell - FIX

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_shutdown_tasks.ps1"

pause

@echo off
title Dell Power-On Tasks

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_dell_poweron_tasks.ps1"

pause

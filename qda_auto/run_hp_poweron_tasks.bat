@echo off
title HP Power-On Tasks

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_hp_poweron_tasks.ps1"

pause

@echo off
title Import Veyon CSV

set BASE=%~dp0
set CSV=%BASE%veyon_clients.csv
set IMPORT=%BASE%veyon_import.csv
set CLI=C:\Program Files\Veyon\veyon-cli.exe

if not exist "%CSV%" (
    echo [LOI] Khong thay %CSV%
    pause
    exit /b 1
)

if not exist "%CLI%" (
    echo [LOI] Khong thay %CLI%
    pause
    exit /b 1
)

echo ===== TAO FILE IMPORT VEYON =====

powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Csv '%CSV%' | ForEach-Object { \"$($_.ROOM),$($_.NAME),$($_.IP),$($_.MAC)\" } | Set-Content '%IMPORT%' -Encoding ASCII"

echo ===== CLEAR DANH SACH CU =====
"%CLI%" networkobjects clear

echo ===== IMPORT DANH SACH MOI =====
"%CLI%" networkobjects import "%IMPORT%" format "%%location%%,%%name%%,%%host%%,%%mac%%"

echo ===== KIEM TRA =====
"%CLI%" networkobjects list

echo.
echo Xong. Hay dong mo lai Veyon Master.
pause
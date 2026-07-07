@echo off
title Scan Rooms To Veyon

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan_rooms_to_veyon.ps1"

echo.
echo ===== UPDATE clients.txt FROM veyon_clients.csv =====

powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Csv '%~dp0veyon_clients.csv' | ForEach-Object { $_.IP } | Sort-Object -Unique | Set-Content '%~dp0clients.txt' -Encoding ASCII"

echo.
echo Da cap nhat clients.txt tu veyon_clients.csv
echo.

pause
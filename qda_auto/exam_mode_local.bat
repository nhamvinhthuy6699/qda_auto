@echo off
title QDA Exam Mode Local

setlocal EnableDelayedExpansion

if /I "%1"=="APPLY" goto APPLY_MODE

set MODE=%1

del C:\exam_mode_log.txt /f /q >nul 2>&1
del C:\exam_mode_result.txt /f /q >nul 2>&1

echo ===== QDA EXAM MODE LOCAL ===== > C:\exam_mode_log.txt
echo START %DATE% %TIME% >> C:\exam_mode_log.txt
echo MODE=%MODE% >> C:\exam_mode_log.txt

if "%MODE%"=="1" call :ENABLE_EXAM_MODE
if "%MODE%"=="2" call :DISABLE_EXAM_MODE

if not "%MODE%"=="1" if not "%MODE%"=="2" (
    echo FAILED - Invalid MODE=%MODE% > C:\exam_mode_result.txt
    echo [ERROR] Invalid MODE=%MODE% >> C:\exam_mode_log.txt
    exit /b 1
)

echo [BACKGROUND] Starting background Wi-Fi toggle + restart... >> C:\exam_mode_log.txt

start "" /min cmd.exe /c ""%~f0" APPLY %MODE%"

echo SUCCESS > C:\exam_mode_result.txt
echo [DONE] Local registry completed. Background process will toggle Wi-Fi and restart. >> C:\exam_mode_log.txt

exit /b 0


:APPLY_MODE
set MODE=%2

echo [APPLY] Background apply started at %DATE% %TIME% MODE=%MODE% >> C:\exam_mode_log.txt

timeout /t 5 /nobreak >nul

if "%MODE%"=="1" (
    call :DISABLE_WIFI_ONLY
)

if "%MODE%"=="2" (
    call :ENABLE_WIFI_ONLY
)

echo [APPLY] Restart computer now... >> C:\exam_mode_log.txt
shutdown /r /f /t 0

exit /b 0


:ENABLE_EXAM_MODE
echo [1] ENABLE EXAM MODE - Hide C + Disable WiFi... >> C:\exam_mode_log.txt

call :HIDE_C_DRIVE

echo [1] ENABLE EXAM MODE registry done. >> C:\exam_mode_log.txt
exit /b 0


:DISABLE_EXAM_MODE
echo [2] DISABLE EXAM MODE - Show C + Enable WiFi... >> C:\exam_mode_log.txt

call :SHOW_C_DRIVE

echo [2] DISABLE EXAM MODE registry done. >> C:\exam_mode_log.txt
exit /b 0


:HIDE_C_DRIVE
echo [C] Hide / block C drive... >> C:\exam_mode_log.txt

reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDrives /t REG_DWORD /d 4 /f >> C:\exam_mode_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoViewOnDrive /t REG_DWORD /d 4 /f >> C:\exam_mode_log.txt 2>&1

call :HIDE_C_FOR_USER admin

reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" >> C:\exam_mode_log.txt 2>&1

echo [C] Hide C done. >> C:\exam_mode_log.txt
exit /b 0


:SHOW_C_DRIVE
echo [C] Show / unblock C drive... >> C:\exam_mode_log.txt

reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDrives /f >> C:\exam_mode_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoViewOnDrive /f >> C:\exam_mode_log.txt 2>&1

call :SHOW_C_FOR_USER admin

reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" >> C:\exam_mode_log.txt 2>&1

echo [C] Show C done. >> C:\exam_mode_log.txt
exit /b 0


:HIDE_C_FOR_USER
set "TARGET_USER=%~1"
set "TARGET_SID="

for /f "delims=" %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "try{(Get-LocalUser '%TARGET_USER%').SID.Value}catch{}" 2^>nul') do set "TARGET_SID=%%S"

if "%TARGET_SID%"=="" (
    echo [C_USER] Cannot get SID for %TARGET_USER%. Skip. >> C:\exam_mode_log.txt
    exit /b 0
)

echo [C_USER] Hide C for TARGET_USER=%TARGET_USER% SID=%TARGET_SID% >> C:\exam_mode_log.txt

reg query "HKU\%TARGET_SID%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    reg add "HKU\%TARGET_SID%\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDrives /t REG_DWORD /d 4 /f >> C:\exam_mode_log.txt 2>&1
    reg delete "HKU\%TARGET_SID%\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoViewOnDrive /t REG_DWORD /d 4 /f >> C:\exam_mode_log.txt 2>&1
) else (
    echo [C_USER] User hive not loaded. HKLM will apply after login/restart. >> C:\exam_mode_log.txt
)

exit /b 0


:SHOW_C_FOR_USER
set "TARGET_USER=%~1"
set "TARGET_SID="

for /f "delims=" %%S in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "try{(Get-LocalUser '%TARGET_USER%').SID.Value}catch{}" 2^>nul') do set "TARGET_SID=%%S"

if "%TARGET_SID%"=="" (
    echo [C_USER] Cannot get SID for %TARGET_USER%. Skip. >> C:\exam_mode_log.txt
    exit /b 0
)

echo [C_USER] Show C for TARGET_USER=%TARGET_USER% SID=%TARGET_SID% >> C:\exam_mode_log.txt

reg query "HKU\%TARGET_SID%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    reg delete "HKU\%TARGET_SID%\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDrives /f >> C:\exam_mode_log.txt 2>&1
    reg delete "HKU\%TARGET_SID%\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoViewOnDrive /f >> C:\exam_mode_log.txt 2>&1
) else (
    echo [C_USER] User hive not loaded. HKLM removed, user policy may clear after login/restart. >> C:\exam_mode_log.txt
)

exit /b 0


:DISABLE_WIFI_ONLY
echo [WIFI] Disable WiFi adapters only. Do not touch LAN/Ethernet. >> C:\exam_mode_log.txt

start "" /min powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match 'Wi-Fi|Wifi|Wireless|WLAN|802.11') -or ($_.InterfaceDescription -match 'Wi-Fi|Wifi|Wireless|WLAN|802.11') } | ForEach-Object { Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }"

timeout /t 8 /nobreak >nul

echo [WIFI] Disable WiFi command sent. >> C:\exam_mode_log.txt
exit /b 0


:ENABLE_WIFI_ONLY
echo [WIFI] Enable WiFi adapters only. Do not touch LAN/Ethernet. >> C:\exam_mode_log.txt

start "" /min powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match 'Wi-Fi|Wifi|Wireless|WLAN|802.11') -or ($_.InterfaceDescription -match 'Wi-Fi|Wifi|Wireless|WLAN|802.11') } | ForEach-Object { Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue }"

timeout /t 8 /nobreak >nul

echo [WIFI] Enable WiFi command sent. >> C:\exam_mode_log.txt
exit /b 0
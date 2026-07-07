@echo off
title Set Windows NTP Server

echo ==========================================
echo        SET WINDOWS NTP SERVER
echo ==========================================
echo.
echo [1] Server dong bo Internet time.windows.com
echo [2] Server dung gio local, khong Internet
set /p MODE=Nhap 1 hoac 2: 

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [LOI] Hay chay bang Run as administrator.
    pause
    exit /b 1
)

tzutil /s "SE Asia Standard Time"

sc config w32time start= auto >nul 2>&1
net start w32time >nul 2>&1

if "%MODE%"=="1" (
    echo [MODE 1] Dung Internet time.windows.com...
    w32tm /config /manualpeerlist:"time.windows.com,0x8" /syncfromflags:manual /reliable:yes /update
) else (
    echo [MODE 2] Dung Local Clock reliable...
    w32tm /config /syncfromflags:manual /reliable:yes /update
)

reg add HKLM\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer /v Enabled /t REG_DWORD /d 1 /f >nul

net stop w32time
net start w32time

netsh advfirewall firewall delete rule name="Allow NTP UDP 123" >nul 2>&1
netsh advfirewall firewall add rule name="Allow NTP UDP 123" dir=in action=allow protocol=UDP localport=123 profile=any >nul

echo.
echo ===== STATUS =====
w32tm /query /source
w32tm /query /status
echo.
pause

@echo off
title Reinstall Veyon Client Clean

setlocal EnableDelayedExpansion

set BASE=C:\APP_DEPLOY\INSTALL
set SRC=%BASE%\VEYON
set INSTALLER=%SRC%\veyon-setup.exe
set PUBKEY=%SRC%\master_public.pem
set LOG=%BASE%\veyon_install_log.txt
set RESULT=%BASE%\veyon_install_result.txt
set CLI=C:\Program Files\Veyon\veyon-cli.exe

echo ===== CLEAN REINSTALL VEYON CLIENT ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"

if not exist "%INSTALLER%" (
 echo FAILED VEYON_INSTALLER_NOT_FOUND > "%RESULT%"
 exit /b 1
)

if not exist "%PUBKEY%" (
 echo FAILED VEYON_PUBLIC_KEY_NOT_FOUND > "%RESULT%"
 exit /b 1
)

echo [1] Stop Veyon service... >> "%LOG%"
net stop VeyonService >> "%LOG%" 2>&1

echo [2] Remove old Veyon config/key cache... >> "%LOG%"
rmdir /s /q "C:\ProgramData\Veyon" >> "%LOG%" 2>&1
rmdir /s /q "C:\Program Files\Veyon\etc" >> "%LOG%" 2>&1

echo [3] Install/Reinstall Veyon silent... >> "%LOG%"
"%INSTALLER%" /S >> "%LOG%" 2>&1

timeout /t 15 /nobreak >nul

if not exist "%CLI%" (
 echo FAILED VEYON_CLI_NOT_FOUND > "%RESULT%"
 exit /b 1
)

echo [4] Import public key... >> "%LOG%"
"%CLI%" authkeys import master/public "%PUBKEY%" >> "%LOG%" 2>&1

echo [5] Check key... >> "%LOG%"
"%CLI%" authkeys list >> "%LOG%" 2>&1

"%CLI%" authkeys list | findstr /i "master/public" >nul 2>&1
if errorlevel 1 (
 echo FAILED VEYON_KEY_IMPORT_FAILED > "%RESULT%"
 exit /b 1
)

echo [6] Set service automatic... >> "%LOG%"
sc config VeyonService start= auto >> "%LOG%" 2>&1

echo [7] Open firewall... >> "%LOG%"
netsh advfirewall firewall delete rule name="Veyon TCP 11100" >> "%LOG%" 2>&1
netsh advfirewall firewall delete rule name="Veyon TCP 11400" >> "%LOG%" 2>&1
netsh advfirewall firewall add rule name="Veyon TCP 11100" dir=in action=allow protocol=TCP localport=11100 >> "%LOG%" 2>&1
netsh advfirewall firewall add rule name="Veyon TCP 11400" dir=in action=allow protocol=TCP localport=11400 >> "%LOG%" 2>&1

echo [8] Restart Veyon service... >> "%LOG%"
net stop VeyonService >> "%LOG%" 2>&1
net start VeyonService >> "%LOG%" 2>&1

echo [9] Check service and port... >> "%LOG%"
sc query VeyonService >> "%LOG%" 2>&1
netstat -ano | find "11100" >> "%LOG%" 2>&1

sc query VeyonService | findstr /i "RUNNING" >nul 2>&1
if errorlevel 1 (
 echo FAILED VEYON_SERVICE_NOT_RUNNING > "%RESULT%"
 exit /b 1
)

netstat -ano | find "11100" >nul 2>&1
if errorlevel 1 (
 echo FAILED VEYON_PORT_11100_NOT_LISTENING > "%RESULT%"
 exit /b 1
)

echo SUCCESS VEYON_CLIENT_READY > "%RESULT%"
echo SUCCESS VEYON_CLIENT_READY >> "%LOG%"
exit /b 0
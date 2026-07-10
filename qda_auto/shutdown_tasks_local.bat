@echo off
title Shutdown Tasks Local HP + Dell - QDA Room Control

setlocal EnableDelayedExpansion

set KILL_APP=%1
set CLEAR_BIOS=%2
set DISABLE_STARTUP=%3
set DO_SHUTDOWN=%4

del C:\shutdown_tasks_log.txt /f /q >nul 2>&1
del C:\shutdown_tasks_result.txt /f /q >nul 2>&1

echo ===== SHUTDOWN TASKS LOCAL HP + DELL / QDA ROOM CONTROL ===== > C:\shutdown_tasks_log.txt
echo START %DATE% %TIME% >> C:\shutdown_tasks_log.txt
echo KILL_APP=%KILL_APP% >> C:\shutdown_tasks_log.txt
echo CLEAR_BIOS=%CLEAR_BIOS% >> C:\shutdown_tasks_log.txt
echo DISABLE_STARTUP=%DISABLE_STARTUP% >> C:\shutdown_tasks_log.txt
echo DO_SHUTDOWN=%DO_SHUTDOWN% >> C:\shutdown_tasks_log.txt

if /I "%KILL_APP%"=="Y" call :KILL_SEB_AND_RESTORE
if /I "%CLEAR_BIOS%"=="Y" call :CLEAR_BIOS_POWERON
if /I "%DISABLE_STARTUP%"=="Y" call :DISABLE_STARTUP_APP

if /I "%DO_SHUTDOWN%"=="Y" (
    echo SUCCESS > C:\shutdown_tasks_result.txt
    echo [SHUTDOWN] shutdown /s /f /t 0 >> C:\shutdown_tasks_log.txt
    timeout /t 3 /nobreak >nul
    shutdown /s /f /t 0
    exit /b 0
)

echo SUCCESS > C:\shutdown_tasks_result.txt
exit /b 0


:KILL_SEB_AND_RESTORE
echo [1] Kill SEB/QDA and restore Windows policy... >> C:\shutdown_tasks_log.txt

echo [1A] Kill SEB/QDA processes... >> C:\shutdown_tasks_log.txt

taskkill /F /T /IM SafeExamBrowser.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SafeExamBrowser.Client.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SafeExamBrowser.Service.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SafeExamBrowser.Browser.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SEBWindowsService.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SebWindowsService.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM SEB.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM CefSharp.BrowserSubprocess.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM QDA.exe >> C:\shutdown_tasks_log.txt 2>&1
taskkill /F /T /IM qda.exe >> C:\shutdown_tasks_log.txt 2>&1

timeout /t 3 /nobreak >nul

call :RUN_SEB_RESETTER
call :RESTORE_WINDOWS_POLICY

echo [1] Done kill SEB/QDA and restore policy. >> C:\shutdown_tasks_log.txt
exit /b 0


:RUN_SEB_RESETTER
echo [1B] Try run SebRegistryResetter... >> C:\shutdown_tasks_log.txt

set "SEB_RESETTER_1=C:\Program Files (x86)\SafeExamBrowser\SebWindowsServiceWCF\SebRegistryResetter.exe"
set "SEB_RESETTER_2=C:\Program Files\SafeExamBrowser\SebWindowsServiceWCF\SebRegistryResetter.exe"
set "SEB_RESETTER="

if exist "%SEB_RESETTER_1%" set "SEB_RESETTER=%SEB_RESETTER_1%"
if "%SEB_RESETTER%"=="" if exist "%SEB_RESETTER_2%" set "SEB_RESETTER=%SEB_RESETTER_2%"

if "%SEB_RESETTER%"=="" (
    echo [SEB_RESETTER] Not found. Skip. >> C:\shutdown_tasks_log.txt
    exit /b 0
)

echo [SEB_RESETTER] Found: %SEB_RESETTER% >> C:\shutdown_tasks_log.txt

set "LOGIN_USER="

for /f "skip=1 tokens=1" %%A in ('query user 2^>nul') do (
    if not defined LOGIN_USER set "LOGIN_USER=%%A"
)

if "!LOGIN_USER:~0,1!"==">" set "LOGIN_USER=!LOGIN_USER:~1!"

echo [SEB_RESETTER] Detected LOGIN_USER=!LOGIN_USER! >> C:\shutdown_tasks_log.txt

if not "!LOGIN_USER!"=="" (
    echo [SEB_RESETTER] Run with user input: !LOGIN_USER! >> C:\shutdown_tasks_log.txt
    echo !LOGIN_USER! | "%SEB_RESETTER%" >> C:\shutdown_tasks_log.txt 2>&1
    echo [SEB_RESETTER] ExitCode=%ERRORLEVEL% >> C:\shutdown_tasks_log.txt
) else (
    echo [SEB_RESETTER] Cannot detect user. Run blank input. >> C:\shutdown_tasks_log.txt
    echo. | "%SEB_RESETTER%" >> C:\shutdown_tasks_log.txt 2>&1
    echo [SEB_RESETTER] Blank ExitCode=%ERRORLEVEL% >> C:\shutdown_tasks_log.txt
)

ver >nul
exit /b 0


:RESTORE_WINDOWS_POLICY
echo [1C] Restore Windows shutdown / explorer / system policies... >> C:\shutdown_tasks_log.txt

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoClose /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HidePowerOptions /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HidePowerOptions /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogOff /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogOff /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableLockWorkstation /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableChangePassword /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableChangePassword /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v DontDisplayNetworkSelectionUI /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\Utilman.exe" /v Debugger /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\VMware, Inc.\VMware VDM\Client" /v EnableShade /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\VMware, Inc.\VMware VDM\Client" /v EnableShade /f >> C:\shutdown_tasks_log.txt 2>&1

gpupdate /force >> C:\shutdown_tasks_log.txt 2>&1

echo [1C] Policy restore done. Skip restart explorer to avoid black screen. >> C:\shutdown_tasks_log.txt
exit /b 0


:CLEAR_BIOS_POWERON
echo [2] Clear BIOS Power-On HP/Dell... >> C:\shutdown_tasks_log.txt
call :CLEAR_DELL_BIOS
call :CLEAR_HP_BIOS
exit /b 0


:CLEAR_DELL_BIOS
echo [2A] Try clear Dell Auto-On... >> C:\shutdown_tasks_log.txt

set CCTK1=C:\Windows\Temp\DELL_AUTOON\DELL_CMD\cctk.exe
set CCTK2=C:\Windows\Temp\DELL_AUTOON\DELL_CMD\X86_64\cctk.exe
set CCTK3=C:\Windows\Temp\DELL_AUTOON\DELL_CCTK\cctk.exe
set CCTK4=C:\Windows\Temp\DELL_AUTOON\DELL_CCTK\X86_64\cctk.exe
set CCTK=

if exist "%CCTK1%" set CCTK=%CCTK1%
if "%CCTK%"=="" if exist "%CCTK2%" set CCTK=%CCTK2%
if "%CCTK%"=="" if exist "%CCTK3%" set CCTK=%CCTK3%
if "%CCTK%"=="" if exist "%CCTK4%" set CCTK=%CCTK4%

if "%CCTK%"=="" (
    echo [SKIP] Khong thay Dell CCTK. >> C:\shutdown_tasks_log.txt
    exit /b 0
)

"%CCTK%" --autoon=disabled >> C:\shutdown_tasks_log.txt 2>&1
"%CCTK%" --autoon >> C:\shutdown_tasks_log.txt 2>&1

exit /b 0


:CLEAR_HP_BIOS
echo [2B] Try clear HP BIOS Power-On... >> C:\shutdown_tasks_log.txt

set HPBCU1=C:\Windows\Temp\NTP_LAB\HP_BCU\BiosConfigUtility64.exe
set HPBCU2=C:\Windows\Temp\HP_BCU\BiosConfigUtility64.exe
set HPBCU=

if exist "%HPBCU1%" set HPBCU=%HPBCU1%
if "%HPBCU%"=="" if exist "%HPBCU2%" set HPBCU=%HPBCU2%

if "%HPBCU%"=="" (
    echo [SKIP] Khong thay HP BCU. >> C:\shutdown_tasks_log.txt
    exit /b 0
)

> C:\hp_poweron_disable_shutdown.tmp echo BIOSConfig 1.0
>> C:\hp_poweron_disable_shutdown.tmp echo Sunday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Monday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Tuesday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Wednesday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Thursday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Friday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo Saturday
>> C:\hp_poweron_disable_shutdown.tmp echo 	*Disable
>> C:\hp_poweron_disable_shutdown.tmp echo BIOS Power-On Hour
>> C:\hp_poweron_disable_shutdown.tmp echo 	0
>> C:\hp_poweron_disable_shutdown.tmp echo BIOS Power-On Minute
>> C:\hp_poweron_disable_shutdown.tmp echo 	0

"%HPBCU%" /setconfig:"C:\hp_poweron_disable_shutdown.tmp" >> C:\shutdown_tasks_log.txt 2>&1
del C:\hp_poweron_disable_shutdown.tmp /f /q >nul 2>&1
exit /b 0


:DISABLE_STARTUP_APP
echo [3] Disable Startup QDA/SEB/BQP... >> C:\shutdown_tasks_log.txt

set "COMMON_STARTUP=C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"

if exist "%COMMON_STARTUP%" (
    echo [3A] Clean COMMON STARTUP: %COMMON_STARTUP% >> C:\shutdown_tasks_log.txt

    del "%COMMON_STARTUP%\open_qda_once.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\open_qda_after_30s.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\open_qda_startup.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1

    del "%COMMON_STARTUP%\*QDA*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*BQP*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*SEB*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*safe*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*exam*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1

    del "%COMMON_STARTUP%\*QDA*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*BQP*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*SEB*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*safe*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%COMMON_STARTUP%\*exam*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
)

echo [3B] Clean all user Startup folders... >> C:\shutdown_tasks_log.txt

for /d %%U in ("C:\Users\*") do (
    call :DELETE_STARTUP "%%~fU"
)

echo [3C] Delete scheduled tasks... >> C:\shutdown_tasks_log.txt

schtasks /Delete /TN "Open QDA Once" /F >> C:\shutdown_tasks_log.txt 2>&1
schtasks /Delete /TN "Open QDA Startup" /F >> C:\shutdown_tasks_log.txt 2>&1
schtasks /Delete /TN "QDA Startup" /F >> C:\shutdown_tasks_log.txt 2>&1
schtasks /Delete /TN "Auto Open QDA" /F >> C:\shutdown_tasks_log.txt 2>&1
schtasks /Delete /TN "DellPowerOnTasks" /F >> C:\shutdown_tasks_log.txt 2>&1
schtasks /Delete /TN "HPPowerOnTasks" /F >> C:\shutdown_tasks_log.txt 2>&1

echo [3D] Delete registry Run keys... >> C:\shutdown_tasks_log.txt

reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "OpenQDA" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "QDAStartup" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "OpenBQP" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "BQPStartup" /f >> C:\shutdown_tasks_log.txt 2>&1

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OpenQDA" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "QDAStartup" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OpenBQP" /f >> C:\shutdown_tasks_log.txt 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "BQPStartup" /f >> C:\shutdown_tasks_log.txt 2>&1

echo [3] Da xoa Startup QDA/SEB/BQP. >> C:\shutdown_tasks_log.txt
exit /b 0


:DELETE_STARTUP
set "PROFILE=%~1"
set "STARTUP=%PROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"

if exist "%STARTUP%" (
    echo [3B] Clean USER STARTUP: %STARTUP% >> C:\shutdown_tasks_log.txt

    del "%STARTUP%\open_qda_once.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\open_qda_after_30s.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\open_qda_startup.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1

    del "%STARTUP%\*QDA*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*BQP*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*SEB*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*safe*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*exam*.bat" /f /q >> C:\shutdown_tasks_log.txt 2>&1

    del "%STARTUP%\*QDA*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*BQP*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*SEB*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*safe*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
    del "%STARTUP%\*exam*.lnk" /f /q >> C:\shutdown_tasks_log.txt 2>&1
)

exit /b 0
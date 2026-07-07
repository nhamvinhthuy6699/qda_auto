@echo off
title HP Power-On Tasks Local - Startup Fix

setlocal EnableDelayedExpansion

set DO_BIOS=%1
set SUN=%2
set MON=%3
set TUE=%4
set WED=%5
set THU=%6
set FRI=%7
set SAT=%8
set TARGET_TIME=%9
shift
shift
shift
shift
shift
shift
shift
shift
shift
set DO_APP=%1
set APP_DELAY=%2

if "%APP_DELAY%"=="" set APP_DELAY=30
set LOGFILE=C:\hp_poweron_tasks_log.txt

del C:\hp_poweron_tasks_log.txt /f /q >nul 2>&1
del C:\hp_poweron_tasks_result.txt /f /q >nul 2>&1

echo ===== HP POWER-ON TASKS LOCAL - STARTUP FIX ===== > %LOGFILE%
echo DO_BIOS=%DO_BIOS% TARGET_TIME=%TARGET_TIME% DO_APP=%DO_APP% APP_DELAY=%APP_DELAY% >> %LOGFILE%

if /I "%DO_BIOS%"=="Y" call :SET_HP_BIOS
if errorlevel 1 exit /b 1

if /I "%DO_APP%"=="Y" call :SET_STARTUP_APP
if errorlevel 1 exit /b 1

echo SUCCESS > C:\hp_poweron_tasks_result.txt
exit /b 0

:SET_HP_BIOS
set HPBCU=%~dp0HP_BCU\BiosConfigUtility64.exe

if not exist "%HPBCU%" (
    echo FAILED - Khong thay BiosConfigUtility64.exe > C:\hp_poweron_tasks_result.txt
    echo [BIOS] Khong thay BiosConfigUtility64.exe >> %LOGFILE%
    exit /b 1
)

for /f "tokens=1,2 delims=:" %%a in ("%TARGET_TIME%") do (
    set TARGET_HOUR=%%a
    set TARGET_MINUTE=%%b
)
set /a TARGET_HOUR_NUM=1%TARGET_HOUR%-100
set /a TARGET_MINUTE_NUM=1%TARGET_MINUTE%-100

> C:\hp_poweron_tasks_config.tmp echo BIOSConfig 1.0
call :WRITE_DAY Sunday %SUN%
call :WRITE_DAY Monday %MON%
call :WRITE_DAY Tuesday %TUE%
call :WRITE_DAY Wednesday %WED%
call :WRITE_DAY Thursday %THU%
call :WRITE_DAY Friday %FRI%
call :WRITE_DAY Saturday %SAT%

>> C:\hp_poweron_tasks_config.tmp echo BIOS Power-On Hour
>> C:\hp_poweron_tasks_config.tmp echo 	%TARGET_HOUR_NUM%
>> C:\hp_poweron_tasks_config.tmp echo BIOS Power-On Minute
>> C:\hp_poweron_tasks_config.tmp echo 	%TARGET_MINUTE_NUM%

"%HPBCU%" /setconfig:"C:\hp_poweron_tasks_config.tmp" >> %LOGFILE% 2>&1
if errorlevel 1 (
    echo FAILED - HP BCU setconfig loi > C:\hp_poweron_tasks_result.txt
    exit /b 1
)
del C:\hp_poweron_tasks_config.tmp /f /q >nul 2>&1
exit /b 0

:WRITE_DAY
set DAYNAME=%1
set ENABLE=%2
>> C:\hp_poweron_tasks_config.tmp echo %DAYNAME%
if "%ENABLE%"=="1" (
    >> C:\hp_poweron_tasks_config.tmp echo 	*Enable
) else (
    >> C:\hp_poweron_tasks_config.tmp echo 	*Disable
)
exit /b 0

:SET_STARTUP_APP
echo [APP] Dang tim QDA/SEB de tao Startup... >> %LOGFILE%

set QDA_FILE=

REM Uu tien tim trong admin va TTCNTTNN truoc
call :FIND_QDA "C:\Users\admin"
call :FIND_QDA "C:\Users\TTCNTTNN"
call :FIND_QDA "C:\Users\DELL"
call :FIND_QDA "C:\Users\dell"
call :FIND_QDA "C:\Users\adfmin"
call :FIND_QDA "C:\Users\adin"
call :FIND_QDA "C:\Users\admintest"

REM Tim them Public Desktop
if "%QDA_FILE%"=="" (
    for %%P in (
        "C:\Users\Public\Desktop\*QDA*.seb"
        "C:\Users\Public\Desktop\*BQP*.seb"
        "C:\Users\Public\Desktop\*QDA*.lnk"
        "C:\Users\Public\Desktop\*BQP*.lnk"
    ) do (
        if exist "%%~fP" (
            set QDA_FILE=%%~fP
            goto FOUND_QDA_FILE
        )
    )
)

:FOUND_QDA_FILE
if "%QDA_FILE%"=="" (
    echo WARNING - Khong tim thay QDA/SEB tren admin/TTCNTTNN/Desktop/Documents/Downloads/Public >> %LOGFILE%
    exit /b 0
)

echo [APP] QDA_FILE=%QDA_FILE% >> %LOGFILE%

REM Tao Startup chung All Users: user nao login cung chay
set COMMON_STARTUP=C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup
set COMMON_STARTUP_FILE=%COMMON_STARTUP%\open_qda_startup.bat

if not exist "%COMMON_STARTUP%" mkdir "%COMMON_STARTUP%"

del "%COMMON_STARTUP_FILE%" /f /q >nul 2>&1

(
echo @echo off
echo timeout /t %APP_DELAY% /nobreak ^>nul
echo start "" "%QDA_FILE%"
) > "%COMMON_STARTUP_FILE%"

echo [APP] Created common startup: %COMMON_STARTUP_FILE% >> %LOGFILE%

REM Tao them Startup rieng cho admin va TTCNTTNN cho chac
REM call :CREATE_USER_STARTUP "C:\Users\admin"
REM call :CREATE_USER_STARTUP "C:\Users\TTCNTTNN"

exit /b 0


:FIND_QDA
if not "%QDA_FILE%"=="" exit /b 0

set CHECK_PROFILE=%~1

for %%P in (
    "%CHECK_PROFILE%\Desktop\QDA2026_BQP.seb"
    "%CHECK_PROFILE%\Desktop\*QDA2026*.seb"
    "%CHECK_PROFILE%\Desktop\*BQP*.seb"
    "%CHECK_PROFILE%\Desktop\*QDA*.seb"
    "%CHECK_PROFILE%\Desktop\*QDA*.lnk"
    "%CHECK_PROFILE%\Desktop\*BQP*.lnk"

    "%CHECK_PROFILE%\Documents\*QDA*.seb"
    "%CHECK_PROFILE%\Documents\*BQP*.seb"
    "%CHECK_PROFILE%\Documents\*QDA*.lnk"
    "%CHECK_PROFILE%\Documents\*BQP*.lnk"

    "%CHECK_PROFILE%\Downloads\*QDA*.seb"
    "%CHECK_PROFILE%\Downloads\*BQP*.seb"
    "%CHECK_PROFILE%\Downloads\*QDA*.lnk"
    "%CHECK_PROFILE%\Downloads\*BQP*.lnk"
) do (
    if exist "%%~fP" (
        set QDA_FILE=%%~fP
        exit /b 0
    )
)

exit /b 0


:CREATE_USER_STARTUP
set USER_PROFILE=%~1
set USER_STARTUP=%USER_PROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup
set USER_STARTUP_FILE=%USER_STARTUP%\open_qda_startup.bat

if exist "%USER_PROFILE%" (
    if not exist "%USER_STARTUP%" mkdir "%USER_STARTUP%"

    del "%USER_STARTUP_FILE%" /f /q >nul 2>&1

    (
    echo @echo off
    echo timeout /t %APP_DELAY% /nobreak ^>nul
    echo start "" "%QDA_FILE%"
    ) > "%USER_STARTUP_FILE%"

    echo [APP] Created user startup: %USER_STARTUP_FILE% >> %LOGFILE%
)

exit /b 0

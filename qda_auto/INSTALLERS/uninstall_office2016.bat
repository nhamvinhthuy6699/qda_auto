@echo off
title Uninstall Office 2016

setlocal EnableDelayedExpansion

set BASE=C:\APP_DEPLOY\INSTALL
set OFFICE_DIR=%BASE%\OFFICE2016
set SETUP=%OFFICE_DIR%\setup.exe
set REMOVE_XML=%BASE%\remove_office2016_config.xml
set LOG=%BASE%\office2016_uninstall_log.txt
set RESULT=%BASE%\office2016_uninstall_result.txt

if not exist "%BASE%" mkdir "%BASE%"

echo ===== UNINSTALL OFFICE 2016 ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"

echo OFFICE_DIR=%OFFICE_DIR% >> "%LOG%"
echo SETUP=%SETUP% >> "%LOG%"
echo REMOVE_XML=%REMOVE_XML% >> "%LOG%"

echo [1] Kill Office processes... >> "%LOG%"
taskkill /F /IM WINWORD.EXE >> "%LOG%" 2>&1
taskkill /F /IM EXCEL.EXE >> "%LOG%" 2>&1
taskkill /F /IM POWERPNT.EXE >> "%LOG%" 2>&1
taskkill /F /IM OUTLOOK.EXE >> "%LOG%" 2>&1
taskkill /F /IM MSACCESS.EXE >> "%LOG%" 2>&1
taskkill /F /IM ONENOTE.EXE >> "%LOG%" 2>&1

echo [2] Check source... >> "%LOG%"

if not exist "%SETUP%" (
    echo FAILED SETUP_NOT_FOUND > "%RESULT%"
    echo FAILED: Khong thay %SETUP% >> "%LOG%"
    exit /b 1
)

if not exist "%OFFICE_DIR%\proplus.ww" (
    echo FAILED PROPLUS_WW_NOT_FOUND > "%RESULT%"
    echo FAILED: Khong thay %OFFICE_DIR%\proplus.ww >> "%LOG%"
    exit /b 1
)

echo [3] Create remove config... >> "%LOG%"

(
echo ^<Configuration Product="ProPlus"^>
echo   ^<Display Level="none" CompletionNotice="no" SuppressModal="yes" AcceptEula="yes" /^>
echo ^</Configuration^>
) > "%REMOVE_XML%"

echo [4] Run Office uninstall... >> "%LOG%"

cd /d "%OFFICE_DIR%"

"%SETUP%" /uninstall ProPlus /config "%REMOVE_XML%" >> "%LOG%" 2>&1

set CODE=%ERRORLEVEL%
echo Uninstall exit code: !CODE! >> "%LOG%"

echo [5] Wait setup/msiexec finish... >> "%LOG%"

set WAIT_COUNT=0

:WAIT_OFFICE
tasklist | findstr /i "setup.exe msiexec.exe" >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto CHECK_REMOVE

if !WAIT_COUNT! GEQ 120 goto CHECK_REMOVE

timeout /t 5 /nobreak >nul
set /a WAIT_COUNT+=1
goto WAIT_OFFICE

:CHECK_REMOVE
echo [6] Check Office removed... >> "%LOG%"

set WORD_FOUND=0

if exist "C:\Program Files\Microsoft Office\Office16\WINWORD.EXE" set WORD_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE" set WORD_FOUND=1

if "%WORD_FOUND%"=="0" (
    echo SUCCESS OFFICE2016_UNINSTALLED CODE=!CODE! > "%RESULT%"
    echo SUCCESS: Office 2016 uninstalled. >> "%LOG%"
    exit /b 0
)

echo FAILED OFFICE2016_STILL_EXISTS CODE=!CODE! > "%RESULT%"
echo FAILED: Office 2016 still exists. >> "%LOG%"
exit /b 1
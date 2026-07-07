@echo off
title Remove Microsoft 365 By ODT - Safe Version

setlocal EnableDelayedExpansion

set BASE=C:\APP_DEPLOY\INSTALL
set ODT_DIR=%BASE%\ODT
set ODT_SETUP=%ODT_DIR%\setup.exe
set REMOVE_XML=%BASE%\remove_m365_all.xml
set LOG=%BASE%\remove_m365_odt_log.txt
set RESULT=%BASE%\remove_m365_odt_result.txt

echo ===== REMOVE MICROSOFT 365 BY ODT SAFE ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"
echo BASE=%BASE% >> "%LOG%"
echo ODT_SETUP=%ODT_SETUP% >> "%LOG%"

echo. >> "%LOG%"
echo [1] Kill Office processes... >> "%LOG%"

taskkill /F /T /IM WINWORD.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM EXCEL.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM POWERPNT.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM OUTLOOK.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM ONENOTE.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM MSACCESS.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM MSPUB.EXE >> "%LOG%" 2>&1
taskkill /F /T /IM OfficeClickToRun.exe >> "%LOG%" 2>&1
taskkill /F /T /IM OfficeC2RClient.exe >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo [2] Check ODT setup.exe... >> "%LOG%"

if exist "%ODT_SETUP%" goto ODT_OK

echo FAILED ODT_SETUP_NOT_FOUND > "%RESULT%"
echo FAILED: Cannot find ODT setup.exe >> "%LOG%"
exit /b 1

:ODT_OK
echo ODT setup.exe found. >> "%LOG%"

echo. >> "%LOG%"
echo [3] Create Remove XML... >> "%LOG%"

echo ^<Configuration^> > "%REMOVE_XML%"
echo   ^<Remove All="TRUE" /^> >> "%REMOVE_XML%"
echo   ^<Display Level="None" AcceptEULA="TRUE" /^> >> "%REMOVE_XML%"
echo   ^<Property Name="FORCEAPPSHUTDOWN" Value="TRUE" /^> >> "%REMOVE_XML%"
echo ^</Configuration^> >> "%REMOVE_XML%"

echo XML created at %REMOVE_XML% >> "%LOG%"
type "%REMOVE_XML%" >> "%LOG%"

echo. >> "%LOG%"
echo [4] Run ODT Remove All... >> "%LOG%"

"%ODT_SETUP%" /configure "%REMOVE_XML%" >> "%LOG%" 2>&1

set CODE=%ERRORLEVEL%
echo ODT Remove All exit code: !CODE! >> "%LOG%"

echo. >> "%LOG%"
echo [5] Wait after ODT remove... >> "%LOG%"

ping 127.0.0.1 -n 61 >nul

echo. >> "%LOG%"
echo [6] Check exact Office C2R paths... >> "%LOG%"

set OFFICE_FOUND=0

if exist "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" set OFFICE_FOUND=1
if exist "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" set OFFICE_FOUND=1
if exist "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE" set OFFICE_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE" set OFFICE_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\root\Office16\EXCEL.EXE" set OFFICE_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\root\Office16\POWERPNT.EXE" set OFFICE_FOUND=1

echo OFFICE_FOUND=!OFFICE_FOUND! >> "%LOG%"

echo. >> "%LOG%"
echo [7] List remaining Office files... >> "%LOG%"

where /r "C:\Program Files\Microsoft Office" WINWORD.EXE >> "%LOG%" 2>&1
where /r "C:\Program Files\Microsoft Office" EXCEL.EXE >> "%LOG%" 2>&1
where /r "C:\Program Files\Microsoft Office" POWERPNT.EXE >> "%LOG%" 2>&1
where /r "C:\Program Files (x86)\Microsoft Office" WINWORD.EXE >> "%LOG%" 2>&1
where /r "C:\Program Files (x86)\Microsoft Office" EXCEL.EXE >> "%LOG%" 2>&1
where /r "C:\Program Files (x86)\Microsoft Office" POWERPNT.EXE >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo [8] Check Office ClickToRun registry... >> "%LOG%"

reg query "HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" >> "%LOG%" 2>&1

if "!OFFICE_FOUND!"=="0" goto SUCCESS_REMOVE

echo FAILED M365_STILL_REMAINS CODE=!CODE! > "%RESULT%"
echo FAILED: Office C2R executable still exists after ODT Remove All. >> "%LOG%"
exit /b 1

:SUCCESS_REMOVE
echo SUCCESS M365_REMOVED CODE=!CODE! > "%RESULT%"
echo SUCCESS: Microsoft 365 C2R apps not found. >> "%LOG%"
exit /b 0
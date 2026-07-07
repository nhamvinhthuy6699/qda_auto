@echo off
title Install Office 2016 Strict Check

setlocal EnableDelayedExpansion

set BASE=C:\APP_DEPLOY\INSTALL
set OFFICE_DIR=%BASE%\OFFICE2016
set SETUP=%OFFICE_DIR%\setup.exe
set MSP=%OFFICE_DIR%\updates\office2016_silent.msp
set LOG=%BASE%\office2016_install_log.txt
set RESULT=%BASE%\office2016_install_result.txt

if not exist "%BASE%" mkdir "%BASE%"

echo ===== INSTALL OFFICE 2016 STRICT ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"
echo OFFICE_DIR=%OFFICE_DIR% >> "%LOG%"
echo SETUP=%SETUP% >> "%LOG%"
echo MSP=%MSP% >> "%LOG%"

echo [1] Check source files... >> "%LOG%"

if not exist "%SETUP%" (
    echo FAILED SETUP_NOT_FOUND > "%RESULT%"
    exit /b 1
)

if not exist "%OFFICE_DIR%\proplus.ww" (
    echo FAILED PROPLUS_WW_NOT_FOUND > "%RESULT%"
    exit /b 1
)

if not exist "%MSP%" (
    echo FAILED MSP_NOT_FOUND > "%RESULT%"
    exit /b 1
)

echo Source OK. >> "%LOG%"

echo [2] Run Office setup with MSP... >> "%LOG%"

cd /d "%OFFICE_DIR%"

"%SETUP%" /adminfile "%MSP%" >> "%LOG%" 2>&1

set CODE=%ERRORLEVEL%
echo Setup exit code: !CODE! >> "%LOG%"

echo [3] Check Office apps and VBA... >> "%LOG%"

set WORD_FOUND=0
set EXCEL_FOUND=0
set PPT_FOUND=0
set ACCESS_FOUND=0
set VBA_FOUND=0

if exist "C:\Program Files\Microsoft Office\Office16\WINWORD.EXE" set WORD_FOUND=1
if exist "C:\Program Files\Microsoft Office\Office16\EXCEL.EXE" set EXCEL_FOUND=1
if exist "C:\Program Files\Microsoft Office\Office16\POWERPNT.EXE" set PPT_FOUND=1
if exist "C:\Program Files\Microsoft Office\Office16\MSACCESS.EXE" set ACCESS_FOUND=1

if exist "C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE" set WORD_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\Office16\EXCEL.EXE" set EXCEL_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\Office16\POWERPNT.EXE" set PPT_FOUND=1
if exist "C:\Program Files (x86)\Microsoft Office\Office16\MSACCESS.EXE" set ACCESS_FOUND=1

powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Get-ChildItem 'C:\Program Files\Microsoft Office','C:\Program Files\Common Files\Microsoft Shared','C:\Program Files (x86)\Microsoft Office','C:\Program Files (x86)\Common Files\Microsoft Shared' -Recurse -Filter VBE7INTL.DLL -ErrorAction SilentlyContinue | Select-Object -First 1) { exit 0 } else { exit 1 }"

if !ERRORLEVEL! EQU 0 set VBA_FOUND=1

echo WORD=!WORD_FOUND! >> "%LOG%"
echo EXCEL=!EXCEL_FOUND! >> "%LOG%"
echo PPT=!PPT_FOUND! >> "%LOG%"
echo ACCESS=!ACCESS_FOUND! >> "%LOG%"
echo VBA=!VBA_FOUND! >> "%LOG%"

if "!WORD_FOUND!"=="1" if "!EXCEL_FOUND!"=="1" if "!PPT_FOUND!"=="1" if "!ACCESS_FOUND!"=="1" if "!VBA_FOUND!"=="1" (
    echo SUCCESS OFFICE2016_EXAM_READY CODE=!CODE! > "%RESULT%"
    exit /b 0
)

echo FAILED OFFICE2016_NOT_EXAM_READY CODE=!CODE! > "%RESULT%"
exit /b 1
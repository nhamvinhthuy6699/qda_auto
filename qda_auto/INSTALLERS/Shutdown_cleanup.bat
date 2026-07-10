@echo off
title QDA Shutdown Cleanup
setlocal EnableExtensions EnableDelayedExpansion

REM =====================================================
REM TU DONG YEU CAU QUYEN ADMINISTRATOR
REM Nguoi dung chi can BAM DUP file BAT
REM =====================================================

net session >nul 2>&1

if errorlevel 1 (
    echo Dang yeu cau quyen Administrator...

    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"

    exit /b
)

:init

REM Chuyen working directory ve noi chua file BAT
cd /d "%~dp0"

REM =====================================================
REM CHUONG TRINH BAT DAU TU DAY
REM =====================================================

REM =====================================================
REM TIM USER DANG DANG NHAP
REM =====================================================

set "LOGGED_USER="

for /f "tokens=2 delims=\" %%U in ('whoami') do (
    set "CURRENT_USER=%%U"
)

for /f "tokens=2 delims==" %%U in ('wmic computersystem get username /value 2^>nul ^| find "="') do (
    set "LOGGED_USER=%%U"
)

if defined LOGGED_USER (
    for /f "tokens=2 delims=\" %%U in ("!LOGGED_USER!") do (
        set "LOGGED_USER=%%U"
    )
)

if not defined LOGGED_USER (
    set "LOGGED_USER=%CURRENT_USER%"
)

set "USER_PROFILE=C:\Users\%LOGGED_USER%"

if not exist "%USER_PROFILE%" (
    echo [LOI] Khong tim thay profile user:
    echo %USER_PROFILE%
    pause
    exit /b 2
)

REM =====================================================
REM DUONG DAN CAN DON
REM =====================================================

set "DESKTOP=%USER_PROFILE%\Desktop"
set "ONEDRIVE_DESKTOP=%USER_PROFILE%\OneDrive\Desktop"
set "DOWNLOADS=%USER_PROFILE%\Downloads"

set "THICNTT=%DESKTOP%\ThiCNTT"
set "THICNTT_ONEDRIVE=%ONEDRIVE_DESKTOP%\ThiCNTT"

REM =====================================================
REM TAO THICNTT NEU CHUA CO
REM =====================================================

if exist "%DESKTOP%" (
    if not exist "%THICNTT%" (
        mkdir "%THICNTT%" >nul 2>&1
    )
)

if exist "%ONEDRIVE_DESKTOP%" (
    if not exist "%THICNTT_ONEDRIVE%" (
        mkdir "%THICNTT_ONEDRIVE%" >nul 2>&1
    )
)

REM =====================================================
REM DON SACH BEN TRONG THICNTT
REM =====================================================

if exist "%THICNTT%" (
    attrib -h -r -s "%THICNTT%\*" /s /d >nul 2>&1

    for /d %%D in ("%THICNTT%\*") do (
        rmdir /s /q "%%D"
    )

    del /f /q "%THICNTT%\*" >nul 2>&1
)

if exist "%THICNTT_ONEDRIVE%" (
    attrib -h -r -s "%THICNTT_ONEDRIVE%\*" /s /d >nul 2>&1

    for /d %%D in ("%THICNTT_ONEDRIVE%\*") do (
        rmdir /s /q "%%D"
    )

    del /f /q "%THICNTT_ONEDRIVE%\*" >nul 2>&1
)

REM =====================================================
REM DON SACH DOWNLOADS
REM =====================================================

if exist "%DOWNLOADS%" (
    attrib -h -r -s "%DOWNLOADS%\*" /s /d >nul 2>&1

    for /d %%D in ("%DOWNLOADS%\*") do (
        rmdir /s /q "%%D"
    )

    del /f /q "%DOWNLOADS%\*" >nul 2>&1
)

REM =====================================================
REM DON DESKTOP THUONG
REM CHI GIU:
REM - ThiCNTT
REM - Microsoft Edge
REM - UniKey / UnikeyTM / UniKeyNT / VNI
REM - Shutdown_Cleanup.bat
REM
REM RECYCLE BIN LA ICON HE THONG, KHONG NAM NHU FILE THUONG
REM =====================================================

if exist "%DESKTOP%" (
    for /f "delims=" %%F in ('dir /b /a-d "%DESKTOP%" 2^>nul') do (
        set "KEEP=N"

        echo %%F | findstr /i /b /c:"Microsoft Edge" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UniKey" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"Unikey" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UnikeyTM" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UniKeyNT" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"VNI" >nul && set "KEEP=Y"
        echo %%F | findstr /i /x /c:"Shutdown_Cleanup.bat" >nul && set "KEEP=Y"

        if /i "!KEEP!"=="N" (
            del /f /q "%DESKTOP%\%%F" >nul 2>&1
        )
    )

    for /d %%D in ("%DESKTOP%\*") do (
        if /i not "%%~nxD"=="ThiCNTT" (
            attrib -h -s "%%D" >nul 2>&1

            if not "%%~aD"=="dhs" (
                rmdir /s /q "%%D"
            )
        )
    )
)

REM =====================================================
REM DON ONEDRIVE DESKTOP NEU CO
REM =====================================================

if exist "%ONEDRIVE_DESKTOP%" (
    for /f "delims=" %%F in ('dir /b /a-d "%ONEDRIVE_DESKTOP%" 2^>nul') do (
        set "KEEP=N"

        echo %%F | findstr /i /b /c:"Microsoft Edge" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UniKey" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"Unikey" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UnikeyTM" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"UniKeyNT" >nul && set "KEEP=Y"
        echo %%F | findstr /i /b /c:"VNI" >nul && set "KEEP=Y"
        echo %%F | findstr /i /x /c:"Shutdown_Cleanup.bat" >nul && set "KEEP=Y"

        if /i "!KEEP!"=="N" (
            del /f /q "%ONEDRIVE_DESKTOP%\%%F" >nul 2>&1
        )
    )

    for /d %%D in ("%ONEDRIVE_DESKTOP%\*") do (
        if /i not "%%~nxD"=="ThiCNTT" (
            rmdir /s /q "%%D"
        )
    )
)

REM =====================================================
REM EMPTY RECYCLE BIN
REM =====================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

REM =====================================================
REM TAT MAY
REM =====================================================

shutdown.exe /s /f /t 0

exit /b 0
@echo off
title Uninstall QDA Cleanup Service
setlocal EnableExtensions

REM File nay duoc install.ps1 chay bang SYSTEM tren client.
REM Khong hoi Y, khong UAC.

set "SERVICE_NAME=QDACleanupService"

set "INSTALL_DIR=C:\ProgramData\QDA\ShutdownCleanup"
set "SOURCE_DIR=C:\APP_DEPLOY\INSTALL\QDA_CLEANUP_SERVICE"

echo ===== UNINSTALL QDA CLEANUP SERVICE =====

REM =====================================================
REM STOP SERVICE
REM =====================================================

sc.exe query "%SERVICE_NAME%" >nul 2>&1

if not errorlevel 1 (
    echo [1] Stop service...
    sc.exe stop "%SERVICE_NAME%" >nul 2>&1
    timeout /t 5 /nobreak >nul
) else (
    echo [INFO] Service khong ton tai.
)

REM =====================================================
REM DELETE SERVICE REGISTRATION
REM =====================================================

sc.exe query "%SERVICE_NAME%" >nul 2>&1

if not errorlevel 1 (
    echo [2] Delete service...
    sc.exe delete "%SERVICE_NAME%" >nul 2>&1

    if errorlevel 1 (
        echo [LOI] Khong xoa duoc service.
        exit /b 1
    )

    timeout /t 5 /nobreak >nul
)

REM =====================================================
REM DELETE INSTALLED FILES
REM =====================================================

echo [3] Delete installed cleanup files...

if exist "%INSTALL_DIR%" (
    rmdir /s /q "%INSTALL_DIR%"
)

if exist "%INSTALL_DIR%" (
    echo [LOI] Thu muc service van con:
    echo %INSTALL_DIR%
    exit /b 1
)

REM =====================================================
REM DELETE COPIED SOURCE
REM =====================================================

echo [4] Delete copied source...

if exist "%SOURCE_DIR%" (
    rmdir /s /q "%SOURCE_DIR%"
)

if exist "%SOURCE_DIR%" (
    echo [LOI] Source folder van con:
    echo %SOURCE_DIR%
    exit /b 1
)

REM =====================================================
REM VERIFY SERVICE REMOVED
REM =====================================================

sc.exe query "%SERVICE_NAME%" >nul 2>&1

if not errorlevel 1 (
    echo [LOI] Service van con ton tai.
    exit /b 1
)

echo [OK] Da go QDA Cleanup Service.
echo [OK] Da xoa:
echo - %INSTALL_DIR%
echo - %SOURCE_DIR%

exit /b 0
@echo off
title QDA Cleanup Exam For All Clients
setlocal EnableDelayedExpansion

cd /d "%~dp0"

REM =====================================================
REM CAU HINH
REM =====================================================

set "BASE=%~dp0"
set "CLIENTS=%BASE%clients.txt"
set "REMOTE_DIR=C:\Windows\Temp\QDA_CLEANUP"
set "LOCAL_PS1=%BASE%cleanup_exam_remote_client.ps1"

REM Tai khoan admin local tren may client
set "ADMINUSER=admintest"
set "ADMINPASS=123456"

REM TEST truoc thi de N.
REM Khi muon don xong tat may thi doi thanh Y.
set "SHUTDOWN_AFTER_CLEAN=N"

REM PsExec.exe dat trong C:\mywork\qda_auto neu co
set "PSEXEC=%BASE%PsExec.exe"

set "LOG=%BASE%cleanup_exam_log.txt"
set "SUCCESS=%BASE%cleanup_exam_success.txt"
set "FAILED=%BASE%cleanup_exam_failed.txt"

echo ===== QDA CLEANUP EXAM ALL CLIENTS ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"
echo BASE=%BASE% >> "%LOG%"
echo CLIENTS=%CLIENTS% >> "%LOG%"
echo ADMINUSER=%ADMINUSER% >> "%LOG%"
echo SHUTDOWN_AFTER_CLEAN=%SHUTDOWN_AFTER_CLEAN% >> "%LOG%"
echo. >> "%LOG%"

if not exist "%CLIENTS%" (
    echo [LOI] Khong thay clients.txt
    echo [LOI] Khong thay clients.txt >> "%LOG%"
    pause
    exit /b 1
)

if not exist "%LOCAL_PS1%" (
    echo [LOI] Khong thay cleanup_exam_remote_client.ps1
    echo [LOI] Khong thay cleanup_exam_remote_client.ps1 >> "%LOG%"
    pause
    exit /b 1
)

if not exist "%PSEXEC%" (
    set "PSEXEC=psexec"
)

del "%SUCCESS%" >nul 2>&1
del "%FAILED%" >nul 2>&1

echo ==========================================
echo       QDA CLEANUP EXAM ALL CLIENTS
echo ==========================================
echo.
echo Script nay chay tu server den cac client trong clients.txt
echo.


set /p CONFIRM=Nhap Y de bat dau TEST tren tat ca client: 

if /i not "%CONFIRM%"=="Y" (
    echo [HUY] Nguoi dung khong xac nhan.
    echo [HUY] User cancelled >> "%LOG%"
    pause
    exit /b 1
)

echo.
echo ===== BAT DAU =====
echo.

for /f "usebackq tokens=1 delims=,; " %%I in ("%CLIENTS%") do (
    set "IP=%%I"

    if not "!IP!"=="" (
        echo !IP! | findstr /b "#" >nul
        if errorlevel 1 (
            call :RUN_ONE "!IP!"
        )
    )
)

echo.
echo ==========================================
echo           HOAN TAT
echo ==========================================
echo.
echo Success:
type "%SUCCESS%" 2>nul
echo.
echo Failed:
type "%FAILED%" 2>nul
echo.
echo Log:
echo %LOG%
echo.
pause
exit /b 0


:RUN_ONE
set "IP=%~1"

echo ------------------------------------------
echo [RUN] Dang don dep may %IP%
echo ------------------------------------------

echo. >> "%LOG%"
echo ===== %IP% ===== >> "%LOG%"
echo [%DATE% %TIME%] START %IP% >> "%LOG%"

ping -n 1 -w 1000 "%IP%" >nul 2>&1
if errorlevel 1 (
    echo [FAIL] %IP% - Ping failed
    echo %IP% - Ping failed >> "%FAILED%"
    echo [FAIL] Ping failed >> "%LOG%"
    goto :EOF
)

REM Xoa ket noi SMB cu neu co
net use "\\%IP%\C$" /delete /y >nul 2>&1

REM Ket noi C$ bang tai khoan admin
echo [CONNECT] \\%IP%\C$
echo [CONNECT] \\%IP%\C$ >> "%LOG%"

net use "\\%IP%\C$" /user:%ADMINUSER% "%ADMINPASS%" >> "%LOG%" 2>&1

if errorlevel 1 (
    echo [FAIL] %IP% - Cannot access C$
    echo %IP% - Cannot access C$ >> "%FAILED%"
    echo [FAIL] Cannot access \\%IP%\C$ >> "%LOG%"
    goto :EOF
)

REM Tao folder remote bang SMB
mkdir "\\%IP%\C$\Windows\Temp\QDA_CLEANUP" >nul 2>&1

REM Copy PS1 sang client
copy /y "%LOCAL_PS1%" "\\%IP%\C$\Windows\Temp\QDA_CLEANUP\cleanup_exam_remote_client.ps1" >> "%LOG%" 2>&1

if errorlevel 1 (
    echo [FAIL] %IP% - Copy PS1 failed
    echo %IP% - Copy PS1 failed >> "%FAILED%"
    echo [FAIL] Copy PS1 failed >> "%LOG%"
    net use "\\%IP%\C$" /delete /y >nul 2>&1
    goto :EOF
)

if /i "%SHUTDOWN_AFTER_CLEAN%"=="Y" (
    set "PS_ARGS=-ShutdownAfterClean"
) else (
    set "PS_ARGS="
)

REM =====================================================
REM Chay tren client bang SYSTEM
REM Khong dung -u -p de tranh loi logon type
REM admintest chi dung de mo C$ va copy file
REM =====================================================

echo [PSEXEC] Run as SYSTEM without -u -p >> "%LOG%"

"%PSEXEC%" \\%IP% -accepteula -nobanner -s powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Temp\QDA_CLEANUP\cleanup_exam_remote_client.ps1" %PS_ARGS% >> "%LOG%" 2>&1

set "PSEXEC_EXIT=%ERRORLEVEL%"
echo [PSEXEC_EXIT] %PSEXEC_EXIT% >> "%LOG%"

if not "%PSEXEC_EXIT%"=="0" (
    echo [FAIL] %IP% - Cleanup failed
    echo %IP% - Cleanup failed >> "%FAILED%"
    echo [FAIL] Cleanup failed >> "%LOG%"
    net use "\\%IP%\C$" /delete /y >nul 2>&1
    goto :EOF
)

echo [OK] %IP% - Cleanup success
echo %IP% - Cleanup success >> "%SUCCESS%"
echo [OK] Cleanup success >> "%LOG%"

net use "\\%IP%\C$" /delete /y >nul 2>&1

goto :EOF
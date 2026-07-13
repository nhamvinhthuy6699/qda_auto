@echo off
title Install QDA Hybrid Cleanup Service
setlocal EnableExtensions

REM =====================================================
REM FILE NAY DUOC INSTALL.PS1 CHAY BANG SYSTEM QUA PSEXEC
REM
REM KHONG:
REM - PAUSE
REM - SET /P
REM - CHOICE
REM - TIMEOUT
REM =====================================================

set "SERVICE_NAME=QDACleanupService"
set "SERVICE_DISPLAY=QDA Shutdown Cleanup Service"

set "SOURCE_DIR=C:\APP_DEPLOY\INSTALL\QDA_CLEANUP_SERVICE"
set "SOURCE_CS=%SOURCE_DIR%\QDACleanupService.cs"
set "SOURCE_PS1=%SOURCE_DIR%\cleanup_exam_remote_client.ps1"

set "INSTALL_DIR=C:\ProgramData\QDA\ShutdownCleanup"
set "LOG_DIR=%INSTALL_DIR%\Logs"

set "SERVICE_EXE=%INSTALL_DIR%\QDACleanupService.exe"
set "TARGET_PS1=%INSTALL_DIR%\cleanup_exam_remote_client.ps1"

set "CSC64=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
set "CSC32=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
set "CSC="

echo ==========================================
echo    INSTALL QDA HYBRID CLEANUP SERVICE
echo ==========================================
echo.

REM =====================================================
REM 1. KIEM TRA SOURCE
REM =====================================================

if not exist "%SOURCE_CS%" (
    echo [FAIL] Khong thay C# source:
    echo %SOURCE_CS%
    exit /b 10
)

if not exist "%SOURCE_PS1%" (
    echo [FAIL] Khong thay cleanup PS1:
    echo %SOURCE_PS1%
    exit /b 11
)

REM =====================================================
REM 2. TIM C# COMPILER
REM =====================================================

if exist "%CSC64%" (
    set "CSC=%CSC64%"
)

if not defined CSC if exist "%CSC32%" (
    set "CSC=%CSC32%"
)

if not defined CSC (
    echo [FAIL] Khong thay csc.exe.
    echo Da kiem tra:
    echo %CSC64%
    echo %CSC32%
    exit /b 12
)

echo [INFO] Compiler:
echo %CSC%
echo.

REM =====================================================
REM 3. STOP SERVICE CU
REM =====================================================

sc.exe query "%SERVICE_NAME%" >nul 2>&1

if not errorlevel 1 (
    echo [INFO] Service cu dang ton tai.
    echo [INFO] Dang stop service...

    sc.exe stop "%SERVICE_NAME%" >nul 2>&1

    ping.exe 127.0.0.1 -n 6 >nul

    sc.exe query "%SERVICE_NAME%" | findstr /i "STOPPED" >nul

    if errorlevel 1 (
        echo [WARN] Service chua STOPPED.
        echo [WARN] Thu taskkill process cu...

        taskkill.exe /F /IM QDACleanupService.exe >nul 2>&1

        ping.exe 127.0.0.1 -n 3 >nul
    )
)

REM =====================================================
REM 4. TAO THU MUC
REM =====================================================

if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%" >nul 2>&1
)

if not exist "%INSTALL_DIR%" (
    echo [FAIL] Khong tao duoc:
    echo %INSTALL_DIR%
    exit /b 13
)

if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%" >nul 2>&1
)

if not exist "%LOG_DIR%" (
    echo [FAIL] Khong tao duoc:
    echo %LOG_DIR%
    exit /b 13
)

REM Xoa co cu cua ban pending-cleanup truoc day.
del /f /q "%INSTALL_DIR%\pending_cleanup.flag" >nul 2>&1

REM KHONG xoa recycle_pending.flag.
REM Neu flag nay ton tai thi lan start service tiep theo
REM se tiep tuc empty Recycle Bin.

REM =====================================================
REM 5. COPY CLEANUP PS1
REM =====================================================

echo [1] Copy cleanup PowerShell...

copy /y "%SOURCE_PS1%" "%TARGET_PS1%" >nul

if errorlevel 1 (
    echo [FAIL] Copy cleanup PS1 that bai.
    exit /b 14
)

if not exist "%TARGET_PS1%" (
    echo [FAIL] Khong thay PS1 sau khi copy:
    echo %TARGET_PS1%
    exit /b 14
)

REM =====================================================
REM 6. XOA EXE CU
REM =====================================================

if exist "%SERVICE_EXE%" (
    del /f /q "%SERVICE_EXE%" >nul 2>&1
)

if exist "%SERVICE_EXE%" (
    echo [WARN] EXE cu dang bi khoa.
    echo [WARN] Thu taskkill va xoa lai...

    taskkill.exe /F /IM QDACleanupService.exe >nul 2>&1

    ping.exe 127.0.0.1 -n 3 >nul

    del /f /q "%SERVICE_EXE%" >nul 2>&1
)

if exist "%SERVICE_EXE%" (
    echo [FAIL] Khong xoa duoc EXE cu:
    echo %SERVICE_EXE%
    exit /b 15
)

REM =====================================================
REM 7. COMPILE SERVICE
REM =====================================================

echo [2] Compile QDA Hybrid Windows Service...

"%CSC%" /nologo /target:exe /platform:anycpu /optimize+ /reference:System.dll /out:"%SERVICE_EXE%" "%SOURCE_CS%"

set "COMPILE_CODE=%ERRORLEVEL%"

if not "%COMPILE_CODE%"=="0" (
    echo [FAIL] Compile service that bai.
    echo [FAIL] CSC exit code: %COMPILE_CODE%
    exit /b 15
)

if not exist "%SERVICE_EXE%" (
    echo [FAIL] Service EXE khong duoc tao:
    echo %SERVICE_EXE%
    exit /b 16
)

echo [OK] Compile thanh cong.
echo.

REM =====================================================
REM 8. CREATE HOAC UPDATE SERVICE
REM =====================================================

sc.exe query "%SERVICE_NAME%" >nul 2>&1

if errorlevel 1 (
    echo [3] Create Windows Service...

    sc.exe create "%SERVICE_NAME%" binPath= "\"%SERVICE_EXE%\"" start= auto obj= LocalSystem DisplayName= "%SERVICE_DISPLAY%"

    if errorlevel 1 (
        echo [FAIL] sc.exe create that bai.
        exit /b 17
    )
) else (
    echo [3] Update Windows Service...

    sc.exe config "%SERVICE_NAME%" binPath= "\"%SERVICE_EXE%\"" start= auto obj= LocalSystem DisplayName= "%SERVICE_DISPLAY%"

    if errorlevel 1 (
        echo [FAIL] sc.exe config that bai.
        exit /b 17
    )
)

sc.exe description "%SERVICE_NAME%" "Cleanup Desktop, Downloads and ThiCNTT before shutdown; empty Recycle Bin after next user login." >nul 2>&1

REM =====================================================
REM 9. START SERVICE
REM =====================================================

echo [4] Start service...

sc.exe start "%SERVICE_NAME%" >nul 2>&1

if errorlevel 1 (
    echo [FAIL] sc.exe start that bai.
    echo.

    sc.exe query "%SERVICE_NAME%"

    exit /b 18
)

ping.exe 127.0.0.1 -n 5 >nul

REM =====================================================
REM 10. VERIFY RUNNING
REM =====================================================

sc.exe query "%SERVICE_NAME%" | findstr /i "RUNNING" >nul

if errorlevel 1 (
    echo [FAIL] Service khong o trang thai RUNNING.
    echo.

    sc.exe query "%SERVICE_NAME%"

    echo.
    echo Thu muc log:
    echo %LOG_DIR%

    exit /b 19
)

REM =====================================================
REM 11. VERIFY FILES
REM =====================================================

if not exist "%SERVICE_EXE%" (
    echo [FAIL] Mat service EXE sau khi start.
    exit /b 20
)

if not exist "%TARGET_PS1%" (
    echo [FAIL] Mat cleanup PS1 sau khi start.
    exit /b 21
)

echo.
echo ==========================================
echo             INSTALL SUCCESS
echo ==========================================
echo.
echo [OK] Service:
echo %SERVICE_NAME%
echo.
echo [OK] EXE:
echo %SERVICE_EXE%
echo.
echo [OK] Cleanup PS1:
echo %TARGET_PS1%
echo.
echo [OK] Service log:
echo %LOG_DIR%\service.log
echo.
echo LUONG HOAT DONG:
echo - Shutdown/Restart: don Desktop, Downloads, ThiCNTT
echo - Tao recycle_pending.flag
echo - Lan Windows bat lai: cho user login
echo - Cho explorer.exe va them 10 giay
echo - Empty Recycle Bin bang dung user
echo.

exit /b 0
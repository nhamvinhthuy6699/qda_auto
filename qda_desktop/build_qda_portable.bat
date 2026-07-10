@echo off
title Build QDA Desktop App - UAC Admin
setlocal EnableDelayedExpansion

cd /d "%~dp0"

echo ==========================================
echo        BUILD QDA DESKTOP APP - UAC
echo ==========================================
echo.

set APP_NAME=QDA
set SRC=C:\mywork\qda_desktop\qda_app.py
set OUT=C:\mywork
set ICON=C:\mywork\assets\qda.ico

echo [1] Kiem tra Python...
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [LOI] Khong thay python.
    pause
    exit /b 1
)

echo [2] Kiem tra source...
if not exist "%SRC%" (
    echo [LOI] Khong thay file:
    echo %SRC%
    pause
    exit /b 1
)

echo [3] Kiem tra PyInstaller...
python -m pip show pyinstaller >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Chua co PyInstaller, dang cai...
    python -m pip install pyinstaller
    if %errorlevel% neq 0 (
        echo [LOI] Cai PyInstaller that bai.
        pause
        exit /b 1
    )
)

echo [4] Xoa build cu...
rmdir /s /q build >nul 2>&1
rmdir /s /q dist >nul 2>&1
del /f /q "%APP_NAME%.spec" >nul 2>&1
del /f /q "%OUT%\%APP_NAME%.exe" >nul 2>&1

echo [5] Build QDA.exe co UAC Administrator...
echo.

if exist "%ICON%" (
    python -m PyInstaller ^
        --onefile ^
        --noconsole ^
        --uac-admin ^
        --name "%APP_NAME%" ^
        --icon "%ICON%" ^
        --distpath "%OUT%" ^
        "%SRC%"
) else (
    echo [WARN] Khong thay icon:
    echo %ICON%
    echo [WARN] Build khong icon.

    python -m PyInstaller ^
        --onefile ^
        --noconsole ^
        --uac-admin ^
        --name "%APP_NAME%" ^
        --distpath "%OUT%" ^
        "%SRC%"
)

if %errorlevel% neq 0 (
    echo.
    echo [LOI] Build that bai.
    pause
    exit /b 1
)

echo.
echo [6] Kiem tra ket qua...
if exist "%OUT%\%APP_NAME%.exe" (
    echo [OK] Build thanh cong:
    echo %OUT%\%APP_NAME%.exe
) else (
    echo [LOI] Khong thay file EXE sau build.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo        BUILD FINISHED
echo ==========================================
echo.
echo File app:
echo %OUT%\%APP_NAME%.exe
echo.
echo Luu y:
echo - QDA.exe se tu hoi quyen Administrator khi mo.
echo - Nguoi dung chi can double click QDA.exe.
echo - Khi Windows hien UAC thi bam Yes.
echo - Cac BAT con nhu Import Veyon CSV, shutdown, HP/Dell se ke thua quyen Admin.
echo.
pause
exit /b 0
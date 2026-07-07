@echo off
title Build QDA Portable EXE

cd /d "%~dp0"

echo ==========================================
echo        BUILD QDA PORTABLE EXE
echo ==========================================
echo.

python -m PyInstaller ^
 --onefile ^
 --windowed ^
 --name QDA ^
 qda_app.py

if not exist "%~dp0dist\QDA.exe" (
    echo.
    echo [LOI] Build that bai.
    pause
    exit /b 1
)

copy /y "%~dp0dist\QDA.exe" "%~dp0..\QDA.exe"

echo.
echo ==========================================
echo Build xong.
echo File EXE moi nam tai:
echo %~dp0..\QDA.exe
echo ==========================================
echo.

pause
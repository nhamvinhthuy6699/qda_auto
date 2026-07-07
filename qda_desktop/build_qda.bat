@echo off
title Build QDA Desktop EXE

cd /d C:\mywork\qda_desktop

echo ==========================================
echo        BUILD QDA DESKTOP APP
echo ==========================================
echo.

python -m PyInstaller ^
 --onefile ^
 --windowed ^
 --name QDA ^
 qda_app.py

echo.
echo ==========================================
echo Build xong.
echo File EXE nam tai:
echo C:\mywork\qda_desktop\dist\QDA.exe
echo ==========================================
echo.

pause
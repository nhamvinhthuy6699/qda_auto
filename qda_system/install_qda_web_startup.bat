@echo off
title Install QDA Web Startup

schtasks /create ^
 /tn "QDA Control System Web" ^
 /tr "cmd.exe /c C:\mywork\qda_system\start_qda_app.bat" ^
 /sc onlogon ^
 /rl highest ^
 /f

echo Da tao startup task QDA Control System Web.
pause
@echo off
title Fix WinRAR Right Click Menu

setlocal EnableDelayedExpansion

set LOG=C:\APP_DEPLOY\INSTALL\fix_winrar_right_click_log.txt
set RESULT=C:\APP_DEPLOY\INSTALL\fix_winrar_right_click_result.txt

if not exist C:\APP_DEPLOY\INSTALL mkdir C:\APP_DEPLOY\INSTALL

echo ===== FIX WINRAR RIGHT CLICK MENU ===== > "%LOG%"
echo START %DATE% %TIME% >> "%LOG%"

set WINRAR=C:\Program Files\WinRAR\WinRAR.exe
set RAREXT=C:\Program Files\WinRAR\rarext.dll

echo WINRAR=%WINRAR% >> "%LOG%"
echo RAREXT=%RAREXT% >> "%LOG%"

if not exist "%WINRAR%" (
    echo FAILED WINRAR_NOT_FOUND > "%RESULT%"
    echo FAILED: Khong thay WinRAR.exe >> "%LOG%"
    exit /b 1
)

REM ==================================================
REM 1. Dang ky shell extension cua WinRAR neu co
REM ==================================================
if exist "%RAREXT%" (
    echo Register rarext.dll... >> "%LOG%"
    regsvr32 /s "%RAREXT%" >> "%LOG%" 2>&1
)

REM ==================================================
REM 2. Tao menu chuot phai thu cong cho FILE
REM ==================================================
echo Create right-click menu for files... >> "%LOG%"

reg add "HKCR\*\shell\WinRAR_AddToArchive" /ve /d "Add to archive with WinRAR" /f >> "%LOG%" 2>&1
reg add "HKCR\*\shell\WinRAR_AddToArchive" /v Icon /d "\"%WINRAR%\"" /f >> "%LOG%" 2>&1
reg add "HKCR\*\shell\WinRAR_AddToArchive\command" /ve /d "\"%WINRAR%\" a \"%%1.rar\" \"%%1\"" /f >> "%LOG%" 2>&1

REM ==================================================
REM 3. Tao menu chuot phai thu cong cho FOLDER
REM ==================================================
echo Create right-click menu for folders... >> "%LOG%"

reg add "HKCR\Directory\shell\WinRAR_AddToArchive" /ve /d "Add to archive with WinRAR" /f >> "%LOG%" 2>&1
reg add "HKCR\Directory\shell\WinRAR_AddToArchive" /v Icon /d "\"%WINRAR%\"" /f >> "%LOG%" 2>&1
reg add "HKCR\Directory\shell\WinRAR_AddToArchive\command" /ve /d "\"%WINRAR%\" a \"%%1.rar\" \"%%1\"" /f >> "%LOG%" 2>&1

REM ==================================================
REM 4. Tao menu Extract Here cho file nen pho bien
REM ==================================================
echo Create Extract Here menu... >> "%LOG%"

reg add "HKCR\SystemFileAssociations\.rar\shell\WinRAR_ExtractHere" /ve /d "Extract here with WinRAR" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.rar\shell\WinRAR_ExtractHere" /v Icon /d "\"%WINRAR%\"" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.rar\shell\WinRAR_ExtractHere\command" /ve /d "\"%WINRAR%\" x -y \"%%1\" \"%%~dp1\"" /f >> "%LOG%" 2>&1

reg add "HKCR\SystemFileAssociations\.zip\shell\WinRAR_ExtractHere" /ve /d "Extract here with WinRAR" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.zip\shell\WinRAR_ExtractHere" /v Icon /d "\"%WINRAR%\"" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.zip\shell\WinRAR_ExtractHere\command" /ve /d "\"%WINRAR%\" x -y \"%%1\" \"%%~dp1\"" /f >> "%LOG%" 2>&1

reg add "HKCR\SystemFileAssociations\.7z\shell\WinRAR_ExtractHere" /ve /d "Extract here with WinRAR" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.7z\shell\WinRAR_ExtractHere" /v Icon /d "\"%WINRAR%\"" /f >> "%LOG%" 2>&1
reg add "HKCR\SystemFileAssociations\.7z\shell\WinRAR_ExtractHere\command" /ve /d "\"%WINRAR%\" x -y \"%%1\" \"%%~dp1\"" /f >> "%LOG%" 2>&1

echo SUCCESS WINRAR_RIGHT_CLICK_FIXED > "%RESULT%"
echo SUCCESS: WinRAR right-click menu created. >> "%LOG%"
exit /b 0

@echo off
title Scan Rooms Port 445 To Clients

REM =====================================================
REM CAU HINH NHANH
REM =====================================================

REM IP server dang chay script, se bi loai khoi clients.txt
set IP_SERVER=192.168.24.80

REM Loai tru gateway .1
set EXCLUDE_DOT_ONE=Y

REM Loai tru them IP nao khac, cach nhau bang dau phay
set EXTRA_EXCLUDE_IPS=

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scan_rooms_to_clients.ps1" ^
    -IPServer "%IP_SERVER%" ^
    -ExcludeDotOne "%EXCLUDE_DOT_ONE%" ^
    -ExtraExcludeIPs "%EXTRA_EXCLUDE_IPS%"

pause
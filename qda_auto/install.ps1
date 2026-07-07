$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$SourceRoot = Join-Path $Base "INSTALLERS"
$AppsMenu = Join-Path $Base "apps_menu.txt"

$AdminUser = "admintest"
$AdminPass = "123456"
$Throttle = 40

$DefaultSilentExeArgs = "/S /v/qn"

if (!(Test-Path $Clients)) { Write-Host "[LOI] Khong thay clients.txt"; pause; exit }
if (!(Test-Path $PsExec)) { Write-Host "[LOI] Khong thay PsExec.exe"; pause; exit }
if (!(Test-Path $SourceRoot)) { Write-Host "[LOI] Khong thay folder INSTALLERS"; pause; exit }
if (!(Test-Path $AppsMenu)) { Write-Host "[LOI] Khong thay apps_menu.txt"; pause; exit }

$SupportedTypes = @("EXE","EXE_SILENT","EXE_SEB241","MSI","COPY","FOLDER","BAT","PS1","ZIP","WINGET","APPX","MSIX","APPXBUNDLE","MSIXBUNDLE")
$Apps = @()

Get-Content $AppsMenu | ForEach-Object {
    $Line = $_.Trim()
    if ($Line -eq "" -or $Line.StartsWith("#")) { return }

    $Parts = $Line.Split("|", 5)
    if ($Parts.Count -lt 5) {
        Write-Host "[LOI] Sai format apps_menu.txt:"
        Write-Host $Line
        pause
        exit
    }

    $Id = $Parts[0].Trim()
    $Name = $Parts[1].Trim()
    $Type = $Parts[2].Trim().ToUpper()
    $Source = $Parts[3].Trim()
    $ArgsOrDest = $Parts[4].Trim()

    if ($SupportedTypes -notcontains $Type) {
        Write-Host "[LOI] TYPE khong ho tro: $Type"
        Write-Host "Ho tro: $($SupportedTypes -join ', ')"
        pause
        exit
    }

    $Apps += [PSCustomObject]@{
        Id = $Id
        Name = $Name
        Type = $Type
        Source = $Source
        ArgsOrDest = $ArgsOrDest
    }
}

if ($Apps.Count -eq 0) {
    Write-Host "[LOI] apps_menu.txt chua co tac vu nao."
    pause
    exit
}

Write-Host "=========================================="
Write-Host "              INSTALL MENU"
Write-Host "=========================================="
Write-Host ""
Write-Host "Danh sach tac vu:"
foreach ($App in $Apps) {
    Write-Host "[$($App.Id)] $($App.Name) | $($App.Type) | $($App.Source) | $($App.ArgsOrDest)"
}
Write-Host ""
Write-Host "Nhap ID, vi du: 1 hoac 1,2,3 hoac ALL"
Write-Host ""

$Choice = Read-Host "Nhap lua chon"
$Choice = $Choice.Trim()

$SelectedApps = @()

if ($Choice.ToUpper() -eq "ALL") {
    $SelectedApps = $Apps
}
else {
    $Ids = $Choice.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    foreach ($Id in $Ids) {
        $Found = $Apps | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
        if ($null -eq $Found) {
            Write-Host "[LOI] Khong co ID: $Id"
            pause
            exit
        }
        $SelectedApps += $Found
    }
}

foreach ($App in $SelectedApps) {
    if ($App.Type -ne "WINGET") {
        $LocalSource = Join-Path $SourceRoot $App.Source
        if (!(Test-Path $LocalSource)) {
            Write-Host "[LOI] Khong thay source:"
            Write-Host $LocalSource
            Write-Host "Tac vu: $($App.Name)"
            pause
            exit
        }
    }
}

$Targets = Get-Content $Clients |
    Where-Object { $_.Trim() -ne "" -and !$_.Trim().StartsWith("#") } |
    Sort-Object -Unique

if ($Targets.Count -eq 0) {
    Write-Host "[LOI] clients.txt khong co IP."
    pause
    exit
}

Write-Host ""
Write-Host "=========================================="
Write-Host "              THONG TIN"
Write-Host "=========================================="
Write-Host "So may se xu ly : $($Targets.Count)"
Write-Host "Throttle        : $Throttle"
Write-Host "EXE_SILENT args : $DefaultSilentExeArgs"
Write-Host "Tac vu chon:"
$SelectedApps | ForEach-Object { Write-Host "- $($_.Name) | $($_.Type) | $($_.Source) | $($_.ArgsOrDest)" }
Write-Host ""

$Confirm = Read-Host "Nhap INSTALL de bat dau"
if ($Confirm -ne "INSTALL") { exit }

$SuccessFile = Join-Path $Base "install_success.txt"
$FailedFile = Join-Path $Base "install_failed.txt"

Remove-Item $SuccessFile, $FailedFile -ErrorAction SilentlyContinue

$Jobs = @()
$Results = @()

foreach ($IP in $Targets) {
    while (($Jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Throttle) {
        Start-Sleep -Milliseconds 500
        foreach ($Job in @($Jobs | Where-Object { $_.State -ne "Running" })) {
            $JobResult = Receive-Job $Job
            if ($null -ne $JobResult) { $Results += $JobResult }
            Remove-Job $Job
            $Jobs = $Jobs | Where-Object { $_.Id -ne $Job.Id }
        }
    }

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$SourceRoot,$SelectedApps,$DefaultSilentExeArgs -ScriptBlock {
        param($IP,$AdminUser,$AdminPass,$PsExec,$SourceRoot,$SelectedApps,$DefaultSilentExeArgs)

        function Get-DestPath {
            param($Token, $SourceName)

            if ($Token -eq "" -or $Token.ToUpper() -eq "PUBLIC_DESKTOP") { return "C:\Users\Public\Desktop\$SourceName" }
            if ($Token.ToUpper() -eq "ADMIN_DESKTOP") { return "C:\Users\admin\Desktop\$SourceName" }
            if ($Token.ToUpper() -eq "TTCNTTNN_DESKTOP") { return "C:\Users\TTCNTTNN\Desktop\$SourceName" }
            if ($Token.ToUpper() -eq "TEMP") { return "C:\APP_DEPLOY\INSTALL\$SourceName" }
            return $Token
        }

        try {
            & cmd /c "net use \\$IP\C$ /user:$AdminUser $AdminPass >nul 2>&1"

            if ($LASTEXITCODE -ne 0) {
                return [PSCustomObject]@{IP=$IP;Status="FAILED";Message="C$ FAIL"}
            }

            $RemoteRootUNC = "\\$IP\C$\APP_DEPLOY\INSTALL"
            $RemoteRootLocal = "C:\APP_DEPLOY\INSTALL"
            $RemoteBatUNC = "\\$IP\C$\APP_DEPLOY\INSTALL\install_local.bat"
            $RemoteBatLocal = "C:\APP_DEPLOY\INSTALL\install_local.bat"
            $RemoteLogUNC = "\\$IP\C$\APP_DEPLOY\INSTALL\install_local_log.txt"
            $RemoteResultUNC = "\\$IP\C$\APP_DEPLOY\INSTALL\install_result.txt"

            New-Item -ItemType Directory -Path $RemoteRootUNC -Force | Out-Null
            Remove-Item "$RemoteRootUNC\install_local.bat" -Force -ErrorAction SilentlyContinue
            Remove-Item $RemoteLogUNC,$RemoteResultUNC -Force -ErrorAction SilentlyContinue

            $Bat = @()
            $Bat += "@echo off"
            $Bat += "title Install Local"
            $Bat += "setlocal EnableDelayedExpansion"
            $Bat += "echo ===== INSTALL LOCAL ===== > C:\APP_DEPLOY\INSTALL\install_local_log.txt"
            $Bat += "echo START %DATE% %TIME% >> C:\APP_DEPLOY\INSTALL\install_local_log.txt"
            $Bat += "echo. > C:\APP_DEPLOY\INSTALL\install_result.txt"
            $Bat += "set OVERALL=0"
            $Bat += ""

            foreach ($App in $SelectedApps) {
                $Name = $App.Name
                $Type = $App.Type
                $Source = $App.Source
                $ArgsOrDest = $App.ArgsOrDest
                $SafeLabel = ($Name -replace '[^a-zA-Z0-9]', '_')

                $Bat += "echo ===== TASK $Name / $Type ===== >> C:\APP_DEPLOY\INSTALL\install_local_log.txt"

                if ($Type -eq "WINGET") {
                    $Bat += "where winget >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1"
                    $Bat += "if errorlevel 1 (echo TASK:$Name FAILED WINGET_NOT_FOUND >> C:\APP_DEPLOY\INSTALL\install_result.txt & set OVERALL=1 & goto NEXT_$SafeLabel)"
                    if ($ArgsOrDest -eq "") { $Bat += "winget install --id `"$Source`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    else { $Bat += "winget install --id `"$Source`" $ArgsOrDest >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    $Bat += "set CODE=!ERRORLEVEL!"
                    $Bat += "if !CODE! EQU 0 (echo TASK:$Name SUCCESS CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt) else (echo TASK:$Name FAILED CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt & set OVERALL=1)"
                    $Bat += ":NEXT_$SafeLabel"
                    continue
                }

                $LocalSource = Join-Path $SourceRoot $Source
                $RemoteSourceUNC = Join-Path $RemoteRootUNC $Source
                $RemoteSourceLocal = "$RemoteRootLocal\$Source"

                if ($Type -eq "FOLDER") { Copy-Item $LocalSource $RemoteSourceUNC -Recurse -Force }
                else { Copy-Item $LocalSource $RemoteSourceUNC -Force }

                if ($Type -eq "COPY") {
                    $DestLocal = Get-DestPath $ArgsOrDest $Source
                    $DrivePath = $DestLocal -replace '^C:', "\\$IP\C$"
                    $DestDirUNC = Split-Path $DrivePath -Parent
                    New-Item -ItemType Directory -Path $DestDirUNC -Force | Out-Null
                    Copy-Item $LocalSource $DrivePath -Force
                    $Bat += "echo TASK:$Name SUCCESS COPIED_TO=$DestLocal >> C:\APP_DEPLOY\INSTALL\install_result.txt"
                    $Bat += "goto NEXT_$SafeLabel"
                    $Bat += ":NEXT_$SafeLabel"
                    continue
                }

                if ($Type -eq "FOLDER") {
                    $DestLocal = $ArgsOrDest
                    if ($DestLocal -eq "") { $DestLocal = "C:\APP_DEPLOY\INSTALL\$Source" }
                    $DrivePath = $DestLocal -replace '^C:', "\\$IP\C$"
                    New-Item -ItemType Directory -Path (Split-Path $DrivePath -Parent) -Force | Out-Null
                    Remove-Item $DrivePath -Recurse -Force -ErrorAction SilentlyContinue
                    Copy-Item $LocalSource $DrivePath -Recurse -Force
                    $Bat += "echo TASK:$Name SUCCESS FOLDER_COPIED_TO=$DestLocal >> C:\APP_DEPLOY\INSTALL\install_result.txt"
                    $Bat += "goto NEXT_$SafeLabel"
                    $Bat += ":NEXT_$SafeLabel"
                    continue
                }

                if ($Type -eq "ZIP") {
                    $DestLocal = $ArgsOrDest
                    if ($DestLocal -eq "") { $DestLocal = "C:\APP_DEPLOY\INSTALL\UNZIP_$SafeLabel" }
                    $Bat += "powershell -NoProfile -ExecutionPolicy Bypass -Command `"New-Item -ItemType Directory -Path '$DestLocal' -Force | Out-Null; Expand-Archive -Path '$RemoteSourceLocal' -DestinationPath '$DestLocal' -Force`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1"
                    $Bat += "set CODE=!ERRORLEVEL!"
                    $Bat += "if !CODE! EQU 0 (echo TASK:$Name SUCCESS UNZIPPED_TO=$DestLocal >> C:\APP_DEPLOY\INSTALL\install_result.txt) else (echo TASK:$Name FAILED CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt & set OVERALL=1)"
                    $Bat += "goto NEXT_$SafeLabel"
                    $Bat += ":NEXT_$SafeLabel"
                    continue
                }

                if ($Type -eq "EXE_SILENT" -or $Type -eq "EXE_SEB241") {
                    $Bat += "`"$RemoteSourceLocal`" $DefaultSilentExeArgs >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1"
                    $Bat += "set CODE=!ERRORLEVEL!"

                    if ($Type -eq "EXE_SEB241") {
                        $Bat += "timeout /t 10 /nobreak >nul"
                        $Bat += "powershell -NoProfile -ExecutionPolicy Bypass -Command `"if (Get-ChildItem 'C:\Program Files','C:\Program Files (x86)' -Filter SafeExamBrowser.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) { exit 0 } else { exit 1 }`""
                        $Bat += "set CHECK=!ERRORLEVEL!"
                        $Bat += "if !CHECK! EQU 0 ("
                        $Bat += "  echo TASK:$Name SUCCESS SEB_INSTALLED CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt"
                        $Bat += ") else ("
                        $Bat += "  echo TASK:$Name FAILED SEB_NOT_FOUND CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt"
                        $Bat += "  set OVERALL=1"
                        $Bat += ")"
                        $Bat += "goto NEXT_$SafeLabel"
                        $Bat += ":NEXT_$SafeLabel"
                        continue
                    }
                }
                elseif ($Type -eq "MSI") {
                    if ($ArgsOrDest -eq "") { $Bat += "msiexec /i `"$RemoteSourceLocal`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    else { $Bat += "msiexec /i `"$RemoteSourceLocal`" $ArgsOrDest >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    $Bat += "set CODE=!ERRORLEVEL!"
                }
                elseif ($Type -eq "EXE") {
                    if ($ArgsOrDest -eq "") { $Bat += "`"$RemoteSourceLocal`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    else { $Bat += "`"$RemoteSourceLocal`" $ArgsOrDest >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    $Bat += "set CODE=!ERRORLEVEL!"
                }
                elseif ($Type -eq "BAT") {
                    if ($ArgsOrDest -eq "") { $Bat += "cmd /c `"$RemoteSourceLocal`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    else { $Bat += "cmd /c `"$RemoteSourceLocal`" $ArgsOrDest >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    $Bat += "set CODE=!ERRORLEVEL!"
                }
                elseif ($Type -eq "PS1") {
                    if ($ArgsOrDest -eq "") { $Bat += "powershell -NoProfile -ExecutionPolicy Bypass -File `"$RemoteSourceLocal`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    else { $Bat += "powershell -NoProfile -ExecutionPolicy Bypass -File `"$RemoteSourceLocal`" $ArgsOrDest >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1" }
                    $Bat += "set CODE=!ERRORLEVEL!"
                }
                elseif ($Type -eq "APPX" -or $Type -eq "MSIX" -or $Type -eq "APPXBUNDLE" -or $Type -eq "MSIXBUNDLE") {
                    $Bat += "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Add-AppxPackage -Path '$RemoteSourceLocal'`" >> C:\APP_DEPLOY\INSTALL\install_local_log.txt 2>&1"
                    $Bat += "set CODE=!ERRORLEVEL!"
                }
                else {
                    $Bat += "echo TASK:$Name FAILED UNKNOWN_TYPE=$Type >> C:\APP_DEPLOY\INSTALL\install_result.txt"
                    $Bat += "set OVERALL=1"
                    $Bat += "goto NEXT_$SafeLabel"
                    $Bat += ":NEXT_$SafeLabel"
                    continue
                }

                $Bat += "if !CODE! EQU 0 (echo TASK:$Name SUCCESS CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt) else if !CODE! EQU 3010 (echo TASK:$Name SUCCESS_REBOOT_REQUIRED CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt) else (echo TASK:$Name FAILED CODE=!CODE! >> C:\APP_DEPLOY\INSTALL\install_result.txt & set OVERALL=1)"
                $Bat += ":NEXT_$SafeLabel"
            }

            $Bat += "echo END %DATE% %TIME% >> C:\APP_DEPLOY\INSTALL\install_local_log.txt"
            $Bat += "if %OVERALL% EQU 0 (echo FINAL:SUCCESS >> C:\APP_DEPLOY\INSTALL\install_result.txt) else (echo FINAL:FAILED >> C:\APP_DEPLOY\INSTALL\install_result.txt)"
            $Bat += "exit /b %OVERALL%"

            Set-Content -Path $RemoteBatUNC -Value $Bat -Encoding ASCII -Force

            & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner cmd /c $RemoteBatLocal 2>$null
            $PsExecCode = $LASTEXITCODE

            $Waited = 0
            while (!(Test-Path $RemoteResultUNC) -and $Waited -lt 1800) {
                Start-Sleep -Seconds 5
                $Waited += 5
            }

            if (!(Test-Path $RemoteResultUNC)) {
                & cmd /c "net use \\$IP\C$ /delete >nul 2>&1"
                return [PSCustomObject]@{IP=$IP;Status="FAILED";Message="NO RESULT FILE / PsExec code $PsExecCode"}
            }

            $ResultLines = Get-Content $RemoteResultUNC -ErrorAction SilentlyContinue
$FinalLine = ($ResultLines | Where-Object { $_ -like "FINAL:*" } | Select-Object -Last 1)
$ResultText = ($ResultLines | Where-Object { $_ -like "TASK:*" }) -join " | "

$LogText = ""
if (Test-Path $RemoteLogUNC) {
    $LogText = (Get-Content $RemoteLogUNC -ErrorAction SilentlyContinue | Select-Object -Last 14) -join " | "
}

$OfficeResultUNC = "\\$IP\C$\APP_DEPLOY\INSTALL\office2016_install_result.txt"
$OfficeLogUNC    = "\\$IP\C$\APP_DEPLOY\INSTALL\office2016_install_log.txt"

if (Test-Path $OfficeResultUNC) {
    $OfficeResult = (Get-Content $OfficeResultUNC -ErrorAction SilentlyContinue) -join " | "
    if ($OfficeResult -ne "") {
        $ResultText = "$ResultText | OFFICE2016_RESULT: $OfficeResult"
    }
}

if (Test-Path $OfficeLogUNC) {
    $OfficeLogTail = (Get-Content $OfficeLogUNC -ErrorAction SilentlyContinue | Select-Object -Last 20) -join " | "
    if ($OfficeLogTail -ne "") {
        $LogText = "$LogText | OFFICE2016_LOG: $OfficeLogTail"
    }
}

            & cmd /c "net use \\$IP\C$ /delete >nul 2>&1"

            if ($FinalLine -like "FINAL:SUCCESS*") {
                return [PSCustomObject]@{IP=$IP;Status="SUCCESS";Message=$ResultText}
            }

            return [PSCustomObject]@{IP=$IP;Status="FAILED";Message="$ResultText | $LogText"}

        } catch {
            return [PSCustomObject]@{IP=$IP;Status="FAILED";Message=$_.Exception.Message}
        }
    }
}

foreach ($Job in $Jobs) {
    Wait-Job $Job | Out-Null
    $JobResult = Receive-Job $Job
    if ($null -ne $JobResult) { $Results += $JobResult }
    Remove-Job $Job
}

$SuccessResults = $Results | Where-Object { $_.Status -eq "SUCCESS" }
$FailedResults = $Results | Where-Object { $_.Status -eq "FAILED" }

$SuccessResults | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $SuccessFile
$FailedResults | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $FailedFile

Write-Host ""
Write-Host "=========================================="
Write-Host "              KET QUA INSTALL"
Write-Host "=========================================="
Write-Host "Thanh cong: $($SuccessResults.Count)"
Write-Host "That bai  : $($FailedResults.Count)"
Write-Host ""

$SuccessResults | ForEach-Object { Write-Host "[OK] $($_.IP) - $($_.Message)" }
$FailedResults | ForEach-Object { Write-Host "[FAIL] $($_.IP) - $($_.Message)" }

Write-Host ""
Write-Host "File thanh cong: $SuccessFile"
Write-Host "File that bai  : $FailedFile"
pause

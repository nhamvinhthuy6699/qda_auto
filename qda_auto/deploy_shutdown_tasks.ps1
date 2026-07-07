$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalScript = Join-Path $Base "shutdown_tasks_local.bat"

$AdminUser = "admintest"
$AdminPass = "123456"
$Throttle = 30

if (!(Test-Path $Clients)) {
    Write-Host "[LOI] Khong thay clients.txt"
    pause
    exit
}

if (!(Test-Path $PsExec)) {
    Write-Host "[LOI] Khong thay PsExec.exe"
    pause
    exit
}

if (!(Test-Path $LocalScript)) {
    Write-Host "[LOI] Khong thay shutdown_tasks_local.bat"
    pause
    exit
}

Write-Host "=========================================="
Write-Host "        QDA ROOM CONTROL / SHUTDOWN"
Write-Host "=========================================="
Write-Host ""
Write-Host "Chon tac vu can chay:"
Write-Host ""
Write-Host "1) Kill SEB/QDA + reset policy"
Write-Host "2) Xoa lich tu bat may trong BIOS HP/Dell"
Write-Host "3) Tat QDA/SEB/BQP khoi dong cung Windows"
Write-Host "4) BAT che do thi - AN/CHAN o C va TU RESTART"
Write-Host "5) TAT che do thi - HIEN LAI o C va TU RESTART"
Write-Host "6) Shutdown may"
Write-Host ""
Write-Host "Vi du:"
Write-Host "  4       = An o C va restart"
Write-Host "  5       = Hien lai o C va restart"
Write-Host "  1,3,6   = Kill/reset + tat startup + shutdown"
Write-Host "  A       = All cleanup + shutdown, tuong duong 1,2,3,6"
Write-Host ""

$ChoiceInput = Read-Host "Nhap lua chon"

$ChoiceInput = $ChoiceInput.Trim().ToUpper()

if ($ChoiceInput -eq "") {
    Write-Host "[LOI] Ban chua nhap lua chon."
    pause
    exit
}

# Mac dinh tat het
$KillApp = "N"
$ClearBios = "N"
$DisableStartup = "N"
$HideC = "N"
$ShowC = "N"
$DoRestart = "N"
$DoShutdown = "N"

# A / ALL = cleanup + shutdown, khong bao gom 4/5 vi 4 va 5 la 2 che do nguoc nhau
if ($ChoiceInput -eq "A" -or $ChoiceInput -eq "ALL") {
    $Selected = @("1", "2", "3", "6")
} else {
    $Selected = $ChoiceInput.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique
}

# Kiem tra lua chon hop le
foreach ($Item in $Selected) {
    if ($Item -notin @("1", "2", "3", "4", "5", "6")) {
        Write-Host "[LOI] Lua chon khong hop le: $Item"
        pause
        exit
    }
}

# Khong cho chon dong thoi 4 va 5
if (($Selected -contains "4") -and ($Selected -contains "5")) {
    Write-Host "[LOI] Khong duoc chon dong thoi 4 va 5."
    Write-Host "4 la AN o C, 5 la HIEN lai o C. Hay chon 1 trong 2."
    pause
    exit
}

# Khong cho vua restart do 4/5 vua shutdown
if ((($Selected -contains "4") -or ($Selected -contains "5")) -and ($Selected -contains "6")) {
    Write-Host "[LOI] Khong duoc chon 4/5 chung voi 6."
    Write-Host "4/5 da tu restart may. Neu muon shutdown thi chi chon 6."
    pause
    exit
}

if ($Selected -contains "1") { $KillApp = "Y" }
if ($Selected -contains "2") { $ClearBios = "Y" }
if ($Selected -contains "3") { $DisableStartup = "Y" }

if ($Selected -contains "4") {
    $HideC = "Y"
    $DoRestart = "Y"
}

if ($Selected -contains "5") {
    $ShowC = "Y"
    $DoRestart = "Y"
}

if ($Selected -contains "6") {
    $DoShutdown = "Y"
}

$Targets = Get-Content $Clients |
    Where-Object { $_.Trim() -ne "" -and !$_.Trim().StartsWith("#") } |
    Sort-Object -Unique

Write-Host ""
Write-Host "=========================================="
Write-Host "             THONG TIN CHAY"
Write-Host "=========================================="
Write-Host "So may      : $($Targets.Count)"
Write-Host "Lua chon    : $($Selected -join ',')"
Write-Host "Kill app    : $KillApp"
Write-Host "Clear BIOS  : $ClearBios"
Write-Host "Startup off : $DisableStartup"
Write-Host "Hide C      : $HideC"
Write-Host "Show C      : $ShowC"
Write-Host "Auto Restart: $DoRestart"
Write-Host "Shutdown    : $DoShutdown"
Write-Host "Throttle    : $Throttle"
Write-Host ""

$Confirm = Read-Host "Nhap Y de chay"
if ($Confirm -ne "Y") {
    exit
}

$SuccessFile = Join-Path $Base "shutdown_tasks_success.txt"
$FailedFile = Join-Path $Base "shutdown_tasks_failed.txt"

Remove-Item $SuccessFile, $FailedFile -ErrorAction SilentlyContinue

$Jobs = @()
$Results = @()

foreach ($IP in $Targets) {
    Write-Host "[RUN] Dang gui task toi $IP ..."

    while (($Jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Throttle) {
        Start-Sleep -Milliseconds 500

        $DoneJobs = $Jobs | Where-Object { $_.State -ne "Running" }

        foreach ($Job in $DoneJobs) {
            $JobResult = Receive-Job $Job

            if ($null -ne $JobResult) {
                $Results += $JobResult

                if ($JobResult.Status -eq "SUCCESS") {
                    Write-Host "[OK] $($JobResult.IP) - $($JobResult.Message)"
                } else {
                    Write-Host "[FAIL] $($JobResult.IP) - $($JobResult.Message)"
                }
            }

            Remove-Job $Job
            $Jobs = $Jobs | Where-Object { $_.Id -ne $Job.Id }
        }
    }

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$LocalScript,$KillApp,$ClearBios,$DisableStartup,$HideC,$ShowC,$DoRestart,$DoShutdown -ScriptBlock {
        param(
            $IP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalScript,
            $KillApp,
            $ClearBios,
            $DisableStartup,
            $HideC,
            $ShowC,
            $DoRestart,
            $DoShutdown
        )

        try {
            # FAST MODE: chi restart/shutdown, khong can copy BAT
            if (
                ($DoShutdown -eq "Y" -or $DoRestart -eq "Y") -and
                $KillApp -ne "Y" -and
                $ClearBios -ne "Y" -and
                $DisableStartup -ne "Y" -and
                $HideC -ne "Y" -and
                $ShowC -ne "Y"
            ) {
                if ($DoRestart -eq "Y") {
                    & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -d -accepteula -nobanner shutdown /r /f /t 0 2>$null
                    $ActionName = "FAST RESTART"
                } else {
                    & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -d -accepteula -nobanner shutdown /s /f /t 0 2>$null
                    $ActionName = "FAST SHUTDOWN"
                }

                $PsExecCode = $LASTEXITCODE

                return [PSCustomObject]@{
                    IP = $IP
                    Status = "SUCCESS"
                    Message = "$ActionName SENT / PsExec code $PsExecCode"
                }
            }

            # NORMAL MODE
            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"
            & cmd /c "net use \\$IP\C$ /user:$AdminUser $AdminPass >nul 2>&1"

            if ($LASTEXITCODE -ne 0) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "C$ FAIL"
                }
            }

            $RemoteDir = "\\$IP\C$\APP_DEPLOY\SHUTDOWN"
            $RemoteBatUNC = "\\$IP\C$\APP_DEPLOY\SHUTDOWN\shutdown_tasks_local.bat"
            $RemoteBatLocal = "C:\APP_DEPLOY\SHUTDOWN\shutdown_tasks_local.bat"

            New-Item -ItemType Directory -Path $RemoteDir -Force | Out-Null

            Remove-Item $RemoteBatUNC -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\shutdown_tasks_result.txt" -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\shutdown_tasks_log.txt" -Force -ErrorAction SilentlyContinue

            Copy-Item $LocalScript $RemoteBatUNC -Force

            $RemoteCmd = "`"$RemoteBatLocal`" $KillApp $ClearBios $DisableStartup $HideC $ShowC $DoRestart $DoShutdown"

            if ($DoShutdown -eq "Y" -or $DoRestart -eq "Y") {
                & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -d -accepteula -nobanner cmd /c $RemoteCmd 2>$null
            } else {
                & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner cmd /c $RemoteCmd 2>$null
            }

            $PsExecCode = $LASTEXITCODE

            if ($DoShutdown -eq "Y" -or $DoRestart -eq "Y") {
                Start-Sleep -Seconds 8

                $PingAlive = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue

                & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

                if ($DoRestart -eq "Y") {
                    $PowerAction = "RESTART"
                } else {
                    $PowerAction = "SHUTDOWN"
                }

                if ($PingAlive -eq $false) {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "$PowerAction OK - may da mat ping / PsExec code $PsExecCode"
                    }
                } else {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "DA GUI LENH $PowerAction - may con ping, co the dang xu ly / PsExec code $PsExecCode"
                    }
                }
            }

            $ResultPath = "\\$IP\C$\shutdown_tasks_result.txt"
            $LogPath = "\\$IP\C$\shutdown_tasks_log.txt"

            $Waited = 0

            while (!(Test-Path $ResultPath) -and $Waited -lt 90) {
                Start-Sleep -Seconds 2
                $Waited += 2
            }

            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

            if (!(Test-Path $ResultPath)) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "NO RESULT FILE / PsExec code $PsExecCode"
                }
            }

            $ResultText = ((Get-Content $ResultPath -ErrorAction SilentlyContinue | Select-Object -First 1) -join "").Trim()

            $LogText = ""
            if (Test-Path $LogPath) {
                $LogText = (Get-Content $LogPath -ErrorAction SilentlyContinue | Select-Object -Last 14) -join " | "
            }

            Remove-Item "\\$IP\C$\shutdown_tasks_log.txt" -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\shutdown_tasks_result.txt" -Force -ErrorAction SilentlyContinue

            if ($ResultText -like "SUCCESS*") {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "SUCCESS"
                    Message = "OK | $LogText"
                }
            } else {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "$ResultText | $LogText"
                }
            }
        } catch {
            return [PSCustomObject]@{
                IP = $IP
                Status = "FAILED"
                Message = $_.Exception.Message
            }
        }
    }
}

foreach ($Job in $Jobs) {
    Wait-Job $Job | Out-Null

    $JobResult = Receive-Job $Job

    if ($null -ne $JobResult) {
        $Results += $JobResult

        if ($JobResult.Status -eq "SUCCESS") {
            Write-Host "[OK] $($JobResult.IP) - $($JobResult.Message)"
        } else {
            Write-Host "[FAIL] $($JobResult.IP) - $($JobResult.Message)"
        }
    }

    Remove-Job $Job
}

$SuccessResults = $Results | Where-Object { $_.Status -eq "SUCCESS" }
$FailedResults = $Results | Where-Object { $_.Status -eq "FAILED" }

$SuccessResults | ForEach-Object { $_.IP } | Set-Content $SuccessFile
$FailedResults | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $FailedFile

Write-Host ""
Write-Host "=========================================="
Write-Host "        KET QUA QDA ROOM CONTROL"
Write-Host "=========================================="
Write-Host "Thanh cong: $($SuccessResults.Count)"
Write-Host "That bai  : $($FailedResults.Count)"
Write-Host ""
Write-Host "File thanh cong: $SuccessFile"
Write-Host "File that bai  : $FailedFile"

pause
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalScript = Join-Path $Base "shutdown_tasks_local.bat"

$AdminUser = "admintest"
$AdminPass = "123456"
$Throttle = 30

if (!(Test-Path $Clients)) {
    Write-Host "[LOI] Khong thay clients.txt"
    exit 1
}

if (!(Test-Path $PsExec)) {
    Write-Host "[LOI] Khong thay PsExec.exe"
    exit 1
}

if (!(Test-Path $LocalScript)) {
    Write-Host "[LOI] Khong thay shutdown_tasks_local.bat"
    exit 1
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
Write-Host "4) Shutdown may"
Write-Host ""
Write-Host "Vi du:"
Write-Host "  1       = Chi kill SEB/QDA + reset policy"
Write-Host "  1,3     = Kill/reset + tat startup"
Write-Host "  4       = Shutdown may"
Write-Host "  A       = All cleanup + shutdown, tuong duong 1,2,3,4"
Write-Host ""

$ChoiceInput = Read-Host "Nhap lua chon"
$ChoiceInput = $ChoiceInput.Trim().ToUpper()

if ($ChoiceInput -eq "") {
    Write-Host "[LOI] Ban chua nhap lua chon."
    exit 1
}

$KillApp = "N"
$ClearBios = "N"
$DisableStartup = "N"
$DoShutdown = "N"

if ($ChoiceInput -eq "A" -or $ChoiceInput -eq "ALL") {
    $Selected = @("1", "2", "3", "4")
} else {
    $Selected = $ChoiceInput.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique
}

foreach ($Item in $Selected) {
    if ($Item -notin @("1", "2", "3", "4")) {
        Write-Host "[LOI] Lua chon khong hop le: $Item"
        Write-Host "Chi duoc chon: 1, 2, 3, 4 hoac A"
        exit 1
    }
}

if ($Selected -contains "1") { $KillApp = "Y" }
if ($Selected -contains "2") { $ClearBios = "Y" }
if ($Selected -contains "3") { $DisableStartup = "Y" }
if ($Selected -contains "4") { $DoShutdown = "Y" }

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
Write-Host "Shutdown    : $DoShutdown"
Write-Host "Throttle    : $Throttle"
Write-Host ""

$Confirm = Read-Host "Nhap Y de chay"
if ($Confirm -ne "Y") {
    exit 0
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

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$LocalScript,$KillApp,$ClearBios,$DisableStartup,$DoShutdown -ScriptBlock {
        param(
            $IP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalScript,
            $KillApp,
            $ClearBios,
            $DisableStartup,
            $DoShutdown
        )

        try {
            # FAST MODE: neu chi shutdown thi khong copy file local
            if (
                $DoShutdown -eq "Y" -and
                $KillApp -ne "Y" -and
                $ClearBios -ne "Y" -and
                $DisableStartup -ne "Y"
            ) {
                & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -d -accepteula -nobanner shutdown /s /f /t 0 2>$null
                $PsExecCode = $LASTEXITCODE

                Start-Sleep -Seconds 3
                $PingAlive = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue

                if ($PingAlive -eq $false) {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "FAST SHUTDOWN OK - may da mat ping / PsExec code $PsExecCode"
                    }
                } else {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "FAST SHUTDOWN SENT - may con ping, co the dang tat cham / PsExec code $PsExecCode"
                    }
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

            $RemoteCmd = "`"$RemoteBatLocal`" $KillApp $ClearBios $DisableStartup $DoShutdown"

            if ($DoShutdown -eq "Y") {
                & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -d -accepteula -nobanner cmd /c $RemoteCmd 2>$null
            } else {
                & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner cmd /c $RemoteCmd 2>$null
            }

            $PsExecCode = $LASTEXITCODE

            if ($DoShutdown -eq "Y") {
                Start-Sleep -Seconds 8

                $PingAlive = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue

                & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

                if ($PingAlive -eq $false) {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "SHUTDOWN OK - may da mat ping / PsExec code $PsExecCode"
                    }
                } else {
                    return [PSCustomObject]@{
                        IP = $IP
                        Status = "SUCCESS"
                        Message = "DA GUI LENH SHUTDOWN - may con ping, co the dang tat cham / PsExec code $PsExecCode"
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
Write-Host ""

if ($FailedResults.Count -gt 0) {
    Write-Host "========== DANH SACH THAT BAI =========="
    $FailedResults | ForEach-Object {
        Write-Host "[FAIL] $($_.IP) - $($_.Message)"
    }
    Write-Host "========================================"
    Write-Host ""
}

exit 0
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalScript = Join-Path $Base "exam_mode_local.bat"
$CleanupSilent = Join-Path $Base "cleanup_exam_all_silent.bat"

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
    Write-Host "[CANH BAO] Khong thay cleanup_exam_all_silent.bat"
    Write-Host "[LOI] Khong thay exam_mode_local.bat"
    exit 1
}

Write-Host "=========================================="
Write-Host "              QDA EXAM MODE"
Write-Host "=========================================="
Write-Host ""
Write-Host "Chon che do:"
Write-Host ""
Write-Host "1) BAT che do thi"
Write-Host "   - An/chan o C"
Write-Host "   - Tat Wi-Fi"
Write-Host "   - Khong dung LAN/Ethernet"
Write-Host "   - Restart may"
Write-Host ""
Write-Host "2) TAT che do thi"
Write-Host "   - Hien lai o C"
Write-Host "   - Bat lai Wi-Fi"
Write-Host "   - Khong dung LAN/Ethernet"
Write-Host "   - Restart may"
Write-Host ""

$Mode = Read-Host "Nhap lua chon 1 hoac 2"
$Mode = $Mode.Trim()

if ($Mode -ne "1" -and $Mode -ne "2") {
    Write-Host "[LOI] Lua chon khong hop le. Chi nhap 1 hoac 2."
    exit 1
}

$Targets = Get-Content $Clients |
    Where-Object { $_.Trim() -ne "" -and !$_.Trim().StartsWith("#") } |
    Sort-Object -Unique

Write-Host ""
Write-Host "=========================================="
Write-Host "             THONG TIN CHAY"
Write-Host "=========================================="
Write-Host "So may   : $($Targets.Count)"
Write-Host "Lua chon : $Mode"

if ($Mode -eq "1") {
    Write-Host "Che do   : BAT che do thi - An C + Tat Wi-Fi + Restart"
} else {
    Write-Host "Che do   : TAT che do thi - Hien C + Bat Wi-Fi + Restart"
}

Write-Host "Throttle : $Throttle"
Write-Host ""

$Confirm = Read-Host "Nhap Y de chay"
if ($Confirm -ne "Y") {
    exit 0
}
# =====================================================
# Neu TAT che do thi thi cleanup theo throttle truoc
# Cleanup phai xong TOAN BO roi moi tiep tuc tat exam mode
# =====================================================
if ($Mode -eq "2") {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "   CLEANUP DESKTOP / DOWNLOADS TRUOC KHI TAT CHE DO THI"
    Write-Host "=========================================="
    Write-Host ""

    $CleanupSilent = Join-Path $Base "cleanup_exam_all_silent.bat"

    if (!(Test-Path $CleanupSilent)) {
        Write-Host "[LOI] Khong thay cleanup_exam_all_silent.bat"
        Write-Host "Khong the cleanup truoc khi tat che do thi."
        exit 1
    }

    & cmd /c "`"$CleanupSilent`""
    $CleanupCode = $LASTEXITCODE

    Write-Host ""
    Write-Host "Cleanup exit code: $CleanupCode"
    Write-Host ""

    if ($CleanupCode -ne 0) {
        Write-Host "[CANH BAO] Cleanup co may that bai."
        Write-Host "File that bai:"
        Write-Host (Join-Path $Base "cleanup_exam_silent_failed.txt")
        Write-Host ""

        $ContinueAfterCleanup = Read-Host "Van tiep tuc TAT che do thi? Nhap Y de tiep tuc"

        if ($ContinueAfterCleanup -ne "Y") {
            Write-Host "[HUY] Dung lai do cleanup chua thanh cong het."
            exit 1
        }
    }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "   CLEANUP DA XONG - BAT DAU TAT CHE DO THI"
    Write-Host "=========================================="
    Write-Host ""
}

$SuccessFile = Join-Path $Base "exam_mode_success.txt"
$FailedFile = Join-Path $Base "exam_mode_failed.txt"

Remove-Item $SuccessFile, $FailedFile -ErrorAction SilentlyContinue

$Jobs = @()
$Results = @()

foreach ($IP in $Targets) {
    Write-Host "[RUN] Dang gui exam mode toi $IP ..."

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

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$LocalScript,$Mode -ScriptBlock {
        param(
            $IP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalScript,
            $Mode
        )

        try {
            if ($Mode -eq "1") {
                $ActionName = "ENABLE EXAM MODE"
            } else {
                $ActionName = "DISABLE EXAM MODE"
            }

            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"
            & cmd /c "net use \\$IP\C$ /user:$AdminUser $AdminPass >nul 2>&1"

            if ($LASTEXITCODE -ne 0) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "C$ FAIL"
                }
            }

            $RemoteDir = "\\$IP\C$\APP_DEPLOY\EXAM_MODE"
            $RemoteBatUNC = "\\$IP\C$\APP_DEPLOY\EXAM_MODE\exam_mode_local.bat"
            $RemoteBatLocal = "C:\APP_DEPLOY\EXAM_MODE\exam_mode_local.bat"

            New-Item -ItemType Directory -Path $RemoteDir -Force | Out-Null

            Remove-Item $RemoteBatUNC -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\exam_mode_result.txt" -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\exam_mode_log.txt" -Force -ErrorAction SilentlyContinue

            Copy-Item $LocalScript $RemoteBatUNC -Force

            $RemoteCmd = "`"$RemoteBatLocal`" $Mode"

            # Khong dung -d o day.
            # Cho local script tao result truoc.
            & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner cmd /c $RemoteCmd 2>$null
            $PsExecCode = $LASTEXITCODE

            $ResultPath = "\\$IP\C$\exam_mode_result.txt"
            $LogPath = "\\$IP\C$\exam_mode_log.txt"

            $Waited = 0

            while (!(Test-Path $ResultPath) -and $Waited -lt 60) {
                Start-Sleep -Seconds 2
                $Waited += 2
            }

            $LogText = ""
            if (Test-Path $LogPath) {
                $LogText = (Get-Content $LogPath -ErrorAction SilentlyContinue | Select-Object -Last 25) -join " | "
            }

            if (!(Test-Path $ResultPath)) {
                & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "$ActionName CHUA HOAN THANH - khong thay C:\exam_mode_result.txt sau 60 giay / PsExec code $PsExecCode | $LogText"
                }
            }

            $ResultText = ((Get-Content $ResultPath -ErrorAction SilentlyContinue | Select-Object -First 1) -join "").Trim()

            if ($ResultText -notlike "SUCCESS*") {
                & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "$ActionName FAILED - Result=$ResultText / PsExec code $PsExecCode | $LogText"
                }
            }

            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

            return [PSCustomObject]@{
                IP = $IP
                Status = "SUCCESS"
                Message = "$ActionName OK - da cau hinh xong local, client se tu tat/bat Wi-Fi va restart | $LogText"
            }

        } catch {
            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

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
Write-Host "            KET QUA QDA EXAM MODE"
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
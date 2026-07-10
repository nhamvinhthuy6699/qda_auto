$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalCleanupScript = Join-Path $Base "cleanup_exam_remote_client.ps1"

$AdminUser = "admintest"
$AdminPass = "123456"

# So may cleanup song song toi da
$Throttle = 20

# Cleanup khong shutdown rieng o day
$ShutdownAfterClean = "N"

$SuccessFile = Join-Path $Base "cleanup_exam_silent_success.txt"
$FailedFile = Join-Path $Base "cleanup_exam_silent_failed.txt"
$LogFile = Join-Path $Base "cleanup_exam_silent_log.txt"

"===== QDA CLEANUP EXAM SILENT THROTTLE =====" | Set-Content $LogFile
"START $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile
"BASE=$Base" | Add-Content $LogFile
"CLIENTS=$Clients" | Add-Content $LogFile
"ADMINUSER=$AdminUser" | Add-Content $LogFile
"THROTTLE=$Throttle" | Add-Content $LogFile
"SHUTDOWN_AFTER_CLEAN=$ShutdownAfterClean" | Add-Content $LogFile
"" | Add-Content $LogFile

if (!(Test-Path $Clients)) {
    Write-Host "[LOI] Khong thay clients.txt"
    "[LOI] Khong thay clients.txt" | Add-Content $LogFile
    exit 1
}

if (!(Test-Path $PsExec)) {
    Write-Host "[LOI] Khong thay PsExec.exe"
    "[LOI] Khong thay PsExec.exe" | Add-Content $LogFile
    exit 1
}

if (!(Test-Path $LocalCleanupScript)) {
    Write-Host "[LOI] Khong thay cleanup_exam_remote_client.ps1"
    "[LOI] Khong thay cleanup_exam_remote_client.ps1" | Add-Content $LogFile
    exit 1
}

Remove-Item $SuccessFile, $FailedFile -ErrorAction SilentlyContinue

$Targets = Get-Content $Clients |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" -and !$_.StartsWith("#") } |
    Sort-Object -Unique

Write-Host "=========================================="
Write-Host "     QDA CLEANUP EXAM SILENT THROTTLE"
Write-Host "=========================================="
Write-Host ""
Write-Host "So may   : $($Targets.Count)"
Write-Host "Throttle : $Throttle"
Write-Host ""
Write-Host "Client se duoc don dep..."
Write-Host ""

$Jobs = @()
$Results = @()

foreach ($IP in $Targets) {
    Write-Host "[QUEUE] Cleanup $IP ..."

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

                "[$($JobResult.Status)] $($JobResult.IP) - $($JobResult.Message)" | Add-Content $LogFile
            }

            Remove-Job $Job
            $Jobs = $Jobs | Where-Object { $_.Id -ne $Job.Id }
        }
    }

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$LocalCleanupScript,$ShutdownAfterClean -ScriptBlock {
        param(
            $IP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalCleanupScript,
            $ShutdownAfterClean
        )

        try {
            $RemoteDirUNC = "\\$IP\C$\Windows\Temp\QDA_CLEANUP"
            $RemotePs1UNC = "\\$IP\C$\Windows\Temp\QDA_CLEANUP\cleanup_exam_remote_client.ps1"
            $RemotePs1Local = "C:\Windows\Temp\QDA_CLEANUP\cleanup_exam_remote_client.ps1"

            ping -n 1 -w 1000 $IP | Out-Null

            if ($LASTEXITCODE -ne 0) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "Ping failed"
                }
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

            New-Item -ItemType Directory -Path $RemoteDirUNC -Force | Out-Null

            Copy-Item $LocalCleanupScript $RemotePs1UNC -Force

            if (!(Test-Path $RemotePs1UNC)) {
                & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "Copy cleanup PS1 failed"
                }
            }

            if ($ShutdownAfterClean -eq "Y") {
                $PsArgs = "-ShutdownAfterClean"
            } else {
                $PsArgs = ""
            }

            $Output = & $PsExec "\\$IP" -accepteula -nobanner -s powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RemotePs1Local $PsArgs 2>&1
            $Code = $LASTEXITCODE

            $ShortOutput = ($Output | Select-Object -Last 20) -join " | "

            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"

            if ($Code -ne 0) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "Cleanup failed / PsExec code $Code | $ShortOutput"
                }
            }

            return [PSCustomObject]@{
                IP = $IP
                Status = "SUCCESS"
                Message = "Cleanup success"
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

        "[$($JobResult.Status)] $($JobResult.IP) - $($JobResult.Message)" | Add-Content $LogFile
    }

    Remove-Job $Job
}

$SuccessResults = $Results | Where-Object { $_.Status -eq "SUCCESS" }
$FailedResults = $Results | Where-Object { $_.Status -eq "FAILED" }

$SuccessResults | ForEach-Object { "$($_.IP) - Cleanup success" } | Set-Content $SuccessFile
$FailedResults | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $FailedFile

Write-Host ""
Write-Host "=========================================="
Write-Host "        KET QUA CLEANUP EXAM"
Write-Host "=========================================="
Write-Host "Thanh cong: $($SuccessResults.Count)"
Write-Host "That bai  : $($FailedResults.Count)"
Write-Host ""
Write-Host "File thanh cong: $SuccessFile"
Write-Host "File that bai  : $FailedFile"
Write-Host "Log            : $LogFile"
Write-Host ""

"Thanh cong: $($SuccessResults.Count)" | Add-Content $LogFile
"That bai  : $($FailedResults.Count)" | Add-Content $LogFile
"END $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content $LogFile

if ($FailedResults.Count -gt 0) {
    Write-Host "========== DANH SACH CLEANUP THAT BAI =========="
    $FailedResults | ForEach-Object {
        Write-Host "[FAIL] $($_.IP) - $($_.Message)"
    }
    Write-Host "================================================"
    exit 1
}

exit 0
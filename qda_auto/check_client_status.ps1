param(
    [string]$IP = "",
    [switch]$All,
    [switch]$NoConfirm
)

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalScript = Join-Path $Base "client_status_local.ps1"

$StatusDir = Join-Path $Base "status"
$SuccessFile = Join-Path $Base "check_status_success.txt"
$FailedFile = Join-Path $Base "check_status_failed.txt"
$SummaryFile = Join-Path $StatusDir "inventory_summary.json"

$AdminUser = "admintest"
$AdminPass = "123456"
$Throttle = 20

function Log-Step {
    param([string]$Text)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Output "[$ts] $Text"
}

function Get-IPv4FromLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return ""
    }

    $matches = [regex]::Matches($Line, "\b(?:\d{1,3}\.){3}\d{1,3}\b")

    foreach ($m in $matches) {
        $ip = $m.Value
        $parts = $ip.Split(".")
        $valid = $true

        foreach ($p in $parts) {
            $n = 0

            if (-not [int]::TryParse($p, [ref]$n)) {
                $valid = $false
                break
            }

            if ($n -lt 0 -or $n -gt 255) {
                $valid = $false
                break
            }
        }

        if ($valid) {
            return $ip
        }
    }

    return ""
}

if (!(Test-Path $StatusDir)) {
    New-Item -ItemType Directory -Path $StatusDir -Force | Out-Null
}

if (!(Test-Path $PsExec)) {
    Log-Step "[LOI] Khong thay PsExec.exe: $PsExec"
    exit 1
}

if (!(Test-Path $LocalScript)) {
    Log-Step "[LOI] Khong thay client_status_local.ps1: $LocalScript"
    exit 1
}

$Targets = @()

if ($All) {
    if (!(Test-Path $Clients)) {
        Log-Step "[LOI] Khong thay clients.txt: $Clients"
        exit 1
    }

    $Targets = Get-Content $Clients |
        Where-Object { $_.Trim() -ne "" -and !$_.Trim().StartsWith("#") } |
        ForEach-Object {
            $line = $_.Trim()
            Get-IPv4FromLine $line
        } |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique
} else {
    if ($IP -eq "") {
        if ($NoConfirm) {
            Log-Step "[LOI] App goi check nhung khong co IP."
            exit 1
        }

        $IP = Read-Host "Nhap IP client can check"
    }

    if ($IP -eq "") {
        Log-Step "[LOI] Chua nhap IP"
        exit 1
    }

    $RealIP = Get-IPv4FromLine $IP

    if ($RealIP -eq "") {
        Log-Step "[LOI] IP khong hop le: $IP"
        exit 1
    }

    $Targets = @($RealIP)
}

Write-Output "=========================================="
Write-Output "          QDA CHECK CLIENT STATUS"
Write-Output "=========================================="
Write-Output "So may   : $($Targets.Count)"
Write-Output "Throttle : $Throttle"
Write-Output "Status   : $StatusDir"
Write-Output ""

if (-not $NoConfirm) {
    $Confirm = Read-Host "Nhap Y de chay"
    if ($Confirm -ne "Y") {
        Log-Step "Nguoi dung huy chay."
        exit 0
    }
}

Log-Step "[START] Bat dau check client status..."
Log-Step "[INFO] So may: $($Targets.Count)"
Log-Step "[INFO] Status dir: $StatusDir"

Remove-Item $SuccessFile, $FailedFile -Force -ErrorAction SilentlyContinue

$Jobs = @()
$Results = @()

foreach ($TargetIP in $Targets) {
    Log-Step "[RUN] Check status $TargetIP ..."

    while (($Jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Throttle) {
        Start-Sleep -Milliseconds 500

        $DoneJobs = $Jobs | Where-Object { $_.State -ne "Running" }

        foreach ($Job in $DoneJobs) {
            $r = Receive-Job $Job

            if ($r) {
                $Results += $r

                if ($r.Status -eq "SUCCESS") {
                    Log-Step "[OK] $($r.IP) - $($r.Message)"
                } else {
                    Log-Step "[FAIL] $($r.IP) - $($r.Message)"
                }
            }

            Remove-Job $Job
            $Jobs = $Jobs | Where-Object { $_.Id -ne $Job.Id }
        }
    }

    $Jobs += Start-Job -ArgumentList $TargetIP,$AdminUser,$AdminPass,$PsExec,$LocalScript,$StatusDir -ScriptBlock {
        param(
            $TargetIP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalScript,
            $StatusDir
        )

        try {
            $Ping = Test-Connection -ComputerName $TargetIP -Count 1 -Quiet -ErrorAction SilentlyContinue

            if (-not $Ping) {
                $offline = [ordered]@{
                    ip = $TargetIP
                    online = $false
                    admin_share = $false
                    last_check = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    error = "Ping failed"
                }

                $offlinePath = Join-Path $StatusDir "$TargetIP.json"
                $offline | ConvertTo-Json -Depth 8 | Set-Content -Path $offlinePath -Encoding UTF8

                return [PSCustomObject]@{
                    IP = $TargetIP
                    Status = "FAILED"
                    Message = "PING FAIL"
                }
            }

            & cmd /c "net use \\$TargetIP\C$ /delete /y >nul 2>&1"
            & cmd /c "net use \\$TargetIP\C$ /user:$AdminUser $AdminPass >nul 2>&1"

            if ($LASTEXITCODE -ne 0) {
                $shareFail = [ordered]@{
                    ip = $TargetIP
                    online = $true
                    admin_share = $false
                    last_check = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    error = "C$ failed"
                }

                $shareFailPath = Join-Path $StatusDir "$TargetIP.json"
                $shareFail | ConvertTo-Json -Depth 8 | Set-Content -Path $shareFailPath -Encoding UTF8

                return [PSCustomObject]@{
                    IP = $TargetIP
                    Status = "FAILED"
                    Message = "C$ FAIL"
                }
            }

            $RemoteDirUNC = "\\$TargetIP\C$\APP_DEPLOY\STATUS"
            $RemoteScriptUNC = "\\$TargetIP\C$\APP_DEPLOY\STATUS\client_status_local.ps1"
            $RemoteScriptLocal = "C:\APP_DEPLOY\STATUS\client_status_local.ps1"

            New-Item -ItemType Directory -Path $RemoteDirUNC -Force | Out-Null

            Remove-Item $RemoteScriptUNC -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$TargetIP\C$\qda_client_status.json" -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$TargetIP\C$\qda_client_status_log.txt" -Force -ErrorAction SilentlyContinue

            Copy-Item $LocalScript $RemoteScriptUNC -Force

            & $PsExec "\\$TargetIP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner powershell -NoProfile -ExecutionPolicy Bypass -File $RemoteScriptLocal -IP $TargetIP 2>$null
            $PsExecCode = $LASTEXITCODE

            $RemoteResult = "\\$TargetIP\C$\qda_client_status.json"
            $RemoteLog = "\\$TargetIP\C$\qda_client_status_log.txt"

            $Waited = 0
            while (!(Test-Path $RemoteResult) -and $Waited -lt 90) {
                Start-Sleep -Seconds 2
                $Waited += 2
            }

            if (!(Test-Path $RemoteResult)) {
                $LogText = ""

                if (Test-Path $RemoteLog) {
                    $LogText = (Get-Content $RemoteLog -ErrorAction SilentlyContinue | Select-Object -Last 15) -join " | "
                }

                & cmd /c "net use \\$TargetIP\C$ /delete /y >nul 2>&1"

                return [PSCustomObject]@{
                    IP = $TargetIP
                    Status = "FAILED"
                    Message = "NO STATUS JSON / PsExec code $PsExecCode | $LogText"
                }
            }

            $LocalStatusPath = Join-Path $StatusDir "$TargetIP.json"
            Copy-Item $RemoteResult $LocalStatusPath -Force

            & cmd /c "net use \\$TargetIP\C$ /delete /y >nul 2>&1"

            return [PSCustomObject]@{
                IP = $TargetIP
                Status = "SUCCESS"
                Message = "OK / saved $LocalStatusPath"
            }

        } catch {
            & cmd /c "net use \\$TargetIP\C$ /delete /y >nul 2>&1"

            return [PSCustomObject]@{
                IP = $TargetIP
                Status = "FAILED"
                Message = $_.Exception.Message
            }
        }
    }
}

foreach ($Job in $Jobs) {
    Wait-Job $Job | Out-Null

    $r = Receive-Job $Job

    if ($r) {
        $Results += $r

        if ($r.Status -eq "SUCCESS") {
            Log-Step "[OK] $($r.IP) - $($r.Message)"
        } else {
            Log-Step "[FAIL] $($r.IP) - $($r.Message)"
        }
    }

    Remove-Job $Job
}

$OK = $Results | Where-Object { $_.Status -eq "SUCCESS" }
$FAIL = $Results | Where-Object { $_.Status -eq "FAILED" }

$OK | ForEach-Object { $_.IP } | Set-Content $SuccessFile -Encoding UTF8
$FAIL | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $FailedFile -Encoding UTF8

$Summary = @()

Get-ChildItem $StatusDir -Filter "*.json" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "inventory_summary.json" -and $_.Name -ne "1.json" } |
    ForEach-Object {
        try {
            $obj = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $Summary += $obj
        } catch {}
    }

$Summary | ConvertTo-Json -Depth 8 | Set-Content $SummaryFile -Encoding UTF8

Write-Output ""
Write-Output "=========================================="
Write-Output "          KET QUA CHECK STATUS"
Write-Output "=========================================="
Write-Output "Thanh cong: $($OK.Count)"
Write-Output "That bai  : $($FAIL.Count)"
Write-Output ""
Write-Output "File thanh cong: $SuccessFile"
Write-Output "File that bai  : $FailedFile"
Write-Output "Summary JSON   : $SummaryFile"
Write-Output ""

if ($FAIL.Count -gt 0) {
    Write-Output "========== DANH SACH THAT BAI =========="
    $FAIL | ForEach-Object {
        Write-Output "[FAIL] $($_.IP) - $($_.Message)"
    }
    Write-Output "========================================"
}

Log-Step "[END] Hoan tat check client status."

exit 0
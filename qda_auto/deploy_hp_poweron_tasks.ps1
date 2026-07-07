$Base = Split-Path -Parent $MyInvocation.MyCommand.Path

$Clients = Join-Path $Base "clients.txt"
$PsExec = Join-Path $Base "PsExec.exe"
$LocalScript = Join-Path $Base "hp_poweron_tasks_local.bat"
$ToolFolder = Join-Path $Base "HP_BCU"

$AdminUser = "admintest"
$AdminPass = "123456"
$Throttle = 10

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
    Write-Host "[LOI] Khong thay hp_poweron_tasks_local.bat"
    pause
    exit
}

Write-Host "=========================================="
Write-Host "        HP POWER-ON TASKS"
Write-Host "=========================================="
Write-Host ""
Write-Host "Chon tac vu can chay:"
Write-Host ""
Write-Host "1) Day HP_BCU xuong client"
Write-Host "2) Set BIOS tu bat may theo ngay/gio"
Write-Host "3) Set tu mo QDA/SEB sau khi dang nhap Windows"
Write-Host ""
Write-Host "Vi du:"
Write-Host "  1     = chi copy HP_BCU"
Write-Host "  2     = chi set BIOS tu bat may"
Write-Host "  3     = chi set tu mo QDA/SEB"
Write-Host "  1,2   = copy HP_BCU + set BIOS"
Write-Host "  2,3   = set BIOS + set tu mo QDA/SEB"
Write-Host "  A     = All, tuong duong 1,2,3"
Write-Host ""

$ChoiceInput = Read-Host "Nhap lua chon"
$ChoiceInput = $ChoiceInput.Trim().ToUpper()

if ($ChoiceInput -eq "") {
    Write-Host "[LOI] Ban chua nhap lua chon."
    pause
    exit
}

if ($ChoiceInput -eq "A" -or $ChoiceInput -eq "ALL") {
    $Selected = @("1", "2", "3")
} else {
    $Selected = $ChoiceInput.Split(",") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique
}

foreach ($Item in $Selected) {
    if ($Item -notin @("1", "2", "3")) {
        Write-Host "[LOI] Lua chon khong hop le: $Item"
        pause
        exit
    }
}

$CopyTool = "N"
$DoBios = "N"
$DoApp = "N"

if ($Selected -contains "1") {
    $CopyTool = "Y"
}

if ($Selected -contains "2") {
    $DoBios = "Y"
}

if ($Selected -contains "3") {
    $DoApp = "Y"
}

if ($CopyTool -eq "Y") {
    if (!(Test-Path $ToolFolder)) {
        Write-Host "[LOI] Khong thay folder HP_BCU"
        pause
        exit
    }

    if (!(Test-Path (Join-Path $ToolFolder "BiosConfigUtility64.exe"))) {
        Write-Host "[LOI] Khong thay HP_BCU\BiosConfigUtility64.exe"
        pause
        exit
    }
}

$SUN = 0
$MON = 0
$TUE = 0
$WED = 0
$THU = 0
$FRI = 0
$SAT = 0
$TargetTime = "00:00"

if ($DoBios -eq "Y") {
    Write-Host ""
    Write-Host "Nhap cac thu can bat: CN,2,3,4,5,6,7"
    Write-Host "Vi du:"
    Write-Host "  2,3,4,5,6"
    Write-Host "  6,7,CN"
    Write-Host ""

    $DayItems = (Read-Host "Nhap thu").Split(",") |
        ForEach-Object { $_.Trim().ToUpper() } |
        Where-Object { $_ -ne "" }

    foreach ($Item in $DayItems) {
        switch ($Item) {
            "CN" { $SUN = 1 }
            "2"  { $MON = 1 }
            "3"  { $TUE = 1 }
            "4"  { $WED = 1 }
            "5"  { $THU = 1 }
            "6"  { $FRI = 1 }
            "7"  { $SAT = 1 }
            default {
                Write-Host "[LOI] Sai thu: $Item"
                pause
                exit
            }
        }
    }

    $TargetTime = Read-Host "Nhap gio bat HH:mm"

    if ($TargetTime -notmatch '^\d{2}:\d{2}$') {
        Write-Host "[LOI] Sai dinh dang gio. Vi du dung: 06:30"
        pause
        exit
    }
}

$AppDelay = 60

if ($DoApp -eq "Y") {
    $DelayInput = Read-Host "Nhap so giay cho truoc khi mo app, Enter mac dinh 60"

    if ($DelayInput -ne "") {
        try {
            $AppDelay = [int]$DelayInput
        } catch {
            Write-Host "[LOI] Delay phai la so giay."
            pause
            exit
        }
    }
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
Write-Host "CopyTool    : $CopyTool"
Write-Host "Set BIOS    : $DoBios"
Write-Host "Set App     : $DoApp"
Write-Host "Gio bat     : $TargetTime"
Write-Host "Delay app   : $AppDelay"
Write-Host "Throttle    : $Throttle"
Write-Host ""

$Confirm = Read-Host "Nhap Y de chay"
if ($Confirm -ne "Y") {
    exit
}

$SuccessFile = Join-Path $Base "hp_poweron_tasks_success.txt"
$FailedFile = Join-Path $Base "hp_poweron_tasks_failed.txt"

Remove-Item $SuccessFile, $FailedFile -ErrorAction SilentlyContinue

$Jobs = @()
$Results = @()

foreach ($IP in $Targets) {
    Write-Host "[RUN] Dang gui task toi $IP ..."

    while (($Jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Throttle) {
        Start-Sleep -Milliseconds 500

        foreach ($Job in @($Jobs | Where-Object { $_.State -ne "Running" })) {
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

    $Jobs += Start-Job -ArgumentList $IP,$AdminUser,$AdminPass,$PsExec,$LocalScript,$ToolFolder,$CopyTool,$DoBios,$DoApp,$SUN,$MON,$TUE,$WED,$THU,$FRI,$SAT,$TargetTime,$AppDelay -ScriptBlock {
        param(
            $IP,
            $AdminUser,
            $AdminPass,
            $PsExec,
            $LocalScript,
            $ToolFolder,
            $CopyTool,
            $DoBios,
            $DoApp,
            $SUN,
            $MON,
            $TUE,
            $WED,
            $THU,
            $FRI,
            $SAT,
            $TargetTime,
            $AppDelay
        )

        try {
            & cmd /c "net use \\$IP\C$ /delete /y >nul 2>&1"
            & cmd /c "net use \\$IP\C$ /user:$AdminUser $AdminPass >nul 2>&1"

            if ($LASTEXITCODE -ne 0) {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "FAILED"
                    Message = "C$ FAIL"
                }
            }

            $RemoteRoot = "\\$IP\C$\Windows\Temp\NTP_LAB"
            $RemoteTool = "\\$IP\C$\Windows\Temp\NTP_LAB\HP_BCU"
            $RemoteBat = "\\$IP\C$\Windows\Temp\NTP_LAB\hp_poweron_tasks_local.bat"

            New-Item -ItemType Directory -Path $RemoteRoot -Force | Out-Null

            Remove-Item $RemoteBat -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\hp_poweron_tasks_result.txt", "\\$IP\C$\hp_poweron_tasks_log.txt" -Force -ErrorAction SilentlyContinue

            Copy-Item $LocalScript $RemoteBat -Force

            if ($CopyTool -eq "Y") {
                Remove-Item $RemoteTool -Recurse -Force -ErrorAction SilentlyContinue
                Copy-Item $ToolFolder $RemoteTool -Recurse -Force
            }

            $RemoteLocal = "C:\Windows\Temp\NTP_LAB\hp_poweron_tasks_local.bat"
            $Args = "$DoBios $SUN $MON $TUE $WED $THU $FRI $SAT $TargetTime $DoApp $AppDelay"
            $RunLine = "`"$RemoteLocal`" $Args"

            & $PsExec "\\$IP" -u $AdminUser -p $AdminPass -s -h -accepteula -nobanner cmd /c $RunLine 2>$null
            $Code = $LASTEXITCODE

            $ResultPath = "\\$IP\C$\hp_poweron_tasks_result.txt"
            $LogPath = "\\$IP\C$\hp_poweron_tasks_log.txt"

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
                    Message = "NO RESULT FILE / code $Code"
                }
            }

            $ResultText = ((Get-Content $ResultPath -ErrorAction SilentlyContinue | Select-Object -First 1) -join "").Trim()

            $LogText = ""
            if (Test-Path $LogPath) {
                $LogText = (Get-Content $LogPath -ErrorAction SilentlyContinue | Select-Object -Last 8) -join " | "
            }

            Remove-Item "\\$IP\C$\hp_poweron_tasks_log.txt" -Force -ErrorAction SilentlyContinue
            Remove-Item "\\$IP\C$\hp_poweron_tasks_result.txt" -Force -ErrorAction SilentlyContinue

            if ($ResultText -like "SUCCESS*") {
                return [PSCustomObject]@{
                    IP = $IP
                    Status = "SUCCESS"
                    Message = "OK | $LogText"
                }
            }

            return [PSCustomObject]@{
                IP = $IP
                Status = "FAILED"
                Message = "$ResultText | $LogText"
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

$OK = $Results | Where-Object { $_.Status -eq "SUCCESS" }
$FAIL = $Results | Where-Object { $_.Status -eq "FAILED" }

$OK | ForEach-Object { $_.IP } | Set-Content $SuccessFile
$FAIL | ForEach-Object { "$($_.IP) - $($_.Message)" } | Set-Content $FailedFile

Write-Host ""
Write-Host "=========================================="
Write-Host "        KET QUA HP POWER-ON TASKS"
Write-Host "=========================================="
Write-Host "Thanh cong: $($OK.Count)"
Write-Host "That bai  : $($FAIL.Count)"
Write-Host ""
Write-Host "File thanh cong: $SuccessFile"
Write-Host "File that bai  : $FailedFile"

$FAIL | ForEach-Object {
    Write-Host "[FAIL] $($_.IP) - $($_.Message)"
}

pause
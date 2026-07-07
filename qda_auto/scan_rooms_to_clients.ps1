param(
    [string]$IPServer = "",
    [string]$ExcludeDotOne = "Y",
    [string]$ExtraExcludeIPs = ""
)

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClientsFile = Join-Path $Base "clients.txt"
$RoomsFile = Join-Path $Base "rooms.txt"

Write-Host "=========================================="
Write-Host "        SCAN ROOMS - ONLY PORT 445"
Write-Host "=========================================="
Write-Host ""

if (!(Test-Path $RoomsFile)) {
    Write-Host "[LOI] Khong thay rooms.txt"
    pause
    exit
}

$RoomRows = @()

Get-Content $RoomsFile | ForEach-Object {
    $Line = $_.Trim()

    if ($Line -eq "" -or $Line.StartsWith("#")) {
        return
    }

    if ($Line -notmatch "=") {
        return
    }

    $Parts = $Line.Split("=", 2)

    if ($Parts.Count -eq 2) {
        $RoomRows += [PSCustomObject]@{
            Room = $Parts[0].Trim().ToUpper()
            Subnet = $Parts[1].Trim()
        }
    }
}

if ($RoomRows.Count -eq 0) {
    Write-Host "[LOI] rooms.txt khong co phong hop le."
    Write-Host "Dung format: 301A=192.168.18.0/24"
    pause
    exit
}

Write-Host "Danh sach phong trong rooms.txt:"
Write-Host ""

for ($i = 0; $i -lt $RoomRows.Count; $i++) {
    $Index = $i + 1
    Write-Host ("[{0}] {1,-10} {2}" -f $Index, $RoomRows[$i].Room, $RoomRows[$i].Subnet)
}

Write-Host ""
$Choice = Read-Host "Nhap so thu tu hoac ten phong, vi du 1 hoac 301A"
$Choice = $Choice.Trim().ToUpper()

$Selected = $null

if ($Choice -match "^\d+$") {
    $Number = [int]$Choice

    if ($Number -ge 1 -and $Number -le $RoomRows.Count) {
        $Selected = $RoomRows[$Number - 1]
    }
} else {
    $Selected = $RoomRows | Where-Object {
        $_.Room -eq $Choice
    } | Select-Object -First 1
}

if ($null -eq $Selected) {
    Write-Host "[LOI] Khong tim thay phong: $Choice"
    pause
    exit
}

$RoomName = $Selected.Room
$Subnet = $Selected.Subnet

$ExcludeList = @()

if ($IPServer.Trim() -ne "") {
    $ExcludeList += $IPServer.Trim()
}

if ($ExtraExcludeIPs.Trim() -ne "") {
    $ExcludeList += $ExtraExcludeIPs.Split(",") | ForEach-Object {
        $_.Trim()
    } | Where-Object {
        $_ -ne ""
    }
}

$ExcludeList = $ExcludeList | Sort-Object -Unique

$LocalNmap = Join-Path $Base "Nmap\nmap.exe"

if (Test-Path $LocalNmap) {
    $NmapCmd = $LocalNmap
} else {
    $Nmap = Get-Command nmap -ErrorAction SilentlyContinue

    if ($null -eq $Nmap) {
        Write-Host "[LOI] Khong thay nmap."
        Write-Host "Hay dat toan bo folder Nmap vao:"
        Write-Host "$Base\Nmap"
        Write-Host "Hoac cai Nmap vao may server."
        pause
        exit
    }

    $NmapCmd = $Nmap.Source
}

Write-Host ""
Write-Host "=========================================="
Write-Host "              THONG TIN SCAN"
Write-Host "=========================================="
Write-Host "Phong          : $RoomName"
Write-Host "Subnet         : $Subnet"
Write-Host "Chi scan port  : 445"
Write-Host "IP server loai : $IPServer"
Write-Host "Loai .1        : $ExcludeDotOne"
Write-Host "Loai them      : $($ExcludeList -join ', ')"
Write-Host ""

Write-Host "Dang chay:"
Write-Host "$NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 $Subnet"
Write-Host ""

$RawLines = New-Object System.Collections.Generic.List[string]

& $NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 $Subnet 2>&1 | ForEach-Object {
    $Line = $_.ToString()
    Write-Host $Line
    $RawLines.Add($Line)
}

$Clients = @()

foreach ($Line in $RawLines) {
    if ($Line -match "Nmap scan report for\s+(.+)$") {
        $Target = $Matches[1].Trim()
        $Match = [regex]::Match($Target, "(\d{1,3}\.){3}\d{1,3}")

        if ($Match.Success) {
            $IP = $Match.Value

            if ($ExcludeDotOne.ToUpper() -eq "Y" -and $IP -match "\.1$") {
                continue
            }

            if ($ExcludeList -contains $IP) {
                continue
            }

            $Clients += $IP
        }
    }
}

$Clients = $Clients | Sort-Object -Unique
$Clients | Set-Content $ClientsFile -Encoding ASCII

Write-Host ""
Write-Host "=========================================="
Write-Host "              KET QUA"
Write-Host "=========================================="
Write-Host "Phong              : $RoomName"
Write-Host "Subnet             : $Subnet"
Write-Host "So may mo port 445 : $($Clients.Count)"
Write-Host "File clients.txt   : $ClientsFile"
Write-Host ""

if ($Clients.Count -gt 0) {
    Write-Host "Danh sach clients.txt:"
    $Clients | ForEach-Object {
        Write-Host $_
    }
} else {
    Write-Host "[CANH BAO] Khong co may nao mo port 445."
    Write-Host "Thu test tay lenh nay:"
    Write-Host "$NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 $Subnet"
}

Write-Host ""
pause
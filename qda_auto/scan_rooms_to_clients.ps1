param(
    [string]$IPServer = "",
    [string]$ExcludeDotOne = "Y",
    [string]$ExtraExcludeIPs = ""
)

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClientsFile = Join-Path $Base "clients.txt"
$RoomsFile = Join-Path $Base "rooms.txt"
$LogFile = Join-Path $Base "scan_rooms_log.txt"
$SuccessFile = Join-Path $Base "scan_rooms_success.txt"
$FailedFile = Join-Path $Base "scan_rooms_failed.txt"

function Write-QdaLog {
    param([string]$Text)

    Write-Host $Text
    Add-Content -Path $LogFile -Value $Text -Encoding UTF8
}

"===== SCAN ROOMS - ONLY PORT 445 =====" | Set-Content -Path $LogFile -Encoding UTF8
"START $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogFile -Encoding UTF8
"BASE=$Base" | Add-Content -Path $LogFile -Encoding UTF8
"ROOMS=$RoomsFile" | Add-Content -Path $LogFile -Encoding UTF8
"CLIENTS=$ClientsFile" | Add-Content -Path $LogFile -Encoding UTF8
"" | Add-Content -Path $LogFile -Encoding UTF8

Write-Host "=========================================="
Write-Host "        SCAN ROOMS - ONLY PORT 445"
Write-Host "=========================================="
Write-Host ""

if (!(Test-Path $RoomsFile)) {
    Write-QdaLog "[LOI] Khong thay rooms.txt: $RoomsFile"
    "Khong thay rooms.txt" | Set-Content -Path $FailedFile -Encoding UTF8
    exit 1
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
        $RoomName = $Parts[0].Trim().ToUpper()
        $Subnet = $Parts[1].Trim()

        if ($RoomName -ne "" -and $Subnet -ne "") {
            $RoomRows += [PSCustomObject]@{
                Room = $RoomName
                Subnet = $Subnet
            }
        }
    }
}

if ($RoomRows.Count -eq 0) {
    Write-QdaLog "[LOI] rooms.txt khong co phong hop le."
    Write-QdaLog "Dung format: 301A=192.168.18.0/24"
    "rooms.txt khong hop le" | Set-Content -Path $FailedFile -Encoding UTF8
    exit 1
}

Write-Host "Danh sach phong trong rooms.txt:"
Write-Host ""

for ($i = 0; $i -lt $RoomRows.Count; $i++) {
    $Index = $i + 1
    Write-Host ("[{0}] {1,-10} {2}" -f $Index, $RoomRows[$i].Room, $RoomRows[$i].Subnet)
}

Write-Host ""
Write-Host "[A] ALL        Scan tat ca phong"
Write-Host ""

$Choice = Read-Host "Nhap so thu tu, ten phong, hoac A de scan tat ca"
$Choice = $Choice.Trim().ToUpper()

if ($Choice -eq "") {
    Write-QdaLog "[LOI] Chua nhap lua chon."
    "Chua nhap lua chon" | Set-Content -Path $FailedFile -Encoding UTF8
    exit 1
}

$SelectedRooms = @()

if ($Choice -eq "A" -or $Choice -eq "ALL") {
    $SelectedRooms = $RoomRows
} else {
    $Choices = $Choice.Split(",") | ForEach-Object {
        $_.Trim().ToUpper()
    } | Where-Object {
        $_ -ne ""
    }

    foreach ($Item in $Choices) {
        if ($Item -match "^\d+$") {
            $Number = [int]$Item

            if ($Number -ge 1 -and $Number -le $RoomRows.Count) {
                $SelectedRooms += $RoomRows[$Number - 1]
            }
        } else {
            $Found = $RoomRows | Where-Object {
                $_.Room -eq $Item
            } | Select-Object -First 1

            if ($null -ne $Found) {
                $SelectedRooms += $Found
            }
        }
    }
}

$SelectedRooms = $SelectedRooms | Sort-Object Room -Unique

if ($SelectedRooms.Count -eq 0) {
    Write-QdaLog "[LOI] Khong tim thay phong/lua chon: $Choice"
    "Khong tim thay phong/lua chon: $Choice" | Set-Content -Path $FailedFile -Encoding UTF8
    exit 1
}

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
        Write-QdaLog "[LOI] Khong thay nmap."
        Write-QdaLog "Hay dat toan bo folder Nmap vao: $Base\Nmap"
        Write-QdaLog "Hoac cai Nmap vao may server."
        "Khong thay nmap" | Set-Content -Path $FailedFile -Encoding UTF8
        exit 1
    }

    $NmapCmd = $Nmap.Source
}

Write-Host ""
Write-Host "=========================================="
Write-Host "              THONG TIN SCAN"
Write-Host "=========================================="
Write-Host "Lua chon       : $Choice"
Write-Host "So phong scan  : $($SelectedRooms.Count)"
Write-Host "Chi scan port  : 445"
Write-Host "IP server loai : $IPServer"
Write-Host "Loai .1        : $ExcludeDotOne"
Write-Host "Loai them      : $($ExcludeList -join ', ')"
Write-Host "Nmap           : $NmapCmd"
Write-Host "=========================================="
Write-Host ""

Add-Content -Path $LogFile -Value "Choice=$Choice" -Encoding UTF8
Add-Content -Path $LogFile -Value "SelectedRooms=$($SelectedRooms.Room -join ', ')" -Encoding UTF8
Add-Content -Path $LogFile -Value "Nmap=$NmapCmd" -Encoding UTF8
Add-Content -Path $LogFile -Value "" -Encoding UTF8

$AllClients = @()

foreach ($Selected in $SelectedRooms) {
    $RoomName = $Selected.Room
    $Subnet = $Selected.Subnet

    Write-QdaLog ""
    Write-QdaLog "=========================================="
    Write-QdaLog "SCAN PHONG: $RoomName - $Subnet"
    Write-QdaLog "=========================================="

    Write-Host ""
    Write-Host "Dang chay:"
    Write-Host "$NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 $Subnet"
    Write-Host ""

    $RawLines = New-Object System.Collections.Generic.List[string]

    & $NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 $Subnet 2>&1 | ForEach-Object {
        $Line = $_.ToString()
        Write-Host $Line
        Add-Content -Path $LogFile -Value $Line -Encoding UTF8
        $RawLines.Add($Line)
    }

    $RoomClients = @()

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

                $RoomClients += $IP
                $AllClients += $IP
            }
        }
    }

    $RoomClients = $RoomClients | Sort-Object -Unique

    Write-QdaLog ""
    Write-QdaLog "KET QUA PHONG $RoomName"
    Write-QdaLog "So may mo port 445: $($RoomClients.Count)"

    if ($RoomClients.Count -gt 0) {
        foreach ($Client in $RoomClients) {
            Write-QdaLog " - $Client"
        }
    } else {
        Write-QdaLog "[CANH BAO] Phong $RoomName khong co may nao mo port 445."
    }
}

$AllClients = $AllClients | Sort-Object -Unique
$AllClients | Set-Content $ClientsFile -Encoding ASCII

Write-Host ""
Write-Host "=========================================="
Write-Host "              KET QUA TONG"
Write-Host "=========================================="
Write-Host "So phong da scan    : $($SelectedRooms.Count)"
Write-Host "So may mo port 445  : $($AllClients.Count)"
Write-Host "File clients.txt    : $ClientsFile"
Write-Host ""

Add-Content -Path $LogFile -Value "" -Encoding UTF8
Add-Content -Path $LogFile -Value "===== KET QUA TONG =====" -Encoding UTF8
Add-Content -Path $LogFile -Value "So phong da scan: $($SelectedRooms.Count)" -Encoding UTF8
Add-Content -Path $LogFile -Value "So may mo port 445: $($AllClients.Count)" -Encoding UTF8
Add-Content -Path $LogFile -Value "ClientsFile: $ClientsFile" -Encoding UTF8

if ($AllClients.Count -gt 0) {
    Write-Host "Danh sach clients.txt:"
    $AllClients | ForEach-Object {
        Write-Host $_
        Add-Content -Path $LogFile -Value $_ -Encoding UTF8
    }
} else {
    Write-Host "[CANH BAO] Khong co may nao mo port 445."
    Write-Host "Thu test tay lenh:"
    Write-Host "$NmapCmd -Pn -n -p 445 --open --stats-every 5s -T4 <SUBNET>"
}

"Thanh cong $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $SuccessFile -Encoding UTF8
if (Test-Path $FailedFile) {
    Remove-Item $FailedFile -Force
}

Add-Content -Path $LogFile -Value "END $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8

Write-Host ""
Write-Host "Log:"
Write-Host $LogFile
Write-Host ""

exit 0
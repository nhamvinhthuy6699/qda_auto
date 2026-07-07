$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$RoomsFile = Join-Path $Base "rooms.txt"
$OutFile = Join-Path $Base "veyon_clients.csv"
$ScanDir = Join-Path $Base "nmap_veyon_scans"
$Nmap = Join-Path $Base "Nmap\nmap.exe"

if (!(Test-Path $RoomsFile)) {
    Write-Host "[LOI] Khong thay rooms.txt" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $Nmap)) {
    Write-Host "[LOI] Khong thay Nmap: $Nmap" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $ScanDir)) {
    New-Item -ItemType Directory -Path $ScanDir | Out-Null
}

function Convert-ToSubnet24 {
    param([string]$Cidr)

    $ipPart = $Cidr -replace "/24",""
    $octets = $ipPart.Split(".")

    if ($octets.Count -lt 3) {
        return $null
    }

    return "$($octets[0]).$($octets[1]).$($octets[2]).0/24"
}

$rooms = @()

Get-Content $RoomsFile | ForEach-Object {
    $line = $_.Trim()

    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    if ($line -notmatch "=") {
        Write-Host "[BO QUA] Sai format: $line" -ForegroundColor Yellow
        return
    }

    $parts = $line.Split("=")
    $room = $parts[0].Trim()
    $cidrRaw = $parts[1].Trim()
    $cidr = Convert-ToSubnet24 $cidrRaw

    if ($null -eq $cidr) {
        Write-Host "[BO QUA] IP sai: $line" -ForegroundColor Yellow
        return
    }

    $rooms += [PSCustomObject]@{
        ROOM = $room
        CIDR = $cidr
    }
}

if ($rooms.Count -eq 0) {
    Write-Host "[LOI] rooms.txt khong co phong hop le" -ForegroundColor Red
    exit 1
}

cls
Write-Host "===== CHON PHONG CAN SCAN =====" -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $rooms.Count; $i++) {
    Write-Host "[$($i+1)] $($rooms[$i].ROOM) - $($rooms[$i].CIDR)"
}

Write-Host "[A] Scan tat ca phong"
Write-Host ""

$choice = Read-Host "Nhap lua chon, vi du 1 hoac 1,3 hoac A"

$selected = @()

if ($choice.Trim().ToUpper() -eq "A") {
    $selected = $rooms
} else {
    $indexes = $choice.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }

    foreach ($idx in $indexes) {
        $n = [int]$idx
        if ($n -ge 1 -and $n -le $rooms.Count) {
            $selected += $rooms[$n - 1]
        }
    }
}

if ($selected.Count -eq 0) {
    Write-Host "[LOI] Khong chon phong nao" -ForegroundColor Red
    exit 1
}

$serverIPs = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object -ExpandProperty IPAddress

$allResults = @()

foreach ($r in $selected) {
    $room = $r.ROOM
    $cidr = $r.CIDR

    $safeName = "$room-" + $cidr.Replace("/","_").Replace(".","-")
    $xmlFile = Join-Path $ScanDir "$safeName.xml"

    Write-Host ""
    Write-Host "===== SCAN $room - $cidr =====" -ForegroundColor Green

    & $Nmap -sn -PS445 $cidr --stats-every 5s -oX $xmlFile

    if (!(Test-Path $xmlFile)) {
        Write-Host "[LOI] Nmap khong tao file XML: $xmlFile" -ForegroundColor Red
        continue
    }

    [xml]$xml = Get-Content $xmlFile

    $roomCount = 1

    foreach ($hostNode in $xml.nmaprun.host) {
        if ($hostNode.status.state -ne "up") {
            continue
        }

        $ip = ""
        $mac = ""

        foreach ($addr in $hostNode.address) {
            if ($addr.addrtype -eq "ipv4") {
                $ip = $addr.addr
            }

            if ($addr.addrtype -eq "mac") {
                $mac = $addr.addr.ToUpper()
            }
        }

# Neu Nmap khong lay duoc MAC thi thu lay bang ARP cua Windows
if ($ip -ne "" -and $mac -eq "") {
    ping -n 1 -w 500 $ip | Out-Null

    $arpLine = arp -a $ip | Select-String $ip

    if ($arpLine) {
        $tokens = ($arpLine.ToString() -split "\s+") | Where-Object { $_ -ne "" }

        foreach ($t in $tokens) {
            if ($t -match "^[0-9a-fA-F]{2}(-[0-9a-fA-F]{2}){5}$") {
                $mac = $t.Replace("-",":").ToUpper()
            }
        }
    }
}

        if ($ip -eq "") {
            continue
        }

        $lastOctet = [int]($ip.Split(".")[-1])

        if ($lastOctet -eq 0 -or $lastOctet -eq 1 -or $lastOctet -eq 255) {
            continue
        }

        if ($serverIPs -contains $ip) {
            continue
        }

        $name = "{0}-MAY{1:D3}" -f $room, $roomCount

        $allResults += [PSCustomObject]@{
            ROOM = $room
            NAME = $name
            IP   = $ip
            MAC  = $mac
        }

        if ($mac -eq "") {
            Write-Host "[UP] $ip MAC_TRONG" -ForegroundColor Yellow
        } else {
            Write-Host "[UP] $ip $mac" -ForegroundColor Green
        }

        $roomCount++
    }
}

$allResults |
    Sort-Object ROOM,IP |
    Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "===== DONE =====" -ForegroundColor Cyan
Write-Host "Tong may tim thay: $($allResults.Count)"
Write-Host "Da tao file:"
Write-Host $OutFile -ForegroundColor Green
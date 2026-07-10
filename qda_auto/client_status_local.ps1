param(
    [string]$IP = ""
)

$ErrorActionPreference = "SilentlyContinue"

$ResultPath = "C:\qda_client_status.json"
$LogPath = "C:\qda_client_status_log.txt"

Remove-Item $ResultPath -Force -ErrorAction SilentlyContinue
Remove-Item $LogPath -Force -ErrorAction SilentlyContinue

function Write-Log {
    param([string]$Text)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Text"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Test-PathWildcard {
    param([string[]]$Paths)

    foreach ($p in $Paths) {
        try {
            $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return $true
            }
        } catch {}
    }

    return $false
}

function Get-PathWildcard {
    param([string[]]$Paths)

    foreach ($p in $Paths) {
        try {
            $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                return $found.FullName
            }
        } catch {}
    }

    return ""
}

function Test-AnyPath {
    param([string[]]$Paths)
    return Test-PathWildcard $Paths
}

function Get-AnyPath {
    param([string[]]$Paths)
    return Get-PathWildcard $Paths
}

function Get-RegistryDword {
    param(
        [string]$Path,
        [string]$Name
    )

    try {
        $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return [int]$item.$Name
    } catch {
        return $null
    }
}

function New-AppCheck {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Type,
        [bool]$Installed,
        [string]$CheckPath,
        [string]$Note
    )

    return [ordered]@{
        id = $Id
        name = $Name
        type = $Type
        installed = $Installed
        check_path = $CheckPath
        note = $Note
    }
}

function Test-Microsoft365Installed {
    $paths = @(
        "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
        "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE",
        "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE",
        "C:\Program Files (x86)\Microsoft Office\root\Office16\EXCEL.EXE"
    )

    if (Test-PathWildcard $paths) {
        return $true
    }

    $uninstallRoots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($root in $uninstallRoots) {
        try {
            $apps = Get-ItemProperty $root -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.DisplayName -match "Microsoft 365|Microsoft Office 365|Microsoft 365 Apps|Office 365"
                }

            if ($apps) {
                return $true
            }
        } catch {}
    }

    return $false
}

function Get-Microsoft365Evidence {
    $paths = @(
        "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
        "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE",
        "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE",
        "C:\Program Files (x86)\Microsoft Office\root\Office16\EXCEL.EXE"
    )

    $foundPath = Get-PathWildcard $paths

    if ($foundPath -ne "") {
        return $foundPath
    }

    $uninstallRoots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($root in $uninstallRoots) {
        try {
            $app = Get-ItemProperty $root -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.DisplayName -match "Microsoft 365|Microsoft Office 365|Microsoft 365 Apps|Office 365"
                } |
                Select-Object -First 1

            if ($app) {
                return $app.DisplayName
            }
        } catch {}
    }

    return ""
}

Write-Log "===== QDA CLIENT STATUS LOCAL START ====="
Write-Log "IP=$IP"

$ComputerName = $env:COMPUTERNAME
$UserName = $env:USERNAME

# =========================
# BASIC SOFTWARE CHECKS
# =========================

$VeyonPaths = @(
    "C:\Program Files\Veyon\veyon-service.exe",
    "C:\Program Files\Veyon\veyon-master.exe",
    "C:\Program Files\Veyon\veyon-configurator.exe"
)

$SEBPaths = @(
    "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.exe",
    "C:\Program Files (x86)\SafeExamBrowser\Application\SafeExamBrowser.exe",
    "C:\Program Files\SafeExamBrowser\SafeExamBrowser.exe",
    "C:\Program Files (x86)\SafeExamBrowser\SafeExamBrowser.exe"
)

$Office2016Paths = @(
    "C:\Program Files\Microsoft Office\Office16\WINWORD.EXE",
    "C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE",
    "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
    "C:\Program Files (x86)\Microsoft Office\root\Office16\WINWORD.EXE"
)

$HPBCUPaths = @(
    "C:\Windows\Temp\NTP_LAB\HP_BCU\BiosConfigUtility64.exe",
    "C:\Windows\Temp\HP_BCU\BiosConfigUtility64.exe",
    "C:\APP_DEPLOY\INSTALL\HP_BCU\BiosConfigUtility64.exe",
    "C:\APP_DEPLOY\HP_BCU\BiosConfigUtility64.exe"
)

$DellCCTKPaths = @(
    "C:\Windows\Temp\DELL_AUTOON\DELL_CMD\cctk.exe",
    "C:\Windows\Temp\DELL_AUTOON\DELL_CMD\X86_64\cctk.exe",
    "C:\Windows\Temp\DELL_AUTOON\DELL_CCTK\cctk.exe",
    "C:\Windows\Temp\DELL_AUTOON\DELL_CCTK\X86_64\cctk.exe",
    "C:\APP_DEPLOY\DELL_CCTK\cctk.exe"
)

$QDAFilePaths = @(
    "C:\Users\Public\Desktop\QDA2026_BQP.seb",
    "C:\Users\Public\Desktop\*.seb",
    "C:\Users\admin\Desktop\QDA2026_BQP.seb",
    "C:\Users\TTCNTTNN\Desktop\QDA2026_BQP.seb"
)

$veyonInstalled = Test-AnyPath $VeyonPaths
$sebInstalled = Test-AnyPath $SEBPaths
$office2016Installed = Test-AnyPath $Office2016Paths
$hpBcuAvailable = Test-AnyPath $HPBCUPaths
$dellCctkAvailable = Test-AnyPath $DellCCTKPaths
$qdaSebFileExists = Test-AnyPath $QDAFilePaths

$veyonPath = Get-AnyPath $VeyonPaths
$sebPath = Get-AnyPath $SEBPaths
$officePath = Get-AnyPath $Office2016Paths
$hpBcuPath = Get-AnyPath $HPBCUPaths
$dellCctkPath = Get-AnyPath $DellCCTKPaths
$qdaSebPath = Get-AnyPath $QDAFilePaths

# =========================
# SERVICES
# =========================

$veyonService = Get-Service | Where-Object {
    $_.Name -match "Veyon" -or $_.DisplayName -match "Veyon"
} | Select-Object -First 1

$sebService = Get-Service | Where-Object {
    $_.Name -match "SEB|SafeExam" -or $_.DisplayName -match "SEB|Safe Exam"
} | Select-Object -First 1

# =========================
# WIFI STATUS
# =========================

$wifiAdapters = @()

try {
    $wifiAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -match "Wi-Fi|Wifi|Wireless|WLAN|802.11") -or
            ($_.InterfaceDescription -match "Wi-Fi|Wifi|Wireless|WLAN|802.11")
        } |
        Select-Object Name, Status, InterfaceDescription
} catch {
    $wifiAdapters = @()
}

$wifiText = "NotFound"

if ($wifiAdapters.Count -gt 0) {
    $wifiText = ($wifiAdapters | ForEach-Object {
        "$($_.Name):$($_.Status)"
    }) -join "; "
}

# =========================
# EXAM MODE / C DRIVE HIDDEN
# =========================

$ExplorerPolicy = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"

$NoDrives = Get-RegistryDword -Path $ExplorerPolicy -Name "NoDrives"
$NoViewOnDrive = Get-RegistryDword -Path $ExplorerPolicy -Name "NoViewOnDrive"

$CDriveHidden = $false
$CDriveBlocked = $false

if ($null -ne $NoDrives) {
    if (($NoDrives -band 4) -eq 4) {
        $CDriveHidden = $true
    }
}

if ($null -ne $NoViewOnDrive) {
    if (($NoViewOnDrive -band 4) -eq 4) {
        $CDriveBlocked = $true
    }
}

# =========================
# DISK / BASIC INFO
# =========================

$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$FreeGB = $null
$SizeGB = $null

if ($disk) {
    $FreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $SizeGB = [math]::Round($disk.Size / 1GB, 2)
}

# =========================
# APPS_MENU DEPLOYMENT CHECKS
# =========================

$PublicDesktop = "C:\Users\Public\Desktop"
$AppDeployInstall = "C:\APP_DEPLOY\INSTALL"

$CheckSEBPaths = @(
    "C:\Program Files\SafeExamBrowser\Application\SafeExamBrowser.exe",
    "C:\Program Files (x86)\SafeExamBrowser\Application\SafeExamBrowser.exe",
    "C:\Program Files\SafeExamBrowser\SafeExamBrowser.exe",
    "C:\Program Files (x86)\SafeExamBrowser\SafeExamBrowser.exe"
)

$CheckQdaSebPaths = @(
    "$PublicDesktop\QDA2026_BQP.seb",
    "$PublicDesktop\*QDA*.seb",
    "$PublicDesktop\*BQP*.seb"
)

$CheckUnikeyPaths = @(
    "$PublicDesktop\UniKeyNT.exe",
    "$PublicDesktop\*UniKey*.exe"
)

$CheckOfficeSourcePaths = @(
    "$AppDeployInstall\OFFICE2016",
    "C:\APP_DEPLOY\INSTALL\OFFICE2016"
)

$CheckUninstallOfficeBatPaths = @(
    "$AppDeployInstall\uninstall_office2016.bat",
    "C:\APP_DEPLOY\INSTALL\uninstall_office2016.bat",
    "C:\APP_DEPLOY\uninstall_office2016.bat"
)

$CheckOfficeInstalledPaths = @(
    "C:\Program Files\Microsoft Office\Office16\WINWORD.EXE",
    "C:\Program Files (x86)\Microsoft Office\Office16\WINWORD.EXE"
)

$CheckODTPaths = @(
    "$AppDeployInstall\ODT",
    "$AppDeployInstall\ODT\setup.exe",
    "C:\APP_DEPLOY\INSTALL\ODT\setup.exe"
)

$CheckWinrarPaths = @(
    "C:\Program Files\WinRAR\WinRAR.exe",
    "C:\Program Files (x86)\WinRAR\WinRAR.exe"
)

$CheckFixWinrarBatPaths = @(
    "$AppDeployInstall\fix_winrar_right_click.bat",
    "C:\APP_DEPLOY\INSTALL\fix_winrar_right_click.bat",
    "C:\APP_DEPLOY\fix_winrar_right_click.bat"
)

$CheckVeyonSourcePaths = @(
    "$AppDeployInstall\VEYON",
    "C:\APP_DEPLOY\INSTALL\VEYON"
)

$CheckVeyonInstalledPaths = @(
    "C:\Program Files\Veyon\veyon-service.exe",
    "C:\Program Files\Veyon\veyon-master.exe",
    "C:\Program Files\Veyon\veyon-configurator.exe"
)

$M365Installed = Test-Microsoft365Installed
$M365Evidence = Get-Microsoft365Evidence
$M365Removed = -not $M365Installed

$AppsMenuChecks = @()

$AppsMenuChecks += New-AppCheck `
    -Id "1" `
    -Name "Safe Exam Browser 2.4.1" `
    -Type "EXE_SILENT" `
    -Installed (Test-PathWildcard $CheckSEBPaths) `
    -CheckPath (Get-PathWildcard $CheckSEBPaths) `
    -Note "Check SEB installed"

$AppsMenuChecks += New-AppCheck `
    -Id "2" `
    -Name "QDA2026_BQP SEB" `
    -Type "COPY" `
    -Installed (Test-PathWildcard $CheckQdaSebPaths) `
    -CheckPath (Get-PathWildcard $CheckQdaSebPaths) `
    -Note "Check .seb file on Public Desktop"

$AppsMenuChecks += New-AppCheck `
    -Id "3" `
    -Name "Copy UniKey to Desktop" `
    -Type "COPY" `
    -Installed (Test-PathWildcard $CheckUnikeyPaths) `
    -CheckPath (Get-PathWildcard $CheckUnikeyPaths) `
    -Note "Check UniKeyNT.exe on Public Desktop"

$AppsMenuChecks += New-AppCheck `
    -Id "4" `
    -Name "Copy Office 2016 Source" `
    -Type "FOLDER" `
    -Installed (Test-PathWildcard $CheckOfficeSourcePaths) `
    -CheckPath (Get-PathWildcard $CheckOfficeSourcePaths) `
    -Note "Check Office 2016 source copied"

$AppsMenuChecks += New-AppCheck `
    -Id "5" `
    -Name "Uninstall Office 2016 BAT" `
    -Type "BAT" `
    -Installed (Test-PathWildcard $CheckUninstallOfficeBatPaths) `
    -CheckPath (Get-PathWildcard $CheckUninstallOfficeBatPaths) `
    -Note "Check uninstall_office2016.bat copied"

$AppsMenuChecks += New-AppCheck `
    -Id "6" `
    -Name "Install Office 2016" `
    -Type "BAT" `
    -Installed (Test-PathWildcard $CheckOfficeInstalledPaths) `
    -CheckPath (Get-PathWildcard $CheckOfficeInstalledPaths) `
    -Note "Check Office 2016 installed by WINWORD.EXE"

$AppsMenuChecks += New-AppCheck `
    -Id "7" `
    -Name "Copy ODT Tool" `
    -Type "FOLDER" `
    -Installed (Test-PathWildcard $CheckODTPaths) `
    -CheckPath (Get-PathWildcard $CheckODTPaths) `
    -Note "Check ODT folder/setup.exe copied"

$AppsMenuChecks += New-AppCheck `
    -Id "8" `
    -Name "Remove Microsoft 365 By ODT" `
    -Type "BAT" `
    -Installed $M365Removed `
    -CheckPath $M365Evidence `
    -Note $(if ($M365Removed) { "Microsoft 365 removed / not found" } else { "Microsoft 365 still exists: $M365Evidence" })

$AppsMenuChecks += New-AppCheck `
    -Id "9" `
    -Name "Install WinRAR" `
    -Type "EXE" `
    -Installed (Test-PathWildcard $CheckWinrarPaths) `
    -CheckPath (Get-PathWildcard $CheckWinrarPaths) `
    -Note "Check WinRAR installed"

$AppsMenuChecks += New-AppCheck `
    -Id "10" `
    -Name "Fix WinRAR Right Click Menu" `
    -Type "BAT" `
    -Installed (Test-PathWildcard $CheckFixWinrarBatPaths) `
    -CheckPath (Get-PathWildcard $CheckFixWinrarBatPaths) `
    -Note "Check fix_winrar_right_click.bat copied"

$AppsMenuChecks += New-AppCheck `
    -Id "11" `
    -Name "Copy Veyon Source" `
    -Type "FOLDER" `
    -Installed (Test-PathWildcard $CheckVeyonSourcePaths) `
    -CheckPath (Get-PathWildcard $CheckVeyonSourcePaths) `
    -Note "Check Veyon source copied"

$AppsMenuChecks += New-AppCheck `
    -Id "12" `
    -Name "Install Veyon Client" `
    -Type "BAT" `
    -Installed (Test-PathWildcard $CheckVeyonInstalledPaths) `
    -CheckPath (Get-PathWildcard $CheckVeyonInstalledPaths) `
    -Note "Check Veyon installed"

# =========================
# RESULT
# =========================

$result = [ordered]@{
    ip = $IP
    computer_name = $ComputerName
    user = $UserName
    last_check = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    online = $true
    local_script_ok = $true

    os_caption = $os.Caption
    os_version = $os.Version

    c_drive_free_gb = $FreeGB
    c_drive_size_gb = $SizeGB

    veyon_installed = $veyonInstalled
    veyon_path = $veyonPath
    veyon_service = if ($veyonService) { $veyonService.Status.ToString() } else { "NotFound" }

    seb_installed = $sebInstalled
    seb_path = $sebPath
    seb_service = if ($sebService) { $sebService.Status.ToString() } else { "NotFound" }

    office2016_installed = $office2016Installed
    office2016_path = $officePath

    hp_bcu_available = $hpBcuAvailable
    hp_bcu_path = $hpBcuPath

    dell_cctk_available = $dellCctkAvailable
    dell_cctk_path = $dellCctkPath

    qda_seb_file_exists = $qdaSebFileExists
    qda_seb_path = $qdaSebPath

    microsoft365_installed = $M365Installed
    microsoft365_removed = $M365Removed
    microsoft365_evidence = $M365Evidence

    wifi = $wifiText

    c_drive_hidden = $CDriveHidden
    c_drive_blocked = $CDriveBlocked
    no_drives = $NoDrives
    no_view_on_drive = $NoViewOnDrive

    apps_menu_checks = $AppsMenuChecks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $ResultPath -Encoding UTF8

Write-Log "Wrote result to $ResultPath"
Write-Log "===== QDA CLIENT STATUS LOCAL END ====="

exit 0
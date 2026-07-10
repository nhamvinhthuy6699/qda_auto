param(
    [string]$ExamFolderName = "ThiCNTT",
    [switch]$ShutdownAfterClean
)

$ErrorActionPreference = "Continue"

function Write-Line {
    param([string]$Text)
    Write-Output $Text
}

function Get-ExplorerProfilePaths {
    $profiles = @()

    try {
        $explorers = Get-CimInstance Win32_Process -Filter "name='explorer.exe'" -ErrorAction SilentlyContinue

        foreach ($p in $explorers) {
            try {
                $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue

                if ($owner.User) {
                    $userName = $owner.User
                    $profile = Join-Path "C:\Users" $userName

                    if ((Test-Path -LiteralPath $profile) -and ($profiles -notcontains $profile)) {
                        $profiles += $profile
                    }
                }
            } catch {
            }
        }
    } catch {
    }

    return $profiles
}

function Get-FallbackProfilePaths {
    $profiles = @()

    $skipNames = @(
        "Public",
        "Default",
        "Default User",
        "All Users",
        "Administrator",
        "admintest",
        "WDAGUtilityAccount"
    )

    try {
        $dirs = Get-ChildItem -LiteralPath "C:\Users" -Directory -Force -ErrorAction SilentlyContinue

        foreach ($dir in $dirs) {
            if ($skipNames -contains $dir.Name) {
                continue
            }

            if (($dir.Attributes -band [IO.FileAttributes]::Hidden) -ne 0) {
                continue
            }

            if (($dir.Attributes -band [IO.FileAttributes]::System) -ne 0) {
                continue
            }

            $desktop1 = Join-Path $dir.FullName "Desktop"
            $desktop2 = Join-Path $dir.FullName "OneDrive\Desktop"
            $downloads = Join-Path $dir.FullName "Downloads"

            if (
                (Test-Path -LiteralPath $desktop1) -or
                (Test-Path -LiteralPath $desktop2) -or
                (Test-Path -LiteralPath $downloads)
            ) {
                $profiles += $dir.FullName
            }
        }
    } catch {
    }

    return $profiles
}

function Test-IsHiddenOrSystem {
    param($Item)

    if (($Item.Attributes -band [IO.FileAttributes]::Hidden) -ne 0) {
        return $true
    }

    if (($Item.Attributes -band [IO.FileAttributes]::System) -ne 0) {
        return $true
    }

    return $false
}

function Test-KeepDesktopItem {
    param(
        [string]$Name
    )

    # Desktop chi giu:
    # - ThiCNTT
    # - Microsoft Edge
    # - UniKey / UnikeyTM / VNI
    #
    # KHONG giu Veyon Master / VeyonMaster.
    # Recycle Bin khong phai file/folder that trong Desktop folder,
    # nen script khong dung icon Recycle Bin.

    $keepPatterns = @(
        "ThiCNTT",
        "Microsoft Edge*",
        "UniKey*",
        "Unikey*",
        "UnikeyTM*",
        "UniKeyNT*",
        "VNI*",
        "Vni*",
        "vni*",
	"Shutdown_cleanup*",
	"Shutdown cleanup*",
	"Shutdown_cleanup.bat"
	"shutdown_cleanup*",
	"shutdown cleanup*",
	"shutdown_cleanup.bat"
    )

    foreach ($pattern in $keepPatterns) {
        if ($Name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Clear-FolderContent-LikeBrotherBat {
    param(
        [string]$TargetFolder
    )

    if (!(Test-Path -LiteralPath $TargetFolder)) {
        Write-Line "[WARN] Khong thay folder: $TargetFolder"
        return
    }

    Write-Line "[CLEAN] $TargetFolder"

    try {
        cmd.exe /c attrib -h -r -s "$TargetFolder\*" /s /d >nul 2>&1
    } catch {
    }

    try {
        $dirs = Get-ChildItem -LiteralPath $TargetFolder -Directory -Force -ErrorAction SilentlyContinue

        foreach ($dir in $dirs) {
            Write-Line "[DEL DIR] $($dir.FullName)"
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Line "[WARN] Loi khi xoa folder con trong $TargetFolder"
    }

    try {
        $files = Get-ChildItem -LiteralPath $TargetFolder -File -Force -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            Write-Line "[DEL FILE] $($file.FullName)"
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Line "[WARN] Loi khi xoa file trong $TargetFolder"
    }
}

function Clear-RecycleBin-Safe {
    Write-Line ""
    Write-Line "[RECYCLE BIN] Dang empty Recycle Bin..."

    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Line "[OK] Da empty Recycle Bin"
    } catch {
        Write-Line "[WARN] Clear-RecycleBin loi: $($_.Exception.Message)"
        Write-Line "[WARN] Bo qua Recycle Bin, tiep tuc cac buoc khac."
    }
}

function Ensure-And-Clean-ThiCNTT {
    param(
        [string]$DesktopPath,
        [string]$ExamFolderName
    )

    if (!(Test-Path -LiteralPath $DesktopPath)) {
        Write-Line "[WARN] Khong thay Desktop path: $DesktopPath"
        return
    }

    $examFolder = Join-Path $DesktopPath $ExamFolderName

    Write-Line ""
    Write-Line "[DESKTOP] $DesktopPath"
    Write-Line "[THICNTT] $examFolder"

    if (!(Test-Path -LiteralPath $examFolder)) {
        try {
            New-Item -ItemType Directory -Path $examFolder -Force | Out-Null
            Write-Line "[OK] Da tao folder ThiCNTT: $examFolder"
        } catch {
            Write-Line "[FAIL] Khong tao duoc ThiCNTT: $($_.Exception.Message)"
            return
        }
    }

    Clear-FolderContent-LikeBrotherBat -TargetFolder $examFolder
}

function Clear-Desktop-ExtraItems {
    param(
        [string]$DesktopPath
    )

    if (!(Test-Path -LiteralPath $DesktopPath)) {
        Write-Line "[WARN] Khong thay Desktop path: $DesktopPath"
        return
    }

    Write-Line ""
    Write-Line "[DESKTOP CLEAN] $DesktopPath"
    Write-Line "[RULE] Chi giu: ThiCNTT, Microsoft Edge, UniKey/UnikeyTM/VNI, Recycle Bin"

    $items = Get-ChildItem -LiteralPath $DesktopPath -Force -ErrorAction SilentlyContinue

    foreach ($item in $items) {
        try {
            if (Test-IsHiddenOrSystem $item) {
                Write-Line "[SKIP] Hidden/System: $($item.FullName)"
                continue
            }

            if (Test-KeepDesktopItem -Name $item.Name) {
                Write-Line "[KEEP] $($item.FullName)"
                continue
            }

            if ($item.PSIsContainer) {
                Write-Line "[DEL DESKTOP DIR] $($item.FullName)"
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Line "[DEL DESKTOP FILE] $($item.FullName)"
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Line "[FAIL] Khong xoa duoc Desktop item: $($item.FullName) | $($_.Exception.Message)"
        }
    }
}

Write-Line "=========================================="
Write-Line "        QDA CLEANUP EXAM REMOTE CLIENT"
Write-Line "=========================================="
Write-Line "Computer : $env:COMPUTERNAME"
Write-Line "Time     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Line "RunAs    : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Line ""

$profilePaths = Get-ExplorerProfilePaths

if (!$profilePaths -or $profilePaths.Count -eq 0) {
    Write-Line "[WARN] Khong tim thay user dang login qua explorer.exe."
    Write-Line "[WARN] Se fallback sang quet C:\Users de tim profile that."
    $profilePaths = Get-FallbackProfilePaths
}

if (!$profilePaths -or $profilePaths.Count -eq 0) {
    Write-Line "[FAIL] Khong tim thay profile user nao de don dep."
    exit 2
}

$profilePaths = $profilePaths | Sort-Object -Unique

Write-Line "[INFO] Profile se don dep:"
foreach ($profile in $profilePaths) {
    Write-Line " - $profile"
}

$cleanedAny = $false

foreach ($profilePath in $profilePaths) {
    $desktopNormal = Join-Path $profilePath "Desktop"
    $desktopOneDrive = Join-Path $profilePath "OneDrive\Desktop"
    $downloads = Join-Path $profilePath "Downloads"

    Write-Line ""
    Write-Line "------------------------------------------"
    Write-Line "User profile      : $profilePath"
    Write-Line "Desktop normal    : $desktopNormal"
    Write-Line "Desktop OneDrive  : $desktopOneDrive"
    Write-Line "Downloads         : $downloads"
    Write-Line "------------------------------------------"

    if (Test-Path -LiteralPath $desktopNormal) {
        Ensure-And-Clean-ThiCNTT -DesktopPath $desktopNormal -ExamFolderName $ExamFolderName
        Clear-Desktop-ExtraItems -DesktopPath $desktopNormal
    } else {
        Write-Line "[WARN] Khong thay Desktop normal: $desktopNormal"
    }

    if (Test-Path -LiteralPath $desktopOneDrive) {
        Ensure-And-Clean-ThiCNTT -DesktopPath $desktopOneDrive -ExamFolderName $ExamFolderName
        Clear-Desktop-ExtraItems -DesktopPath $desktopOneDrive
    }

    Clear-FolderContent-LikeBrotherBat -TargetFolder $downloads

    $cleanedAny = $true
}

Clear-RecycleBin-Safe

Write-Line ""
Write-Line "=========================================="
Write-Line "        CLEANUP DONE"
Write-Line "=========================================="

if ($ShutdownAfterClean) {
    Write-Line "[ACTION] Shutdown client..."
    shutdown.exe /s /f /t 0
}

if ($cleanedAny) {
    exit 0
} else {
    exit 1
}
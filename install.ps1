Write-Host "=== Installation du projet EddylianOrigin ===" -ForegroundColor Cyan

# --- Détection OS ---
function Is-Windows {
    try {
        $null = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-WindowsVersion {
    try {
        $ver = (Get-CimInstance Win32_OperatingSystem).Version
        return [version]$ver
    } catch {
        return $null
    }
}

$isWindows = Is-Windows
$winVer    = Get-WindowsVersion

if ($isWindows) {
    Write-Host "Système détecté : Windows ($($winVer.ToString()))" -ForegroundColor Cyan
} else {
    Write-Host "Système détecté : Linux/macOS" -ForegroundColor Cyan
}


Write-Host "Système détecté : $os" -ForegroundColor Cyan

# --- Détection version Windows ---
function Get-WindowsVersion {
    $ver = (Get-CimInstance Win32_OperatingSystem).Version
    return [version]$ver
}

# --- Vérifier si Winget est disponible ---
function Has-Winget {
    return (Get-Command winget.exe -ErrorAction SilentlyContinue) -ne $null
}

# --- Installer Winget si possible ---
function Install-Winget {
    Write-Host "Winget non trouvé. Tentative d'installation..." -ForegroundColor Yellow

    # Winget nécessite Windows 10 1809+ ou Windows Server 2022+
    $winVer = Get-WindowsVersion
    if ($winVer.Major -lt 10) {
        Write-Host "Winget ne peut PAS être installé sur Windows 8 / Windows Server 2012." -ForegroundColor Red
        return $false
    }

    $msix = "$env:TEMP\winget.msixbundle"
    Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $msix

    Write-Host "Installation de Winget..." -ForegroundColor Cyan
    Add-AppxPackage -Path $msix

    return $true
}

# --- Installation ImageMagick ---
function Install-ImageMagick-Windows {
    $winVer = Get-WindowsVersion

    if ($winVer.Major -lt 10) {
        Write-Host "Windows 8 / Windows Server détecté → Installation manuelle d'ImageMagick" -ForegroundColor Yellow

        $installer = "$env:TEMP\ImageMagickInstaller.exe"
        Invoke-WebRequest -Uri "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-21-Q16-HDRI-x64-dll.exe" -OutFile $installer

        Start-Process $installer -ArgumentList "/S" -Wait
        return
    }

    # Windows 10+ ou Windows Server 2022+
    if (-not (Has-Winget)) {
        $installed = Install-Winget
        if (-not $installed) {
            Write-Host "Impossible d'installer Winget → fallback installation manuelle" -ForegroundColor Yellow

            $installer = "$env:TEMP\ImageMagickInstaller.exe"
            Invoke-WebRequest -Uri "https://imagemagick.org/archive/binaries/ImageMagick-7.1.1-21-Q16-HDRI-x64-dll.exe" -OutFile $installer

            Start-Process $installer -ArgumentList "/S" -Wait
            return
        }
    }

    Write-Host "Installation d'ImageMagick via Winget..." -ForegroundColor Cyan
    winget install ImageMagick.ImageMagick --silent
}

function Install-ImageMagick-LinuxMac {
    Write-Host "Installation ImageMagick pour Linux/macOS..." -ForegroundColor Yellow

    $installer = "$env:TEMP/ImageMagick.tar.gz"
    Invoke-WebRequest -Uri "https://imagemagick.org/archive/ImageMagick.tar.gz" -OutFile $installer

    tar -xzf $installer -C /tmp
    cd /tmp/ImageMagick*
    ./configure
    make
    sudo make install

    Write-Host "ImageMagick installé sur Linux/macOS." -ForegroundColor Green
}

# --- Exécution installation ImageMagick ---
if ($isWindows) {
    Install-ImageMagick-Windows
} else {
    Install-ImageMagick-LinuxMac
}

# --- Installer Node.js dépendances ---
if (Test-Path "package.json") {
    Write-Host "Installation des dépendances Node.js..." -ForegroundColor Cyan
    npm install
}

# --- Installer Playwright browsers ---
Write-Host "Installation des navigateurs Playwright..." -ForegroundColor Cyan
npx playwright install

# --- Restaurer .NET ---
Write-Host "Restauration du projet .NET..." -ForegroundColor Cyan
dotnet restore

Write-Host "Installation terminée !" -ForegroundColor Green

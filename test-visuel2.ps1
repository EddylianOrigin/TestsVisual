<#
test-visuel.ps1
Capture Playwright + comparaison ImageMagick + rapport HTML avec bouton PDF
Affichage baseline / current / diff
Sauvegarder ce fichier en UTF-8 (avec BOM)
#>

param(
    [string]$Url = "https://yello.de",
    [string]$BaseDir = "C:\Tests",
    [int]$MaxPages = 100,
    [string]$Fuzz = "6%",
    [double]$AllowedDiffPercent = 0.5
)

# --- Préparation des dossiers ---
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$runDir = Join-Path $BaseDir "run_$timestamp"
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$baselineDir = Join-Path $BaseDir "baseline"
$reportPath  = Join-Path $runDir "rapport_visuel.html"

Write-Host "Run directory: $runDir" -ForegroundColor Cyan

# --- Capture Playwright ---
Write-Host "Capture des pages..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

try {
    if (Test-Path ".\capture.js") {
        & node .\capture.js $Url $runDir $MaxPages true
    } else {
        Write-Warning "capture.js introuvable — fallback npx playwright"
        & npx playwright screenshot "$Url" "$runDir\root.png" --full-page
    }
} catch {
    Write-Warning "Erreur Playwright : $_"
}

$capturedImages = Get-ChildItem -Path $runDir -Filter *.png
if ($capturedImages.Count -eq 0) {
    Write-Error "Aucune capture trouvée."
    exit 1
}

# --- ImageMagick ---
$MagickPath = Get-ChildItem "C:\Program Files" -Filter "magick.exe" -Recurse -ErrorAction SilentlyContinue |
              Select-Object -First 1 -ExpandProperty FullName
if (-not $MagickPath) { $MagickPath = "C:\ImageMagick\magick.exe" }
if (-not (Test-Path $MagickPath)) { Write-Error "magick.exe introuvable"; exit 1 }

Add-Type -AssemblyName System.Numerics

# --- Comparaison ---
$rows = @()

if (Test-Path $baselineDir) {

    Get-ChildItem $baselineDir -Filter *.png | ForEach-Object {

        $baseImg = $_.FullName
        $name    = $_.Name
        $newImg  = Join-Path $runDir $name

        if (-not (Test-Path $newImg)) {
            $rows += [PSCustomObject]@{
                Name = $name
                Status = "MISSING"
                DiffPercent = 100
                DiffImage = ""
            }
            return
        }

        $diffImg = Join-Path $runDir ("diff_" + [IO.Path]::GetFileNameWithoutExtension($name) + ".png")

        $compareArgs = @("compare", "-metric", "AE", "-fuzz", $Fuzz, $baseImg, $newImg, $diffImg)
        $imOutput = & $MagickPath @compareArgs 2>&1

        # Extraire le premier nombre
        $digits = ($imOutput -join "`n") -replace '[^\d]', ''
        if ($digits) {
            $diffPixels = [System.Numerics.BigInteger]::Parse($digits)
        } else {
            $diffPixels = [System.Numerics.BigInteger]::Zero
        }

        # Taille image
        $sizeOutput = & $MagickPath "identify" "-format" "%w %h" $newImg 2>&1
        $parts = ($sizeOutput -split '\s+') | Where-Object { $_ -match '^\d+$' }

        if ($parts.Count -ge 2) {
            $width  = [System.Numerics.BigInteger]::Parse($parts[0])
            $height = [System.Numerics.BigInteger]::Parse($parts[1])
            $totalPixels = $width * $height
        } else {
            $totalPixels = [System.Numerics.BigInteger]::One
        }

        # Pourcentage
        $diffPercent = ([double]$diffPixels / [double]$totalPixels) * 100
        $diffPercentRounded = [math]::Round($diffPercent, 4)

        $status = if ($diffPercentRounded -le $AllowedDiffPercent) { "OK" } else { "REGRESSION" }

        $diffImgValue = if (Test-Path $diffImg) { $diffImg } else { "" }

        $rows += [PSCustomObject]@{
            Name = $name
            Status = $status
            DiffPercent = $diffPercentRounded
            DiffImage = $diffImgValue
        }
    }

} else {
    Write-Warning "Pas de baseline — rapport simple"
    Get-ChildItem $runDir -Filter *.png | ForEach-Object {
        $rows += [PSCustomObject]@{
            Name = $_.Name
            Status = "CAPTURED"
            DiffPercent = 0
            DiffImage = ""
        }
    }
}

# --- Génération HTML (avec bouton PDF + 3 images) ---
$rowsHtml = (
    $rows | ForEach-Object {

        $baselineImg = "file:///$baselineDir/$($_.Name)"
        $currentImg  = "file:///$runDir/$($_.Name)"

        if ($_.DiffImage -and (Test-Path $_.DiffImage)) {
            $diffTag = "<img src='file:///$($_.DiffImage)' style='max-width:300px;border:1px solid #ccc;'>"
        } else {
            $diffTag = "—"
        }

        "<tr>
            <td>$($_.Name)</td>
            <td><img src='$baselineImg' style='max-width:300px;border:1px solid #ccc;'></td>
            <td><img src='$currentImg' style='max-width:300px;border:1px solid #ccc;'></td>
            <td>$diffTag</td>
            <td>$($_.Status)</td>
            <td>$($_.DiffPercent)%</td>
        </tr>"
    }
) -join "`n"

$now = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$html = @"
<!doctype html>
<html lang='fr'>
<head>
<meta charset='utf-8'>
<title>Rapport visuel - $timestamp</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f4f6f9;padding:20px}
.container{max-width:1400px;margin:0 auto;background:#fff;padding:20px;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.06)}
table{width:100%;border-collapse:collapse;margin-top:20px}
th,td{border:1px solid #ddd;padding:8px;text-align:center}
th{background:#f6f8fa}
button{padding:10px 20px;background:#0078d4;color:white;border:none;border-radius:6px;cursor:pointer;margin-bottom:20px;}
</style>
</head>
<body>
<div class='container'>
<h1>Rapport visuel</h1>

<button onclick="window.print()">Télécharger en PDF</button>

<p><strong>URL :</strong> $Url<br>
<strong>Run :</strong> $runDir<br>
<strong>Baseline :</strong> $baselineDir<br>
<strong>Généré le :</strong> $now</p>

<table>
<thead>
<tr>
<th>Page</th>
<th>Baseline</th>
<th>Actuelle</th>
<th>Différence</th>
<th>Statut</th>
<th>Diff %</th>
</tr>
</thead>
<tbody>
$rowsHtml
</tbody>
</table>

</div>
</body>
</html>
"@

Set-Content -Path $reportPath -Value $html -Encoding UTF8
Write-Host "Rapport généré : $reportPath" -ForegroundColor Green

# --- Ouverture dans Edge ---
try {
    Start-Process "msedge" -ArgumentList "--new-window", $reportPath
} catch {
    Start-Process $reportPath
}

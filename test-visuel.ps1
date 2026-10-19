<#
test-visuel.ps1
- Capture (Playwright via capture.js if present, otherwise fallback)
- Compare with ImageMagick using BigInteger
- Generate HTML report and open it in browser (Edge if available)
Save this file as UTF-8 (with BOM).
#>

param(
    [string]$Url = "",
    [string]$BaseDir = "C:\Tests",
    [int]$MaxPages = 100,
    [string]$Fuzz = "15%",                 # ImageMagick fuzz tolerance
    [double]$AllowedDiffPercent = 15     # allowed difference percent (e.g. 0.5 = 0.5%)
)

# --- Prepare folders and variables ---
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$runDir    = Join-Path $BaseDir "run_$timestamp"
New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$baselineDir = Join-Path $BaseDir "baseline"
$reportPath  = Join-Path $runDir "rapport_visuel.html"

Write-Host "Run directory: $runDir" -ForegroundColor Cyan
Write-Host "Baseline directory: $baselineDir" -ForegroundColor Cyan

# --- 1) Capture pages (Playwright) ---
Write-Host "Starting capture for $Url (max $MaxPages pages)..." -ForegroundColor Cyan
Start-Sleep -Seconds 2

try {
    if (Test-Path ".\capture.js") {
        Write-Host "Using node capture.js to capture pages..." -ForegroundColor Cyan
        & node .\capture.js $Url $runDir $MaxPages true
    } else {
        Write-Host "capture.js not found — attempting npx playwright screenshot (fallback)..." -ForegroundColor Yellow
        try {
            & npx playwright screenshot "$Url" --output "$runDir\current_root.png" --full-page
        } catch {
            try {
                & npx playwright screenshot "$Url" "$runDir\current_root.png" --full-page
            } catch {
                Write-Warning "Playwright CLI capture failed. Install Playwright or provide capture.js."
            }
        }
    }
} catch {
    Write-Warning "Capture error: $_"
}

# Ensure at least one PNG exists
$capturedImages = Get-ChildItem -Path $runDir -Filter *.png -ErrorAction SilentlyContinue
if (-not $capturedImages -or $capturedImages.Count -eq 0) {
    Write-Warning "No captures found in $runDir. Exiting."
    exit 1
}

# --- 2) Locate ImageMagick (magick.exe) ---
$MagickPath = Get-ChildItem -Path "C:\Program Files" -Filter "magick.exe" -Recurse -ErrorAction SilentlyContinue |
              Select-Object -First 1 -ExpandProperty FullName -ErrorAction SilentlyContinue
if (-not $MagickPath) { $MagickPath = "C:\ImageMagick\magick.exe" }
if (-not (Test-Path $MagickPath)) {
    Write-Error "ImageMagick (magick.exe) not found. Install ImageMagick or adjust path."
    exit 1
}
Write-Host "ImageMagick found: $MagickPath" -ForegroundColor Cyan

# Load BigInteger
Add-Type -AssemblyName System.Numerics

# --- 3) If no baseline, inform user (they can rename a run_* to baseline) ---
if (-not (Test-Path $baselineDir)) {
    Write-Host "No baseline found at $baselineDir." -ForegroundColor Yellow
    Write-Host "To create a baseline, rename the run folder to 'baseline' or copy it." -ForegroundColor Yellow
    # We'll still produce a report listing captured images
}

# --- 4) Comparison (if baseline exists) ---
$rows = @()

if (Test-Path $baselineDir) {
    Get-ChildItem -Path $baselineDir -Filter *.png | ForEach-Object {
        $baseImg = $_.FullName
        $name    = $_.Name
        $newImg  = Join-Path $runDir $name

        if (-not (Test-Path $newImg)) {
            $rows += [PSCustomObject]@{
                Name = $name
                Status = "MISSING_IN_RUN"
                DiffPercent = 100.0
                DiffImage = ""
            }
            return
        }

        $diffImg = Join-Path $runDir ("diff_" + [IO.Path]::GetFileNameWithoutExtension($name) + ".png")
        $compareArgs = @("compare", "-metric", "AE", "-fuzz", $Fuzz, $baseImg, $newImg, $diffImg)

        # Run ImageMagick compare and capture stderr (AE metric is on stderr)
        $imOutput = & $MagickPath @compareArgs 2>&1
        $exit = $LASTEXITCODE

        # Extract first group of digits (diff pixel count)
        $allText = ($imOutput -join "`n")
        if ($allText -match '(\d+)') { $digits = $Matches[1] } else { $digits = $null }

        if ($digits) {
            try { $diffPixels = [System.Numerics.BigInteger]::Parse($digits) }
            catch { $diffPixels = [System.Numerics.BigInteger]::Zero }
        } else {
            $diffPixels = [System.Numerics.BigInteger]::Zero
        }

        # Get image width/height via identify
        $identifyArgs = @("identify", "-format", "%w %h", $newImg)
        $sizeOutput = & $MagickPath @identifyArgs 2>&1
        $sizeText = ($sizeOutput -join " ")
        $sizeParts = ($sizeText -split '\s+') | Where-Object { $_ -match '^\d+$' }

        if ($sizeParts.Count -ge 2) {
            $width  = [System.Numerics.BigInteger]::Parse($sizeParts[0])
            $height = [System.Numerics.BigInteger]::Parse($sizeParts[1])
            $totalPixels = [System.Numerics.BigInteger]::Multiply($width, $height)
        } else {
            $totalPixels = [System.Numerics.BigInteger]::One
        }

        # Compute percent (convert to double for division)
        try {
            $diffPercent = ([double]::Parse([string]$diffPixels) / [double]::Parse([string]$totalPixels)) * 100.0
        } catch {
            $diffPercent = 100.0
        }
        $diffPercentRounded = [math]::Round($diffPercent, 4)

        $status = if ($diffPercent -le $AllowedDiffPercent) { "OK" } else { "REGRESSION" }

        if (Test-Path $diffImg) { $diffImgValue = $diffImg } else { $diffImgValue = "" }

        $rows += [PSCustomObject]@{
            Name = $name
            Status = $status
            DiffPercent = $diffPercentRounded
            DiffImage = $diffImgValue
        }
    }
} else {
    # No baseline: list captured images
    Get-ChildItem -Path $runDir -Filter *.png | ForEach-Object {
        $rows += [PSCustomObject]@{
            Name = $_.Name
            Status = "CAPTURED"
            DiffPercent = 0.0
            DiffImage = ""
        }
    }
}

# --- 5) Generate HTML report ---
# IMPORTANT: group the ForEach-Object result before applying -join to avoid the "RemainingScripts" error
$rowsHtml = (
    $rows | ForEach-Object {
        if ($_.DiffImage -and (Test-Path $_.DiffImage)) {
            $imgLink = "<a href='file:///$($_.DiffImage)'>Voir diff</a>"
        } else {
            $imgLink = "—"
        }
        "<tr>
            <td style='padding:8px;border:1px solid #ddd;'>$($_.Name)</td>
            <td style='padding:8px;border:1px solid #ddd;'>$($_.Status)</td>
            <td style='padding:8px;border:1px solid #ddd;'>$($_.DiffPercent)%</td>
            <td style='padding:8px;border:1px solid #ddd;'>$imgLink</td>
        </tr>"
    }
) -join "`n"

$now = Get-Date -Format "dd/MM/yyyy à HH:mm:ss"

$html = @"
<!doctype html>
<html lang='fr'>
<head>
<meta charset='utf-8'>
<title>Rapport visuel - $timestamp</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f4f6f9;padding:20px}
.container{max-width:1200px;margin:0 auto;background:#fff;padding:20px;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.06)}
table{width:100%;border-collapse:collapse;margin-top:16px}
th,td{border:1px solid #e1e4e8;padding:8px;text-align:left}
th{background:#f6f8fa}
</style>
</head>
<body>
<div class='container'>
<h1>Rapport visuel</h1>
<p><strong>URL:</strong> <a href='$Url' target='_blank'>$Url</a> &nbsp; | &nbsp; <strong>Run:</strong> $runDir &nbsp; | &nbsp; <strong>Baseline:</strong> $baselineDir</p>
<p><strong>Fuzz:</strong> $Fuzz &nbsp; | &nbsp; <strong>Seuil autorisé:</strong> $AllowedDiffPercent% &nbsp; | &nbsp; <strong>Généré le:</strong> $now</p>
<table>
<thead><tr><th>Image</th><th>Statut</th><th>Diff %</th><th>Diff</th></tr></thead>
<tbody>
$rowsHtml
</tbody>
</table>
</div>
</body>
</html>
"@

Set-Content -Path $reportPath -Value $html -Encoding UTF8
Write-Host "Report generated: $reportPath" -ForegroundColor Green

# --- 6) Open report in browser (Edge preferred) ---
$maxWait = 10
$waited = 0
while (-not (Test-Path $reportPath) -and $waited -lt $maxWait) {
    Start-Sleep -Seconds 1
    $waited++
}
if (-not (Test-Path $reportPath)) {
    Write-Warning "Report not found after $maxWait seconds: $reportPath"
} else {
    try {
        Start-Process -FilePath "msedge" -ArgumentList "--new-window", $reportPath -ErrorAction Stop
        Write-Host "Opening report in Microsoft Edge..." -ForegroundColor Cyan
    } catch {
        try {
            Start-Process -FilePath $reportPath -ErrorAction Stop
            Write-Host "Opening report with default application..." -ForegroundColor Yellow
        } catch {
            Write-Warning "Unable to open report automatically: $($_.Exception.Message)"
        }
    }
}

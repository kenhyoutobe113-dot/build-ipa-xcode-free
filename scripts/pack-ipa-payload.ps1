# Pack .app into .ipa using Payload/ folder (Windows PowerShell).
# Usage: .\scripts\pack-ipa-payload.ps1 -AppPath "path\to\HuyenThoaiUron.app" -OutputIpa "Xcode-Output\HuyenThoaiUron.ipa"
param(
    [Parameter(Mandatory = $true)]
    [string]$AppPath,

    [string]$OutputIpa = "Xcode-Output\output.ipa"
)

if (-not (Test-Path $AppPath -PathType Container)) {
    Write-Error "APP not found: $AppPath"
    exit 1
}

if ($AppPath -notmatch '\.app$') {
    Write-Error "AppPath must be a .app folder"
    exit 1
}

$appName = Split-Path $AppPath -Leaf
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("ipa-payload-" + [guid]::NewGuid().ToString("N"))
$payloadDir = Join-Path $staging "Payload"
New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null

Write-Host "==> Copying $appName -> Payload\"
Copy-Item -Path $AppPath -Destination (Join-Path $payloadDir $appName) -Recurse -Force

$outputDir = Split-Path $OutputIpa -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if (Test-Path $OutputIpa) { Remove-Item $OutputIpa -Force }

Write-Host "==> Zipping Payload -> $OutputIpa"
Push-Location $staging
try {
    Compress-Archive -Path "Payload" -DestinationPath $OutputIpa -Force
}
finally {
    Pop-Location
}

Remove-Item $staging -Recurse -Force
Write-Host "IPA ready: $OutputIpa ($((Get-Item $OutputIpa).Length / 1MB) MB)"

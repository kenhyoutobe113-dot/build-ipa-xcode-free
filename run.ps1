# One-click: Xcode zip in Xcode-Input -> GitHub Actions build -> IPA in Xcode-Output
param(
    [switch]$UploadAppStore,
    [switch]$SkipPush,
    [switch]$Setup
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
Set-Location $Root

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing '$Name'. Install it and ensure it is on PATH."
    }
}

function Write-Step($Msg) {
    Write-Host ""
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

if ($Setup) {
    Write-Step "Initial setup"
    Require-Command git
    git init 2>$null
    git lfs install 2>$null
    if (-not (Test-Path ".gitattributes")) {
        "Xcode-Input/*.zip filter=lfs diff=lfs merge=lfs -text" | Set-Content .gitattributes
    }
    git lfs track "Xcode-Input/*.zip" 2>$null
    Write-Host "Done. Next:"
    Write-Host "  1. gh auth login"
    Write-Host "  2. gh repo create ... OR git remote add origin ..."
    Write-Host "  3. Add signing secrets on GitHub"
    Write-Host "  4. Double-click run.bat"
    exit 0
}

$cfgPath = Join-Path $Root "tool/config.json"
if (-not (Test-Path $cfgPath)) { throw "Missing tool/config.json" }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
if ($UploadAppStore) { $cfg.uploadAppStore = $true }

Write-Step "Detect Xcode project from zip"
& (Join-Path $Root "tool/detect-project.ps1")
$buildCfg = Get-Content "tool/build-config.json" -Raw | ConvertFrom-Json
# Repo LFS quota is full — CI downloads the already-published Xcode zip from the web.
$buildCfg | Add-Member -NotePropertyName xcodeZipUrl -NotePropertyValue "http://103.252.95.111/files/AvatarXmen-Xcode.zip" -Force
$buildCfg | ConvertTo-Json | Set-Content "tool/build-config.json" -Encoding UTF8
$useZipUrl = -not [string]::IsNullOrWhiteSpace([string]$buildCfg.xcodeZipUrl)

Write-Step "Preflight checks"
Require-Command git
Require-Command gh

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI not authenticated. Run: gh auth login" }

$remote = git remote get-url origin 2>$null
if (-not $remote) { throw "No git remote origin. Run setup.bat then create repo." }

if (-not $SkipPush -and -not $useZipUrl) {
    Require-Command git-lfs
    git lfs install 2>$null | Out-Null
}

New-Item -ItemType Directory -Path "Xcode-Output" -Force | Out-Null

$runId = $null

if (-not $SkipPush) {
    Write-Step "Commit and push to GitHub ($($cfg.branch))"
    git add .gitattributes .gitignore .github scripts ci tool/build-config.json tool/config.json run.ps1 run.bat setup.bat
    $zipPath = $buildCfg.xcodeZip.Replace("/", "\")
    if ($useZipUrl) {
        Write-Host "Skipping git-lfs zip upload; CI will fetch $($buildCfg.xcodeZipUrl)"
    } else {
        git add $zipPath
    }
    git add -u

    $zipName = Split-Path $buildCfg.xcodeZip -Leaf
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMsg = "build: $zipName $timestamp"
    $status = git status --porcelain
    if ($status) {
        git commit -m $commitMsg
    } else {
        Write-Host "No file changes. Triggering workflow manually."
    }

    if ($cfg.uploadAppStore) {
        gh workflow run $cfg.workflowFile --ref $cfg.branch -f upload_appstore=true
        Start-Sleep -Seconds 8
        $runId = gh run list --workflow $cfg.workflowFile --branch $cfg.branch --limit 1 --json databaseId --jq ".[0].databaseId"
    } else {
        # git writes progress to stderr; with $ErrorActionPreference=Stop that aborts the script
        cmd /c "git push origin HEAD:$($cfg.branch) 2>&1"
        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
        $commit = git rev-parse HEAD
        $short = $commit.Substring(0, 7)
        Write-Host "Waiting for workflow to start (commit $short)..."
        $deadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds $cfg.pollIntervalSeconds
            $runId = gh run list --commit $commit --workflow $cfg.workflowFile --json databaseId --jq ".[0].databaseId" 2>$null
        } while (-not $runId -and (Get-Date) -lt $deadline)
        if (-not $runId) {
            $runId = gh run list --workflow $cfg.workflowFile --branch $cfg.branch --limit 1 --json databaseId --jq ".[0].databaseId"
        }
    }
} else {
    Write-Step "SkipPush - using latest workflow run"
    $runId = gh run list --workflow $cfg.workflowFile --branch $cfg.branch --limit 1 --json databaseId --jq ".[0].databaseId"
}

if (-not $runId) { throw "Could not find a GitHub Actions run." }
Write-Host "Run ID: $runId"
Write-Host "Logs: $(gh run view $runId --json url --jq ".url")"

Write-Step "Waiting for build (max $($cfg.maxWaitMinutes) min)"
gh run watch $runId --exit-status --interval $cfg.pollIntervalSeconds
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Build FAILED. Fetching log tail:" -ForegroundColor Red
    gh run view $runId --log-failed 2>$null
    throw "GitHub Actions build failed."
}

Write-Step "Download IPA to Xcode-Output"
$dlDir = Join-Path $Root "Xcode-Output\_download"
if (Test-Path $dlDir) { Remove-Item $dlDir -Recurse -Force }
New-Item -ItemType Directory -Path $dlDir -Force | Out-Null

gh run download $runId --name $buildCfg.artifactName --dir $dlDir
if ($LASTEXITCODE -ne 0) {
    gh run download $runId --dir $dlDir
}

$ipaFiles = Get-ChildItem -Path $dlDir -Filter "*.ipa" -Recurse -File
if ($ipaFiles.Count -eq 0) { throw "No .ipa found in downloaded artifacts." }

$dest = Join-Path $Root "Xcode-Output\$($buildCfg.outputIpa)"
Copy-Item $ipaFiles[0].FullName -Destination $dest -Force
Remove-Item $dlDir -Recurse -Force

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "  IPA : $dest"
Write-Host "  Size: $([math]::Round((Get-Item $dest).Length / 1MB, 2)) MB"
if ($cfg.unsignedBuild) {
    Write-Host ""
    Write-Host "IPA is UNSIGNED - user must re-sign before install:" -ForegroundColor Yellow
    Write-Host "  Sideloadly, AltStore, 3uTools, ESign (personal Apple ID / dev cert)"
}

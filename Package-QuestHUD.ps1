# Package-QuestHUD.ps1
# Creates a production-ready zip of the QuestHUD addon for WoW deployment.
#
# Usage:
#   .\Package-QuestHUD.ps1                        # builds QuestHUD-1.0.0.zip
#   .\Package-QuestHUD.ps1 -Install               # also copies to WoW AddOns folder
#   .\Package-QuestHUD.ps1 -WoWPath "D:\Games\World of Warcraft"

param(
    [switch]$Install,
    [string]$WoWPath
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$addonName = "QuestHUD"
$sourceDir = Join-Path $PSScriptRoot $addonName
$version   = (Select-String -Path "$sourceDir\$addonName.toc" -Pattern "^## Version:\s*(.+)$").Matches.Groups[1].Value.Trim()
$outDir    = Join-Path $PSScriptRoot "dist"
$stageDir  = Join-Path $outDir $addonName
$zipName   = "$addonName-$version.zip"
$zipPath   = Join-Path $outDir $zipName

Write-Host "=== Packaging $addonName v$version ===" -ForegroundColor Cyan

# ── Clean previous build ──────────────────────────────────────────────────────
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

# ── Files to include (mirrors .toc load order + supporting assets) ────────────
$includePatterns = @(
    "*.toc",
    "*.lua",
    "*.xml",
    "media\*",
    "modules\*.lua"
)

# ── Copy addon source files (excluding dev-only files) ────────────────────────
$excludeFiles = @("fetch_libs.ps1", ".pkgmeta", ".gitignore", "README.md")

foreach ($pattern in $includePatterns) {
    $files = Get-ChildItem -Path $sourceDir -Filter $pattern -File -ErrorAction SilentlyContinue
    if ($pattern -match "\\") {
        # Sub-directory pattern
        $subDir = $pattern.Split("\")[0]
        $filter = $pattern.Split("\")[1]
        $srcSub = Join-Path $sourceDir $subDir
        if (Test-Path $srcSub) {
            $destSub = Join-Path $stageDir $subDir
            New-Item -ItemType Directory -Path $destSub -Force | Out-Null
            Get-ChildItem -Path $srcSub -Filter $filter -File | Copy-Item -Destination $destSub
        }
    } else {
        foreach ($f in $files) {
            if ($excludeFiles -notcontains $f.Name) {
                Copy-Item $f.FullName -Destination $stageDir
            }
        }
    }
}

# ── Copy libs (full tree, excluding .git folders and dev files) ───────────────
$libsSrc  = Join-Path $sourceDir "libs"
$libsDest = Join-Path $stageDir "libs"

if (Test-Path $libsSrc) {
    # Copy the entire libs tree
    Copy-Item $libsSrc -Destination $libsDest -Recurse -Force

    # Remove .git directories, .github, .editorconfig, .luacheckrc, etc. from libs
    Get-ChildItem -Path $libsDest -Recurse -Directory -Filter ".git" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $libsDest -Recurse -Directory -Filter ".github" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $libsDest -Recurse -File -Include ".gitignore",".editorconfig",".luacheckrc",".pkgmeta","*.md","*.textile","*.toc" |
        Where-Object { $_.FullName -like "*\libs\*" } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# ── Validate the package ──────────────────────────────────────────────────────
Write-Host "`nValidating package..." -ForegroundColor Yellow

# Check .toc exists
$tocFile = Join-Path $stageDir "$addonName.toc"
if (-not (Test-Path $tocFile)) {
    Write-Error "FATAL: $addonName.toc not found in package!"
    exit 1
}

# Verify all files listed in .toc exist
$tocContent = Get-Content $tocFile
$missingFiles = @()
foreach ($line in $tocContent) {
    $line = $line.Trim()
    if ($line -match "^##" -or $line -eq "" -or $line -match "^#") { continue }
    $filePath = Join-Path $stageDir ($line -replace "/", "\")
    if (-not (Test-Path $filePath)) {
        $missingFiles += $line
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "WARNING: Files listed in .toc but missing from package:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
} else {
    Write-Host "  All .toc referenced files present" -ForegroundColor Green
}

# Check for leftover placeholders
$placeholderHits = Select-String -Path "$stageDir\*.lua","$stageDir\*.toc" -Pattern "@project-version@|@cf-project-name@" -ErrorAction SilentlyContinue
if ($placeholderHits) {
    Write-Host "WARNING: Unresolved placeholders found:" -ForegroundColor Red
    $placeholderHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "  No unresolved placeholders" -ForegroundColor Green
}

# Check for FarmHud references
$farmhudHits = Get-ChildItem -Path $stageDir -Recurse -Include *.lua,*.xml,*.toc |
    Where-Object { $_.FullName -notlike "*\libs\*" } |
    ForEach-Object { Select-String -Path $_.FullName -Pattern "(?i)farmhud" -ErrorAction SilentlyContinue }
if ($farmhudHits) {
    Write-Host "WARNING: FarmHud references found in addon files:" -ForegroundColor Red
    $farmhudHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
} else {
    Write-Host "  No FarmHud references in addon files" -ForegroundColor Green
}

# File count summary
$fileCount = (Get-ChildItem -Path $stageDir -Recurse -File).Count
Write-Host "  Total files: $fileCount" -ForegroundColor Green

# ── Create zip ────────────────────────────────────────────────────────────────
Write-Host "`nCreating $zipName..." -ForegroundColor Yellow
Compress-Archive -Path $stageDir -DestinationPath $zipPath -Force
$zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host "  Created: $zipPath ($zipSize KB)" -ForegroundColor Green

# ── Optional: Install to WoW AddOns folder ───────────────────────────────────
if ($Install) {
    # Auto-detect WoW path if not provided
    if (-not $WoWPath) {
        $defaultPaths = @(
            "C:\Program Files (x86)\World of Warcraft",
            "C:\Program Files\World of Warcraft",
            "D:\World of Warcraft",
            "D:\Games\World of Warcraft"
        )
        foreach ($p in $defaultPaths) {
            if (Test-Path $p) { $WoWPath = $p; break }
        }
    }

    if (-not $WoWPath) {
        Write-Host "WARNING: Could not find WoW installation. Use -WoWPath to specify." -ForegroundColor Red
    } else {
        $addonsDir = Join-Path $WoWPath "_retail_\Interface\AddOns\$addonName"
        Write-Host "`nInstalling to: $addonsDir" -ForegroundColor Yellow

        if (Test-Path $addonsDir) {
            Remove-Item $addonsDir -Recurse -Force
        }
        Copy-Item $stageDir -Destination $addonsDir -Recurse -Force
        Write-Host "  Installed successfully. /reload in-game to load." -ForegroundColor Green
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan

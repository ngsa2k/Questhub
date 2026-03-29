# fetch_libs.ps1  — Fetch QuestHUD library dependencies for local development.
# Run from the QuestHUD repo root:  .\fetch_libs.ps1
# Requires: git (with git-svn for CurseForge repos)

$ErrorActionPreference = "Continue"
$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }
$libsDir = Join-Path $root "libs"

if (-not (Test-Path $libsDir)) {
    New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
}

Push-Location $libsDir

function Clone-Git {
    param([string]$url, [string]$dest)
    if (Test-Path $dest) { Write-Host "  SKIP  $dest (already exists)" ; return }
    Write-Host "  GIT   $url -> $dest"
    git clone --depth 1 $url $dest 2>&1 | Out-Null
    if (-not (Test-Path $dest)) { Write-Warning "Failed to clone $url" }
}

function Clone-SvnViaGit {
    param([string]$url, [string]$dest)
    if (Test-Path $dest) { Write-Host "  SKIP  $dest (already exists)" ; return }
    $temp = "${dest}-svntmp"
    Write-Host "  SVN   $url -> $dest"
    git svn clone $url $temp 2>&1 | Out-Null
    if (Test-Path $temp) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Copy-Item "$temp\*" $dest -Recurse -Force
        # Clean up temp
        try { Remove-Item $temp -Recurse -Force 2>$null } catch {}
    } else {
        Write-Warning "Failed to svn-clone $url"
    }
}

function Extract-Ace3 {
    param([string[]]$subfolders)
    $ace3 = "_Ace3_temp"
    if (-not (Test-Path $ace3)) {
        Write-Host "  GIT   Ace3 (WoWUIDev) -> $ace3"
        git clone --depth 1 https://github.com/WoWUIDev/Ace3.git $ace3 2>&1 | Out-Null
    }
    foreach ($sub in $subfolders) {
        if (Test-Path $sub) { Write-Host "  SKIP  $sub (already exists)" ; continue }
        $src = Join-Path $ace3 $sub
        if (Test-Path $src) {
            Copy-Item $src $sub -Recurse -Force
            Write-Host "  COPY  $sub (from Ace3)"
        } else {
            Write-Warning "$sub not found in Ace3 repo"
        }
    }
}

Write-Host "Fetching QuestHUD library dependencies..."
Write-Host ""

# Ace3-based libs (LibStub, CallbackHandler, AceGUI, AceConfig)
Extract-Ace3 @("LibStub", "CallbackHandler-1.0", "AceGUI-3.0", "AceConfig-3.0")

# GitHub-hosted libs
Clone-Git "https://github.com/Nevcairiel/HereBeDragons.git" "HereBeDragons"
Clone-Git "https://github.com/tekkub/libdatabroker-1-1.git" "LibDataBroker-1.1"
Clone-Git "https://github.com/HizurosWoWAddOns/LibColors-1.0.git" "LibColors-1.0"

# CurseForge SVN-only libs (requires git-svn)
Clone-SvnViaGit "https://repos.curseforge.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0" "LibDBIcon-1.0"

# Verify
Write-Host ""
Write-Host "Verification:"
$checks = @(
    "LibStub\LibStub.lua",
    "CallbackHandler-1.0\CallbackHandler-1.0.lua",
    "AceGUI-3.0\AceGUI-3.0.xml",
    "AceConfig-3.0\AceConfig-3.0.xml",
    "LibDataBroker-1.1\LibDataBroker-1.1.lua",
    "LibDBIcon-1.0\LibDBIcon-1.0.lua",
    "HereBeDragons\HereBeDragons-2.0.lua",
    "HereBeDragons\HereBeDragons-Pins-2.0.lua",
    "HereBeDragons\HereBeDragons-Migrate.lua",
    "LibColors-1.0\LibColors-1.0.xml"
)
$missing = 0
foreach ($f in $checks) {
    if (Test-Path $f) {
        Write-Host "  OK      $f"
    } else {
        Write-Host "  MISSING $f"
        $missing++
    }
}

Pop-Location

if ($missing -eq 0) {
    Write-Host ""
    Write-Host "All libraries fetched successfully." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "$missing library file(s) missing. Check warnings above." -ForegroundColor Yellow
}

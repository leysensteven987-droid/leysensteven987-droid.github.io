# install-eotm.ps1 - PUBLIC one-liner bootstrapper for Echoes of the Monarch
# (private repo). PERSONAL project.
#
#   irm https://kage-gumi.com/install-eotm.ps1 | iex
#
# The EOTM repo is PRIVATE, so an unauthenticated raw fetch of the installer would
# 404. This tiny public stub ensures git + GitHub CLI, authenticates you once via
# `gh auth login`, clones the private repo, and hands off to the in-repo installer.
#
# Optional toggle (set BEFORE the pipe; | iex cannot take parameters):
#   $env:EOTM_NOMEMORY='1'    # skip the git-backed memory pull

$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/leysensteven987-droid/echoesofthemonarch.git"
$dest    = "C:\dev\echoesofthemonarch"

function Ensure-Cli {
  param([string]$Cmd, [string]$WingetId, [string]$Label)
  if (Get-Command $Cmd -ErrorAction SilentlyContinue) { return }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "$Label ($Cmd) is missing and winget is unavailable - install $Label by hand, then re-run."
  }
  Write-Host "Installing $Label via winget..." -ForegroundColor Cyan
  winget install -e --id $WingetId --accept-source-agreements --accept-package-agreements
  $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path","User")
  if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
    throw "$Label still not on PATH after install - open a new terminal and re-run the one-liner."
  }
}

Write-Host "`n== Echoes of the Monarch laptop bootstrap ==`n" -ForegroundColor Magenta
Ensure-Cli -Cmd git -WingetId 'Git.Git'    -Label 'Git'
Ensure-Cli -Cmd gh  -WingetId 'GitHub.cli' -Label 'GitHub CLI'

# gh auth login's interactive TUI does NOT work when this script is run via
# `irm | iex` (no live TTY for the arrow-key menus), so we do NOT launch it
# inline. If not authed, stop cleanly with instructions. A GH_TOKEN/GITHUB_TOKEN
# env var is honored automatically by gh and needs no login.
& gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "`n----------------------------------------------------------" -ForegroundColor Yellow
  Write-Host " GitHub sign-in needed (the EOTM repo is private)." -ForegroundColor Yellow
  Write-Host " Run this ONCE in this window, then re-run the one-liner:" -ForegroundColor Yellow
  Write-Host "`n    gh auth login" -ForegroundColor White
  Write-Host "`n (Choose: GitHub.com  ->  HTTPS  ->  Login with a web browser.)" -ForegroundColor Yellow
  Write-Host " Have a PAT? Set `$env:GH_TOKEN='<token>'` instead - no login prompt." -ForegroundColor Yellow
  Write-Host "----------------------------------------------------------`n" -ForegroundColor Yellow
  return
}
gh auth setup-git 2>$null | Out-Null

New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
if (Test-Path (Join-Path $dest ".git")) {
  Write-Host "Repo already at $dest - fetching latest (ff-only)..." -ForegroundColor Cyan
  git -C $dest fetch origin
  git -C $dest merge --ff-only origin/main 2>$null | Out-Null
} else {
  Write-Host "Cloning $repoUrl -> $dest ..." -ForegroundColor Cyan
  git clone $repoUrl $dest
}

$installer = Join-Path $dest "scripts\bootstrap-eotm-laptop.ps1"
$argList = @('-ExecutionPolicy','Bypass','-File',$installer)
if ($env:EOTM_NOMEMORY) { $argList += '-NoMemory' }

Write-Host "`nHanding off to the in-repo installer:`n  powershell $($argList -join ' ')`n" -ForegroundColor Cyan
& powershell @argList

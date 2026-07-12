# install-kg.ps1 - PUBLIC one-liner bootstrapper for Kage-gumi (private repo).
#
#   irm https://kage-gumi.com/install-kg.ps1 | iex
#
# The KG repo is PRIVATE, so an unauthenticated raw fetch of the installer would
# 404. This tiny public stub ensures git + GitHub CLI, authenticates you once via
# `gh auth login`, clones the private repo, and hands off to the in-repo installer.
#
# WORK-SAFE (Veralto/Esko-managed laptop) - set env vars BEFORE the pipe, since
# `| iex` cannot take parameters. Work-safe SKIPS Tailscale, secrets, Cho, the
# personal sibling repos, Shadow Veil and PM2:
#   $env:KG_WORKSAFE='1'; irm https://kage-gumi.com/install-kg.ps1 | iex
# Optional toggles (any non-empty value = on):
#   $env:KG_WITHSECRETS='1'   # work-safe: also unlock onelindt-dev WebCenter creds
#   $env:KG_NOMEMORY='1'      # skip the git-backed memory pull

$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/leysensteven987-droid/kage-gumi.git"
$dest    = "C:\dev\kage-gumi"

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

Write-Host "`n== Kage-gumi laptop bootstrap ==`n" -ForegroundColor Magenta
Ensure-Cli -Cmd git -WingetId 'Git.Git'    -Label 'Git'
Ensure-Cli -Cmd gh  -WingetId 'GitHub.cli' -Label 'GitHub CLI'

# One-time interactive auth (private clone needs it). No-op if already logged in.
& gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "GitHub auth required - launching 'gh auth login' (interactive)..." -ForegroundColor Cyan
  gh auth login
  if ($LASTEXITCODE -ne 0) { throw "gh auth login failed - re-run the one-liner once authenticated." }
}
# Make git use gh's credentials for github.com.
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

# Build the in-repo installer arg list from env toggles (| iex passes no params).
$installer = Join-Path $dest "scripts\bootstrap-kg-laptop.ps1"
$argList = @('-ExecutionPolicy','Bypass','-File',$installer)
if ($env:KG_WORKSAFE)    { $argList += '-WorkSafe' }
if ($env:KG_WITHSECRETS) { $argList += '-WithSecrets' }
if ($env:KG_NOMEMORY)    { $argList += '-NoMemory' }

Write-Host "`nHanding off to the in-repo installer:`n  powershell $($argList -join ' ')`n" -ForegroundColor Cyan
& powershell @argList

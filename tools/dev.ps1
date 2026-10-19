# Starts Rojo and pulls the latest code from GitHub every 30 seconds, so changes
# pushed to the repo show up in Studio automatically (Studio must be connected to Rojo).
# Start it by double-clicking dev.bat in the project folder. Close the window to stop.

$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

$PullSeconds = 30

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is not installed. Get it from https://git-scm.com/download/win and try again." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}
if (-not (Test-Path ".git")) {
    Write-Host "This folder isn't linked to GitHub (no .git folder). Clone the repo with git first." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# Use rojo.exe from this folder if it's here, otherwise the one on PATH (Rokit).
$rojo = if (Test-Path ".\rojo.exe") { (Resolve-Path ".\rojo.exe").Path } else { "rojo" }
$server = Start-Process -FilePath $rojo -ArgumentList "serve" -NoNewWindow -PassThru
Write-Host "Rojo is running. Click Connect in Studio's Rojo plugin." -ForegroundColor Green
Write-Host "Checking GitHub for updates every $PullSeconds seconds..." -ForegroundColor Green

try {
    while ($true) {
        $before = git rev-parse HEAD
        $output = git pull --ff-only 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Couldn't update (did you edit files in this folder?): $output" -ForegroundColor Yellow
        } else {
            $after = git rev-parse HEAD
            if ($before -ne $after) {
                $message = git log -1 --format=%s
                Write-Host "$(Get-Date -Format HH:mm) Updated: $message" -ForegroundColor Cyan
                Write-Host "  If you're in Play mode, press Stop and Play again to use the new code." -ForegroundColor Cyan
            }
        }
        Start-Sleep -Seconds $PullSeconds
    }
} finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id }
}

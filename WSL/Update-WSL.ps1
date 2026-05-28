# Check if WSL is installed
$wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslExe) {
    Write-Warning "WSL is not installed. Run 'wsl.exe --install' to install it."
    return
}

# Get current WSL version — capture output and strip null bytes
$versionOutput = wsl --version 2>&1
$versionString = (($versionOutput -join '') -replace '\x00', '').Trim()

# If version info is not present in output, WSL is not installed
$currentVersion = if ($versionString -match 'WSL version:\s*(\d+\.\d+\.\d+\.\d+)') { $matches[1] } else { $null }

if (-not $currentVersion) {
    Write-Output "WSL is not installed. Run 'wsl.exe --install' to install it."
    exit 0
}

Write-Host $versionOutput

if (-not $currentVersion) {
    Write-Warning "Could not determine current WSL version. Running update anyway."
    wsl --update
}
else {
    # Fetch latest release version from GitHub
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/WSL/releases/latest' -Headers @{ 'User-Agent' = 'PowerShell' }
        $latestVersion = $release.tag_name -replace '^v', ''
    }
    catch {
        Write-Warning "Could not fetch latest WSL version from GitHub: $_"
        $latestVersion = $null
    }

    if (-not $latestVersion) {
        Write-Warning "Unable to determine latest version. Running update anyway."
        wsl --update
    }
    elseif ([version]$latestVersion -gt [version]$currentVersion) {
        Write-Host "WSL update available: $currentVersion -> $latestVersion. Updating..."
        wsl --update
    }
    else {
        Write-Host "The most recent version of Windows Subsystem for Linux is already installed."
        exit 0
    }
}
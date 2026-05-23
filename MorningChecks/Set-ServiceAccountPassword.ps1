<#
.SYNOPSIS
    One-time setup: saves the service-account password so the morning checks
    script can run on a schedule without prompting.

.DESCRIPTION
    HOW IT WORKS
    ------------
    This script asks you for the service-account password, encrypts it using
    AES-256, and writes the encrypted value into Config\settings.psd1.

    The AES key is derived from the service account name (SHA-256 hash).
    This means the encrypted value works on ANY machine -- you only need
    to run this script once, from anywhere.

    STEP-BY-STEP
    ------------
    1. Open PowerShell on any machine.

        2. Run:
            Set-Location '<path-to-UpdatedVersion>'
            .\Set-ServiceAccountPassword.ps1

    3. A password prompt will appear -- enter the service-account password.

    4. The script saves the encrypted password to Config\settings.psd1.
       Start-MorningChecks.ps1 will now run without prompting on any machine.

    TO CLEAR THE PASSWORD (revert to interactive prompt):
       Open Config\settings.psd1 and set:  ServiceAccountPassword = ''

    TO UPDATE THE PASSWORD (e.g. after a password change):
       Simply run this script again -- it will overwrite the old value.
#>

#Requires -Version 5.1

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Morning Checks -- Service Account Password Setup" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Locate settings.psd1 ─────────────────────────────────────────────────────

$settingsPath = Join-Path $PSScriptRoot 'Config\settings.psd1'

if (-not (Test-Path $settingsPath)) {
    Write-Host "[ERROR] Could not find: $settingsPath" -ForegroundColor Red
    Write-Host "        Make sure you are running this script from the UpdatedVersion folder." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$settings = Import-PowerShellDataFile $settingsPath
$userName = "$($settings.ServiceAccountName)@example.com"

# ── Show context to user ──────────────────────────────────────────────────────

Write-Host "  Running as    : $env:USERDOMAIN\$env:USERNAME" -ForegroundColor Yellow
Write-Host "  Target account: $userName" -ForegroundColor Yellow
Write-Host "  Settings file : $settingsPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "  The password will be encrypted with AES-256 (key derived from the"
  Write-Host "  service account name) and will work on any machine."
Write-Host ""



# ── Prompt for password ───────────────────────────────────────────────────────

$cred = Get-Credential -UserName $userName -Message "Enter the password for $userName"
if ($null -eq $cred) {
    Write-Host ""
    Write-Host "  Cancelled -- no changes made." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

# ── Encrypt and save ──────────────────────────────────────────────────────────

# Derive a 32-byte AES-256 key from the service account name (SHA-256).
# This is consistent on any machine so the encrypted blob is fully portable.
$aesKey   = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($settings.ServiceAccountName))
$encrypted = $cred.Password | ConvertFrom-SecureString -Key $aesKey

$content = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
$updated = $content -replace "(ServiceAccountPassword\s*=\s*)'[^']*'", "`$1'$encrypted'"

if ($updated -eq $content) {
    Write-Host ""
    Write-Host "  [ERROR] Could not find the ServiceAccountPassword entry in settings.psd1." -ForegroundColor Red
    Write-Host "          No changes were made." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$utf8bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($settingsPath, $updated, $utf8bom)

# ── Verify round-trip ─────────────────────────────────────────────────────────

try {
    $verify = ConvertTo-SecureString $encrypted -Key $aesKey -ErrorAction Stop
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($verify)
    $null = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $verified = $true
}
catch {
    $verified = $false
}

Write-Host ""
if ($verified) {
    Write-Host "  [OK] Password encrypted and saved successfully." -ForegroundColor Green
    Write-Host "       Start-MorningChecks.ps1 will now run without prompting." -ForegroundColor Green
}
else {
    Write-Host "  [WARNING] Password was saved but the verification decrypt failed." -ForegroundColor Yellow
    Write-Host "            This may happen if you run as a different account later." -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to exit"

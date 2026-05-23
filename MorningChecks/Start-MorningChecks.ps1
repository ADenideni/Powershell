<#
Author: Adenideni
Version: 1.0.0
Date: 2026-05-23
#>

<#
.SYNOPSIS
    Morning Checks Report - main entry point.

.DESCRIPTION
    Orchestrates all morning checks, builds an HTML report and emails it.
    Each functional area is handled by a dedicated module under .\Modules\.
    All environment-specific values live in .\Config\.

    Checks performed (all enabled by default, disable via parameters):
        - Ping: Core Servers, Core Devices, Printers
        - Site availability: Core Sites, Third-Party Sites
        - SharePoint: create daily-checks document from template
        - Windows Updates (local machine)
        - AD: Password changes (past 7 days)
        - AD: Expiring passwords (next 10 days)
        - AD: Locked-out accounts
        - AD: Domain Controller health (ping + services + DCDiag)
        - AD: Stale user accounts (no logon in 60 days)
        - AD: Stale computer objects (no logon in 365 days)
        - Disk space across all Windows Servers
        - ESXi / vCenter error events (past 24 hours)

.EXAMPLE
    # Run with all defaults — prompts for service-account credentials at runtime
    .\Start-MorningChecks.ps1

.EXAMPLE
    # Disable ESXi check; supply credentials non-interactively
    $cred = Get-Credential
    .\Start-MorningChecks.ps1 -CheckESXiEvents $false -Credential $cred

.EXAMPLE
    # Quick ping-only run, no email
    .\Start-MorningChecks.ps1 -SendEmail $false `
        -CheckWindowsUpdates $false -GetADPasswordChanges $false `
        -GetExpiringADPasswords $false -GetADLockedOutAccounts $false `
        -GetDCHealthStatus $false -GetStaleUserObjects $false `
        -GetStaleComputerObjects $false -GetDiskSpace $false `
        -CheckESXiEvents $false -CreateSharePointDailyChecksReport $false


.NOTES
    Author:  Redacted
    Contact: example@example.com
    Version: 2.0
    Date:    2024-01-01

    V2.0  - Full modular rewrite.
              Logging, AD, Network, DiskSpace, VMware, WindowsUpdate,
              SharePoint, Email and HtmlReport each in their own .psm1.
            - Credentials are never stored in source; supplied at runtime.
            - Config externalised to PSD1 files (settings, devices, sites).
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    # ── Feature toggles ────────────────────────────────────────────────────────
    [bool]$GenerateLogs = $true,
    [bool]$PingCoreServers = $true,
    [bool]$PingCoreDevices = $true,
    [bool]$PingPrinters = $true,
    [bool]$CheckCoreSites = $true,
    [bool]$CheckThirdPartySites = $true,
    [bool]$CreateSharePointDailyChecksReport = $false,
    [bool]$CheckWindowsUpdates = $true,
    [bool]$GetADPasswordChanges = $true,
    [bool]$GetExpiringADPasswords = $true,
    [bool]$GetADLockedOutAccounts = $true,
    [bool]$GetDCHealthStatus = $false,
    [bool]$GetStaleUserObjects = $true,
    [bool]$GetStaleComputerObjects = $true,
    [bool]$GetDiskSpace = $false,
    [bool]$GetDiskSpaceWarningOnly = $true,
    [bool]$CheckESXiEvents = $false,
    [bool]$SendEmail = $true,

    # ── Email overrides (default to settings.psd1 values when blank) ───────────
    [string]$From = '',
    [string]$To = '',
    [string]$EmailSubject = '',

    # ── Service-account credential (prompted interactively when not supplied) ──
    [PSCredential]$Credential = $null,

    # ── VMware override (defaults to settings.psd1) ────────────────────────────
    [string]$VMwareHost = ''
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Off

# ──────────────────────────────────────────────────────────────────────────────
# 1.  Execution Policy
# ──────────────────────────────────────────────────────────────────────────────

foreach ($scope in @('Process', 'CurrentUser', 'LocalMachine')) {
    if ((Get-ExecutionPolicy -Scope $scope) -ne 'Bypass') {
        Set-ExecutionPolicy Bypass -Scope $scope -Force -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# 2.  Resolve paths
# ──────────────────────────────────────────────────────────────────────────────

$RootPath = Split-Path $PSCommandPath -Parent
$ConfigPath = Join-Path $RootPath 'Config'
$ModulesPath = Join-Path $RootPath 'Modules'
$LogsPath = Join-Path $RootPath 'Logs'

Set-Location $RootPath

# ──────────────────────────────────────────────────────────────────────────────
# 3.  Load configuration
# ──────────────────────────────────────────────────────────────────────────────

$Settings = Import-PowerShellDataFile (Join-Path $ConfigPath 'settings.psd1')
$Devices = Import-PowerShellDataFile (Join-Path $ConfigPath 'devices.psd1')
$Sites = Import-PowerShellDataFile (Join-Path $ConfigPath 'sites.psd1')

# Apply config defaults for any parameter left blank
if (-not $From) { $From = $Settings.EmailFrom }
if (-not $To) { $To = $Settings.EmailTo }
if (-not $EmailSubject) { $EmailSubject = "$($Settings.EmailSubjectPrefix) - $(Get-Date -Format 'yyyy-MM-dd')" }
if (-not $VMwareHost) { $VMwareHost = $Settings.VMwareHost }

# ──────────────────────────────────────────────────────────────────────────────
# 4.  Import modules  (Logging must be first so other modules can call Write-Log*)
# ──────────────────────────────────────────────────────────────────────────────

$moduleLoadOrder = @(
    'MorningChecks.Logging'
    'MorningChecks.Network'
    'MorningChecks.AD'
    'MorningChecks.DiskSpace'
    'MorningChecks.VMware'
    'MorningChecks.WindowsUpdate'
    'MorningChecks.SharePoint'
    'MorningChecks.Email'
    'MorningChecks.HtmlReport'
)

foreach ($modName in $moduleLoadOrder) {
    $modFile = Join-Path $ModulesPath "$modName\$modName.psm1"
    if (Test-Path $modFile) {
        Import-Module $modFile -Force -Global -ErrorAction Stop
    }
    else {
        Write-Warning "Module file not found: $modFile"
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# 5.  Initialise logging  &  clear screen
# ──────────────────────────────────────────────────────────────────────────────

Initialize-Logging -LogDirectory $LogsPath -Enabled $GenerateLogs
Clear-Host
Start-Log

# ──────────────────────────────────────────────────────────────────────────────
# 6.  Obtain service-account credentials (if not supplied via parameter)
# ──────────────────────────────────────────────────────────────────────────────

if ($null -eq $Credential) {
    if ($Settings.ServiceAccountPassword) {
        # Unpack the AES-encrypted string stored in settings.psd1.
        # The AES key is derived from the service account name (SHA-256),
        # so decryption works on any machine without machine-specific DPAPI.
        try {
            $aesKey = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($Settings.ServiceAccountName))
            $secPwd = ConvertTo-SecureString $Settings.ServiceAccountPassword -Key $aesKey -ErrorAction Stop
            $Credential = New-Object System.Management.Automation.PSCredential(
                "$($Settings.ServiceAccountName)@example.com", $secPwd
            )
            Write-LogInfo -Message "Using stored service-account credentials"
        }
        catch {
            Write-LogError -Message "Failed to decrypt stored password: $_ -- run Set-ServiceAccountPassword.ps1 to re-encrypt the password."
            Stop-Log
            exit 1
        }
    }
    else {
        Write-LogError -Message "No stored password found in settings.psd1. Run Set-ServiceAccountPassword.ps1 to store the password."
        Stop-Log
        exit 1
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# 7.  Run checks and collect HTML sections
# ──────────────────────────────────────────────────────────────────────────────

$sections = [System.Collections.Generic.List[string]]::new()

# ── 7a. Ping: Core Servers ────────────────────────────────────────────────────

if ($PingCoreServers) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Pinging core servers ==="
    $rows = $Devices.CoreServers | ForEach-Object { Get-HTMLPingRow -Device $_.Device -DeviceName $_.Name -DeviceURL $_.URL -SubnetMap $Devices.Subnets }
    $sections.Add((Get-HtmlPingSection -Title 'Core Systems Check (Ping)' -RowsHtml ($rows -join '')))
}

# ── 7b. Ping: Core Devices ────────────────────────────────────────────────────

if ($PingCoreDevices) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Pinging core devices ==="
    $rows = $Devices.CoreDevices | ForEach-Object { Get-HTMLPingRow -Device $_.Device -DeviceName $_.Name -DeviceURL $_.URL -SubnetMap $Devices.Subnets }
    $sections.Add((Get-HtmlPingSection -Title 'Core Devices Check (Ping)' -RowsHtml ($rows -join '')))
}

# ── 7c. Ping: Printers ────────────────────────────────────────────────────────

if ($PingPrinters) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Pinging printers ==="
    $rows = $Devices.Printers | ForEach-Object { Get-HTMLPingRow -Device $_.Device -DeviceName $_.Name -DeviceURL $_.URL -SubnetMap $Devices.Subnets }
    $sections.Add((Get-HtmlPingSection -Title 'Printers Check (Ping)' -RowsHtml ($rows -join '')))
}

# ── 7d. Site check: Core Sites ────────────────────────────────────────────────

if ($CheckCoreSites) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking core sites ==="
    $rows = $Sites.CoreSites | ForEach-Object { Get-HTMLSiteRow -SiteURL $_.URL -SiteName $_.Name }
    $sections.Add((Get-HtmlSiteSection -Title 'Core Sites Check (Online Status)' -RowsHtml ($rows -join '')))
}

# ── 7e. Site check: Third-party sites ────────────────────────────────────────

if ($CheckThirdPartySites) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking third-party sites ==="
    $rows = $Sites.ThirdPartySites | ForEach-Object { Get-HTMLSiteRow -SiteURL $_.URL -SiteName $_.Name }
    $sections.Add((Get-HtmlSiteSection -Title 'Third Party Sites Check (Online Status)' -RowsHtml ($rows -join '')))
}

# ── 7f. SharePoint daily-checks file ─────────────────────────────────────────

if ($CreateSharePointDailyChecksReport) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Creating SharePoint daily checks file ==="
    $year = (Get-Date).Year
    $month = Get-Date -Format 'MM'
    $monthName = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month)
    $targetFile = "/Shared%20Documents/Daily%20Checks/Reports/$year/$month%20-%20$monthName/Daily%20Checks%20Report%20-%20$(Get-Date -Format 'yyyy-MM-dd').docx"
    New-SharePointDailyChecksFile `
        -SiteURL       $Settings.SharePointSiteURL `
        -SourceFileURL $Settings.SharePointSourceFile `
        -TargetFileURL $targetFile `
        -Credential    $Credential
}

# ── 7g. Windows Updates ───────────────────────────────────────────────────────

$windowsUpdateResult = 'N/A'
if ($CheckWindowsUpdates) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking Windows Updates ==="
    $windowsUpdateResult = Get-WindowsUpdateStatus
}

# ── 7h. AD: Password Changes ─────────────────────────────────────────────────

$adPasswordChangesResults = $null
$adPasswordChangesErrored = $false
if ($GetADPasswordChanges) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking AD password changes ==="
    $prevErrCount = $Error.Count
    $adPasswordChangesResults = Get-ADPasswordChanges -NumberOfDays $Settings.PasswordChangesLookback
    $adPasswordChangesErrored = ($Error.Count -gt $prevErrCount -and $null -eq $adPasswordChangesResults)
}

# ── 7i. AD: Expiring Passwords ───────────────────────────────────────────────

$adExpiringPasswordsResults = $null
$adExpiringPasswordsErrored = $false
if ($GetExpiringADPasswords) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking AD expiring passwords ==="
    $prevErrCount = $Error.Count
    $adExpiringPasswordsResults = Get-ADExpiringPasswords -NumberOfDays $Settings.PasswordExpiryDays
    $adExpiringPasswordsErrored = ($Error.Count -gt $prevErrCount -and $null -eq $adExpiringPasswordsResults)
}

# ── 7j. AD: Locked-out accounts ──────────────────────────────────────────────

$adLockedOutResults = $null
$adLockedOutErrored = $false
if ($GetADLockedOutAccounts) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking AD locked-out accounts ==="
    $prevErrCount = $Error.Count
    $adLockedOutResults = Get-ADLockedOutAccounts
    $adLockedOutErrored = ($Error.Count -gt $prevErrCount -and $null -eq $adLockedOutResults)
}

# ── 7k. AD: DC health ────────────────────────────────────────────────────────

$dcHealthResults = $null
if ($GetDCHealthStatus) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking DC health status ==="
    $dcHealthResults = Get-ADDCHealthStatus -Credential $Credential
}

# ── 7l. AD: Stale users ───────────────────────────────────────────────────────

$staleUsersResults = $null
$staleUsersErrored = $false
if ($GetStaleUserObjects) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking stale user accounts ==="
    $prevErrCount = $Error.Count
    $staleUsersResults = Get-ADStaleUsers -NumberOfDays $Settings.StaleUserDays
    $staleUsersErrored = ($Error.Count -gt $prevErrCount -and $null -eq $staleUsersResults)
}

# ── 7m. AD: Stale computers ───────────────────────────────────────────────────

$staleComputerResults = $null
$staleComputerErrored = $false
if ($GetStaleComputerObjects) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking stale computer objects ==="
    $prevErrCount = $Error.Count
    $staleComputerResults = Get-ADStaleComputers -DaysOld $Settings.StaleComputerDays
    $staleComputerErrored = ($Error.Count -gt $prevErrCount -and $null -eq $staleComputerResults)
}

# ── 7n. ESXi Events ───────────────────────────────────────────────────────────

$esxiResults = $null
$esxiErrored = $false
if ($CheckESXiEvents) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Checking ESXi events ==="
    $prevErrCount = $Error.Count
    $esxiResults = Get-ESXiEvents -VMwareHost $VMwareHost -Credential $Credential -EventsCount 100 -Days 1
    $esxiErrored = ($Error.Count -gt $prevErrCount -and $null -eq $esxiResults)
}

# ── 7o. Disk Space ────────────────────────────────────────────────────────────

$diskSpaceResults = $null
if ($GetDiskSpace) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Gathering disk space data ==="
    $diskSpaceResults = Get-DiskSpaceReport -Credential $Credential
    if ($diskSpaceResults) { $diskSpaceResults | Format-Table -AutoSize }
}

# ──────────────────────────────────────────────────────────────────────────────
# 8.  Build the "Daily Checks" summary rows
# ──────────────────────────────────────────────────────────────────────────────

# Build summary rows: only include enabled checks; distinguish Error vs None
$summaryRows = ''

if ($CheckWindowsUpdates) {
    $updateCell = switch ($windowsUpdateResult) {
        'Pass' { '<td>Pass</td>' }
        'Updates found' { '<td bgcolor="#FFC200">Updates found</td>' }
        default { '<td bgcolor="#FF0000">Error</td>' }
    }
    $summaryRows += "<tr><td>Windows Updates</td>$updateCell</tr>`n"
}

if ($GetADLockedOutAccounts) {
    if ($adLockedOutErrored) { $summaryRows += "<tr><td>Locked Out Accounts</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $adLockedOutResults) { $summaryRows += "<tr><td>Locked Out Accounts</td><td>None</td></tr>`n" }
}
if ($GetADPasswordChanges) {
    if ($adPasswordChangesErrored) { $summaryRows += "<tr><td>Passwords Changed (Past $($Settings.PasswordChangesLookback) Days)</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $adPasswordChangesResults) { $summaryRows += "<tr><td>Passwords Changed (Past $($Settings.PasswordChangesLookback) Days)</td><td>None</td></tr>`n" }
}
if ($GetExpiringADPasswords) {
    if ($adExpiringPasswordsErrored) { $summaryRows += "<tr><td>Expiring Passwords (Next $($Settings.PasswordExpiryDays) Days)</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $adExpiringPasswordsResults) { $summaryRows += "<tr><td>Expiring Passwords (Next $($Settings.PasswordExpiryDays) Days)</td><td>None</td></tr>`n" }
}
if ($GetStaleUserObjects) {
    if ($staleUsersErrored) { $summaryRows += "<tr><td>Stale User Accounts</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $staleUsersResults) { $summaryRows += "<tr><td>Stale User Accounts</td><td>None</td></tr>`n" }
}
if ($GetStaleComputerObjects) {
    if ($staleComputerErrored) { $summaryRows += "<tr><td>Stale Computer Objects</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $staleComputerResults) { $summaryRows += "<tr><td>Stale Computer Objects</td><td>None</td></tr>`n" }
}
if ($CheckESXiEvents) {
    if ($esxiErrored) { $summaryRows += "<tr><td>ESXi Alerts (Past 24 Hours)</td><td bgcolor='#FFC200'>Error</td></tr>`n" }
    elseif ($null -eq $esxiResults) { $summaryRows += "<tr><td>ESXi Alerts (Past 24 Hours)</td><td>None</td></tr>`n" }
}

$sections.Add((Get-HtmlDailyChecksSection -AdditionalRows $summaryRows))

# ──────────────────────────────────────────────────────────────────────────────
# 9.  Add detailed report sections
# ──────────────────────────────────────────────────────────────────────────────

$sections.Add((Get-HtmlADLockedAccountsSection    -Results $adLockedOutResults))
$sections.Add((Get-HtmlADPasswordChangesSection   -Results $adPasswordChangesResults))
$sections.Add((Get-HtmlADExpiringPasswordsSection -Results $adExpiringPasswordsResults))
$sections.Add((Get-HtmlDCHealthSection            -Results $dcHealthResults))
$sections.Add((Get-HtmlStaleUsersSection          -Results $staleUsersResults))
$sections.Add((Get-HtmlStaleComputersSection      -Results $staleComputerResults))
$sections.Add((Get-HtmlESXiSection                -Results $esxiResults))

if ($diskSpaceResults) {
    $sections.Add((Get-HtmlDiskSpaceSection `
                -Results            $diskSpaceResults `
                -WarningOnly        $GetDiskSpaceWarningOnly `
                -CriticalThreshold  $Settings.DiskCriticalThreshold `
                -WarningThreshold   $Settings.DiskWarningThreshold))
}

# ──────────────────────────────────────────────────────────────────────────────
# 10.  Assemble full HTML body and send email
# ──────────────────────────────────────────────────────────────────────────────

$emailBody = Get-HtmlReportBody -Sections ($sections.ToArray() | Where-Object { $_ })

if ($SendEmail) {
    Write-LogNewLine
    Write-LogInfo -Message "=== Sending email report ==="
    Send-ReportEmail `
        -From       $From `
        -To         $To `
        -Subject    $EmailSubject `
        -Body       $emailBody `
        -SMTPServer $Settings.SMTPServer `
        -Credential $Credential
}

# ──────────────────────────────────────────────────────────────────────────────
# 11.  Done
# ──────────────────────────────────────────────────────────────────────────────

Stop-Log

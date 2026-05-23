#
# MorningChecks.WindowsUpdate.psm1
# Checks the local machine for pending Windows Updates.
#
# Depends on:  MorningChecks.Logging, PSWindowsUpdate module (auto-installed if missing)
#
# Author: Adenideni
# Version: 1.0.0
# Date: 2026-05-23

#
Set-StrictMode -Off

function Assert-PSWindowsUpdate {
    if (Get-Module -ListAvailable -Name 'PSWindowsUpdate') {
        return $true
    }

    Write-LogInfo -Message "PSWindowsUpdate module not found. Attempting install..."
    try {
        Install-PackageProvider -Name NuGet -Force -Confirm:$false -ErrorAction Stop | Out-Null
        Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false -ErrorAction Stop
        Write-LogSuccess -Message "PSWindowsUpdate installed successfully"
        return $true
    }
    catch {
        Write-LogError -Message "Failed to install PSWindowsUpdate: $($_.Exception.Message)"
        return $false
    }
}

function Get-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Checks the local machine for pending Windows Updates.

    .OUTPUTS
        One of: 'Pass' (up to date) | 'Updates found' | 'Error'
    #>
    [CmdletBinding()]
    param()

    Write-LogInfo -Message "Checking for pending Windows Updates"

    if (-not (Assert-PSWindowsUpdate)) {
        return 'Error'
    }

    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    try {
        $updates = Get-WindowsUpdate -ErrorAction Stop
        if ($updates) {
            Write-LogInfo -Message "$($updates.Count) pending update(s) found"
            return 'Updates found'
        }
        else {
            Write-LogSuccess -Message "Machine is up to date"
            return 'Pass'
        }
    }
    catch {
        Write-LogError -Message "Error checking Windows Updates: $($_.Exception.Message)"
        return 'Error'
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function 'Get-WindowsUpdateStatus'

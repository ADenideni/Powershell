#
# MorningChecks.VMware.psm1
# Retrieves ESXi/vCenter error and warning events for the morning report.
#
# Depends on:  MorningChecks.Logging, VMware.PowerCLI (auto-installed if missing)
#
# Author: ADenideni
# Email: a.denideni@hotmail.com
# Version: 1.0.0
# Date: 2026-05-23

#
Set-StrictMode -Off

function Assert-PowerCLI {
    if (Get-Module -ListAvailable -Name 'VMware.PowerCLI') {
        return $true
    }

    Write-LogInfo -Message "VMware PowerCLI not found. Attempting install from PSGallery..."
    try {
        Install-Module VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-LogSuccess -Message "VMware PowerCLI installed successfully"
        return $true
    }
    catch {
        Write-LogError -Message "Failed to install VMware PowerCLI: $($_.Exception.Message)"
        return $false
    }
}

function Get-ESXiEvents {
    <#
    .SYNOPSIS
        Connects to one or more vCenter servers and returns recent error/warning events.

    .PARAMETER VMwareHost
        One or more vCenter server hostnames or IP addresses.

    .PARAMETER Credential
        PSCredential used to authenticate against vCenter.

    .PARAMETER EventsCount
        Maximum number of events to retrieve per vCenter (default: 100).

    .PARAMETER Days
        Number of days back to query (default: 1 = last 24 hours).

    .OUTPUTS
        Array of event objects with CreatedTime, Source IP Address, UserName, Message
        or $null when no events are found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$VMwareHost,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [ValidateRange(1, 1000)]
        [int]$EventsCount = 100,

        [ValidateRange(1, 30)]
        [int]$Days = 1
    )

    if (-not (Assert-PowerCLI)) { return $null }

    Import-Module VMware.PowerCLI -ErrorAction SilentlyContinue | Out-Null
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

    $allEvents = @()
    $cutoff    = (Get-Date).AddDays(-$Days)

    foreach ($vcHost in $VMwareHost) {
        Write-LogInfo -Message "Connecting to vCenter: $vcHost"
        try {
            Connect-VIServer -Server $vcHost -Credential $Credential -ErrorAction Stop | Out-Null

            $events = Get-VIEvent -MaxSamples $EventsCount -Types Error, Warning -Start $cutoff |
                Select-Object CreatedTime,
                    @{ N = 'Source IP Address'; E = { $_.ObjectName } },
                    UserName,
                    @{ N = 'Message'; E = { $_.FullFormattedMessage } }

            $allEvents += $events

            Disconnect-VIServer -Server $vcHost -Confirm:$false -ErrorAction SilentlyContinue
        }
        catch {
            Write-LogError -Message "Error connecting to vCenter $vcHost`: $($_.Exception.Message)"
        }
    }

    if ($allEvents.Count -eq 0) {
        Write-LogSuccess -Message "No ESXi error/warning events in the past $Days day(s)"
        return $null
    }

    Write-LogInfo -Message "$($allEvents.Count) ESXi event(s) found"
    return $allEvents
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function 'Get-ESXiEvents'

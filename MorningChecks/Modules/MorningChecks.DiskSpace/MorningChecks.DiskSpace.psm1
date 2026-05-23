# Author: Adenideni
# Version: 1.0.0
# Date: 2026-05-23

#
# MorningChecks.DiskSpace.psm1
# Collects disk usage from all Windows servers in Active Directory.
#
# Depends on:  MorningChecks.Logging, ActiveDirectory RSAT module, WMI remoting
#

Set-StrictMode -Off

function Get-DiskSpaceReport {
    <#
    .SYNOPSIS
        Gathers disk usage from every Windows Server found in Active Directory.

    .DESCRIPTION
        Queries Win32_LogicalDisk (DriveType 3 = fixed local disk) on each server.
        The local machine is queried directly; remote machines are queried via WMI
        using the supplied credential.

    .PARAMETER ComputerName
        Optional list of server names to query. When omitted all AD computer objects
        whose OperatingSystem contains "server" are targeted.

    .PARAMETER Credential
        PSCredential used for remote WMI connections.

    .OUTPUTS
        Array of PSCustomObject per drive:
            'Server Name', 'Drive Label', 'Volume Name',
            'Volume Size', 'Used Space', 'Free Space',
            'Used Percentage', 'Free Percentage'
        Returns $null when no data could be collected.
    #>
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    # Ensure AD module is available to enumerate servers
    if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-LogError -Message "Active Directory module unavailable — cannot enumerate servers."
            return $null
        }
    }

    if (-not $ComputerName) {
        Write-LogInfo -Message "Enumerating Windows Server objects from Active Directory"
        $ComputerName = Get-ADComputer -Filter * -Properties OperatingSystem |
            Where-Object { $_.OperatingSystem -like '*server*' } |
            Select-Object -ExpandProperty DNSHostName
    }

    $results = @()

    foreach ($server in $ComputerName) {
        Write-LogInfo -Message "Collecting disk info from: $server"

        try {
            if ($server -eq $env:COMPUTERNAME) {
                $diskInfo = Get-WmiObject Win32_LogicalDisk |
                    Where-Object { $_.DriveType -eq 3 -and $_.Size -gt 1 }
            }
            else {
                # Verify connectivity before attempting WMI
                Test-Connection -ComputerName $server -Count 1 -ErrorAction Stop | Out-Null
                $diskInfo = Get-WmiObject Win32_LogicalDisk -ComputerName $server -Credential $Credential |
                    Where-Object { $_.DriveType -eq 3 -and $_.Size -gt 1 }
            }

            foreach ($disk in $diskInfo) {
                $size        = [math]::Round($disk.Size      / 1GB, 2)
                $free        = [math]::Round($disk.FreeSpace / 1GB, 2)
                $used        = [math]::Round($size - $free, 2)
                $freePercent = [math]::Round(($free / $size) * 100, 2)
                $usedPercent = [math]::Round(100 - $freePercent, 2)

                $results += [PSCustomObject]@{
                    'Server Name'     = $server
                    'Drive Label'     = $disk.DeviceID
                    'Volume Name'     = $disk.VolumeName.ToUpper()
                    'Volume Size'     = $size
                    'Used Space'      = $used
                    'Free Space'      = $free
                    'Used Percentage' = $usedPercent
                    'Free Percentage' = $freePercent
                }
            }
        }
        catch {
            Write-LogError -Message "Failed to collect disk info from $server`: $($_.Exception.Message)"
        }
    }

    if ($results.Count -eq 0) { return $null }
    return $results
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function 'Get-DiskSpaceReport'

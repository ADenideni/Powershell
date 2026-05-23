#
# MorningChecks.Network.psm1
# Ping and website-availability checking with HTML row generation.
#
# Depends on: MorningChecks.Logging (Write-LogInfo / Write-LogError must be loaded)
#
# Author: ADenideni
# Email: a.denideni@hotmail.com
# Version: 1.0.0
# Date: 2026-05-23

#
Set-StrictMode -Off

# ──────────────────────────────────────────────────────────────────────────────
# Ping helpers
# ──────────────────────────────────────────────────────────────────────────────

function Test-DevicePing {
    <#
    .SYNOPSIS
        Sends four ICMP requests to a device and returns connectivity metrics.
    .PARAMETER ComputerName
        Hostname or IP address to ping.
    .OUTPUTS
        PSCustomObject with Source, Destination, AverageResponseTime, IPV4, Reachable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [ValidateRange(1, 10)]
        [int]$Count = 4
    )

    $responses = @()
    $totalResponseMs = 0

    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $ping = Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction Stop
            $responses += $ping
            $totalResponseMs += $ping.ResponseTime
        }
        catch {
            # Individual ping failure — continue accumulating results
        }
    }

    $avgMs = if ($responses.Count -gt 0) { [math]::Round($totalResponseMs / $responses.Count, 0) } else { $null }
    $ipv4 = if ($responses.Count -gt 0) { ($responses | Select-Object -First 1).IPV4Address.IPAddressToString } else { $null }

    return [PSCustomObject]@{
        Source              = $env:COMPUTERNAME
        Destination         = $ComputerName
        AverageResponseTime = $avgMs
        IPV4                = $ipv4
        Reachable           = ($responses.Count -gt 0)
    }
}

function Get-DeviceLocation {
    <#
    .SYNOPSIS
        Resolves a subnet-based human-readable location string from an IP address.
    .PARAMETER IPAddress
        The IPv4 address to look up.
    .PARAMETER SubnetMap
        Array of @{ Pattern; Location } hashtables from devices.psd1.
        Evaluated top-to-bottom; first match wins.
        When omitted the function returns 'Unknown'.
    #>
    param(
        [string]$IPAddress,
        [array]$SubnetMap = @()
    )

    foreach ($entry in $SubnetMap) {
        if ($IPAddress -like $entry.Pattern) { return $entry.Location }
    }
    return 'Unknown'
}

function Get-HTMLPingRow {
    <#
    .SYNOPSIS
        Pings a device and returns an HTML <tr> row for the report.
    .PARAMETER Device
        Hostname or IP address to ping.
    .PARAMETER DeviceName
        Display name shown in the report.
    .PARAMETER DeviceURL
        Optional hyperlink applied to the device name cell.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Device,

        [Parameter(Mandatory = $true)]
        [string]$DeviceName,

        [string]$DeviceLocation,
        [string]$DeviceURL = $null,

        # Subnet map from devices.psd1 used to resolve the location automatically
        [array]$SubnetMap = @()
    )

    $ping = Test-DevicePing -ComputerName $Device

    # PS5.1 / Test-Connection does not always populate IPV4Address (e.g. when the
    # target is already an IP rather than a hostname).  Fall back to the device
    # address itself when it looks like an IPv4 literal so the IP column and the
    # location lookup still work.
    $resolvedIP = if ($ping.IPV4) {
        $ping.IPV4
    }
    elseif ($Device -match '^\d{1,3}(\.\d{1,3}){3}$') {
        $Device
    }
    else {
        $null
    }

    if (-not $DeviceLocation -and $resolvedIP) {
        $DeviceLocation = Get-DeviceLocation -IPAddress $resolvedIP -SubnetMap $SubnetMap
    }

    $avgMs = $ping.AverageResponseTime

    $statusCell = if ($ping.Reachable -and $null -ne $avgMs -and $avgMs -lt 100) {
        '<td>Pass</td>'
    }
    elseif ($ping.Reachable -and $null -ne $avgMs -and $avgMs -lt 150) {
        '<td bgcolor="#FFC200">Warning</td>'
    }
    else {
        '<td bgcolor="#FF0000">Fail</td>'
    }

    $nameCell = if ($DeviceURL) {
        "<td><a href=`"$DeviceURL`">$DeviceName</a></td>"
    }
    else {
        "<td>$DeviceName</td>"
    }

    return @"
        <tr>
            $nameCell
            <td>$DeviceLocation</td>
            <td>$resolvedIP</td>
            <td>$avgMs</td>
            $statusCell
        </tr>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Website availability helpers
# ──────────────────────────────────────────────────────────────────────────────

function Test-WebsiteStatus {
    <#
    .SYNOPSIS
        Issues an HTTP GET to a URL and reports success/failure and response time.
    .OUTPUTS
        PSCustomObject with Url, SiteName, Succeeded, StatusCode, TimeTakenMs, Message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [string]$SiteName
    )

    $succeeded = $false
    $statusCode = $null
    $message = $null

    $timeTaken = Measure-Command {
        try {
            $response = Invoke-WebRequest -Method Get -Uri $Url -UseBasicParsing -ErrorAction Stop
            $succeeded = $true
            $statusCode = $response.StatusCode.ToString()
        }
        catch [System.Net.WebException] {
            $message = $_.Exception.Message
            $exceptionResponse = $_.Exception.GetBaseException().Response
            if ($null -ne $exceptionResponse) {
                $statusCode = [int]$exceptionResponse.StatusCode
                # Treat auth/forbidden/not-found as "site is up"
                if ($statusCode -in 401, 403, 404) { $succeeded = $true }
            }
        }
        catch {
            $message = $_.Exception.Message
        }
    }

    return [PSCustomObject]@{
        Url         = $Url
        SiteName    = $SiteName
        Succeeded   = $succeeded
        StatusCode  = $statusCode
        TimeTakenMs = [math]::Round($timeTaken.TotalMilliseconds, 0)
        Message     = $message
    }
}

function Get-HTMLSiteRow {
    <#
    .SYNOPSIS
        Checks a website and returns an HTML <tr> row for the report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteURL,

        [Parameter(Mandatory = $true)]
        [string]$SiteName
    )

    $result = Test-WebsiteStatus -Url $SiteURL -SiteName $SiteName
    $statusCell = if ($result.Succeeded) { '<td>Online</td>' } else { '<td bgcolor="#FF0000">Offline</td>' }

    return @"
        <tr>
            <td><a href="$SiteURL">$SiteName</a></td>
            $statusCell
        </tr>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Test-DevicePing'
    'Get-HTMLPingRow'
    'Test-WebsiteStatus'
    'Get-HTMLSiteRow'
)

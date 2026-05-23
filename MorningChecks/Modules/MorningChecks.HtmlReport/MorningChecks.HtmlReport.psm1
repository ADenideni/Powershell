#
# MorningChecks.HtmlReport.psm1
# Builds every HTML section that appears in the morning-checks report email.
#
# All functions accept the raw data collected by the other modules and return
# an HTML string fragment that is assembled in Start-MorningChecks.ps1.
#

Set-StrictMode -Off

# ──────────────────────────────────────────────────────────────────────────────
# Shared CSS / page skeleton
# ──────────────────────────────────────────────────────────────────────────────

$script:HtmlStyle = @'
<style>
    body    { font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif; }
    p       { font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif; margin-top: 5px; margin-bottom: 5px; }
    h1      { text-align: left; text-transform: uppercase; color: #4CAF50; font-size: 25px; }
    table   { font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif;
              border-collapse: collapse; width: 85%; border: 1px solid #ddd; }
    th, td  { text-align: left; padding: 8px; border: 1px solid #ddd; }
    tr:nth-child(odd) { background-color: #f2f2f2; }
    th      { background-color: #4CAF50; color: white; border: 1px solid #ddd; }
</style>
'@

function Get-HtmlReportBody {
    <#
    .SYNOPSIS
        Wraps all section fragments in a complete HTML document.
    .PARAMETER Sections
        Array of HTML fragment strings produced by the other functions in this module.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Sections
    )

    $body = ($Sections | Where-Object { $_ }) -join "`n"

    return @"
<!DOCTYPE html>
<html>
<head>
    $script:HtmlStyle
</head>
<body>
<p>
    All.<br><br>
    This report was automatically generated on $(Get-Date -Format 'yyyy-MM-dd') at $(Get-Date -Format 'HH:mm') $([TimeZoneInfo]::Local.Id).<br><br>

    $body

    Many thanks,<br>
</p>
</body>
</html>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Ping sections
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlPingSection {
    <#
    .SYNOPSIS  Wraps pre-built ping <tr> rows in a headed table. #>
    param(
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [string]$RowsHtml
    )

    return @"
<h1>$Title</h1>
<table>
    <tbody>
        <tr>
            <th>Computer Name</th>
            <th>Device Location</th>
            <th>IP Address</th>
            <th>Average Response Time (MS)</th>
            <th>Results</th>
        </tr>
        $RowsHtml
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Site-check section
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlSiteSection {
    <#
    .SYNOPSIS  Wraps pre-built site-check <tr> rows in a headed table. #>
    param(
        [Parameter(Mandatory = $true)] [string]$Title,
        [Parameter(Mandatory = $true)] [string]$RowsHtml
    )

    return @"
<h1>$Title</h1>
<table>
    <tbody>
        <tr>
            <th>Website</th>
            <th>Results</th>
        </tr>
        $RowsHtml
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Daily-checks summary table
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlDailyChecksSection {
    <#
    .SYNOPSIS
        Builds the top-level "Daily Checks" summary table.
    .PARAMETER AdditionalRows
        HTML <tr> blocks for check results built conditionally in Start-MorningChecks.ps1.
    #>
    param(
        [string]$AdditionalRows = ''
    )

    return @"
<h1>Daily Checks</h1>
<table>
    <tbody>
        <tr>
            <th>Check</th>
            <th>Results</th>
        </tr>
        $AdditionalRows
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Active Directory — Password changes
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlADPasswordChangesSection {
    <#
    .SYNOPSIS  Returns an HTML table of recent password changes, or '' if none. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $rows = $Results | ForEach-Object {
        @"
        <tr>
            <td>$($_.Name)</td>
            <td>$($_.SamAccountName)</td>
            <td>$($_.Email)</td>
            <td>$($_.PasswordLastSet)</td>
        </tr>
"@
    }

    return @"
<h1>Active Directory Password Changes (Past 7 Days)</h1>
<table>
    <tbody>
        <tr>
            <th>Name</th>
            <th>SamAccountName</th>
            <th>Email</th>
            <th>Password Last Set</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Active Directory — Expiring passwords
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlADExpiringPasswordsSection {
    <#
    .SYNOPSIS  Returns an HTML table of soon-to-expire passwords, colour-coded by urgency. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $now = Get-Date
    $rows = $Results | ForEach-Object {
        $expiry = $_.'Expiry Date'
        $dateCell = if ($expiry -lt $now.AddDays(3)) {
            "<td bgcolor=`"#FF0000`">$expiry</td>"
        }
        elseif ($expiry -lt $now.AddDays(5)) {
            "<td bgcolor=`"#FFC200`">$expiry</td>"
        }
        else {
            "<td>$expiry</td>"
        }
        @"
        <tr>
            <td>$($_.'Display Name')</td>
            $dateCell
        </tr>
"@
    }

    return @"
<h1>Active Directory Expiring Passwords (Next 10 Days)</h1>
<table>
    <tbody>
        <tr>
            <th>Display Name</th>
            <th>Expiry Date</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Active Directory — Locked-out accounts
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlADLockedAccountsSection {
    <#
    .SYNOPSIS  Returns an HTML table of locked-out accounts, or '' if none. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $rows = $Results | ForEach-Object {
        @"
        <tr>
            <td>$($_.Name)</td>
            <td>$($_.SamAccountName)</td>
            <td>$($_.Email)</td>
        </tr>
"@
    }

    return @"
<h1>Active Directory Locked Out Accounts</h1>
<table>
    <tbody>
        <tr>
            <th>Name</th>
            <th>SamAccountName</th>
            <th>Email</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Domain Controller health
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlDCHealthSection {
    <#
    .SYNOPSIS
        Returns a transposed DC-health table (rows = checks, columns = DCs).
        Cells that fail the pass condition are highlighted amber.
    #>
    param([array]$Results)

    if (-not $Results) { return '' }

    # Helper: build a <tr> for a given check, with one <td> per DC
    function New-HealthRow {
        param(
            [string]$Label,
            [scriptblock]$ValueSelector,
            [scriptblock]$PassCondition
        )
        $cells = $Results | ForEach-Object {
            $val = & $ValueSelector $_
            $css = if (& $PassCondition $val) { '' } else { ' bgcolor="#FCE175"' }
            "<td$css>$val</td>"
        }
        return "<tr><th>$Label</th>$($cells -join '')</tr>"
    }

    $shortName = { param($r) $r.Server -replace "\.$([regex]::Escape($env:USERDNSDOMAIN))", '' }

    $rows = @(
        (New-HealthRow 'Server Name'       $shortName { $true })
        (New-HealthRow 'Ping Status' { param($r) $r.'Ping Status' } { param($v) $v -eq 'Successful' })
        (New-HealthRow 'Net Logon Service' { param($r) $r.'Net Logon Service' } { param($v) $v -eq 'Running' })
        (New-HealthRow 'NTDS Service' { param($r) $r.'NTDS Service' } { param($v) $v -eq 'Running' })
        (New-HealthRow 'DNS Service' { param($r) $r.'DNS Service' } { param($v) $v -eq 'Running' })
        (New-HealthRow 'Net Logon' { param($r) $r.NetLogon } { param($v) $v -eq 'passed' })
        (New-HealthRow 'Replication' { param($r) $r.Replication } { param($v) $v -eq 'passed' })
        (New-HealthRow 'Services' { param($r) $r.Services } { param($v) $v -eq 'passed' })
        (New-HealthRow 'Advertising' { param($r) $r.Advertising } { param($v) $v -eq 'passed' })
    )

    return @"
<h1>Domain Controller Health Status</h1>
<table>
    <tbody>
        $($rows -join "`n        ")
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Stale users
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlStaleUsersSection {
    <#
    .SYNOPSIS  Returns a colour-coded table of stale user accounts, or '' if none. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $now = Get-Date
    $rows = $Results | ForEach-Object {
        $lastLogon = $_.'Last Logon Date'
        $dateCell = if ($lastLogon -lt $now.AddDays(-365)) {
            "<td bgcolor=`"#FF0000`">$lastLogon</td>"
        }
        elseif ($lastLogon -lt $now.AddDays(-182)) {
            "<td bgcolor=`"#FCE175`">$lastLogon</td>"
        }
        else {
            "<td>$lastLogon</td>"
        }
        @"
        <tr>
            <td>$($_.Name)</td>
            <td>$($_.samAccountName)</td>
            $dateCell
            <td>$($_.Enabled)</td>
        </tr>
"@
    }

    return @"
<h1>Stale User Accounts</h1>
<table>
    <tbody>
        <tr>
            <th>Name</th>
            <th>samAccountName</th>
            <th>Last Logon Date</th>
            <th>Enabled</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Stale computers
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlStaleComputersSection {
    <#
    .SYNOPSIS  Returns a table of stale computer objects, or '' if none. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $rows = $Results | ForEach-Object {
        @"
        <tr>
            <td>$($_.ComputerName)</td>
            <td>$($_.LastLogonDate)</td>
            <td>$($_.Created)</td>
            <td>$($_.OperatingSystem)</td>
        </tr>
"@
    }

    return @"
<h1>Stale Computer Objects (Past 365 Days)</h1>
<table>
    <tbody>
        <tr>
            <th>ComputerName</th>
            <th>Last Logon Date</th>
            <th>Created</th>
            <th>Operating System</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# ESXi events
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlESXiSection {
    <#
    .SYNOPSIS  Returns a table of ESXi error/warning events, or '' if none. #>
    param([array]$Results)

    if (-not $Results) { return '' }

    $rows = $Results | ForEach-Object {
        @"
        <tr>
            <td>$($_.CreatedTime)</td>
            <td>$($_.'Source IP Address')</td>
            <td>$($_.UserName)</td>
            <td>$($_.Message)</td>
        </tr>
"@
    }

    return @"
<h1>ESXi Error Logs (Past 24 Hours)</h1>
<table>
    <tbody>
        <tr>
            <th>Created Time</th>
            <th>Source IP Address</th>
            <th>User Name</th>
            <th>Message</th>
        </tr>
        $($rows -join '')
    </tbody>
</table>
<br><br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Disk space
# ──────────────────────────────────────────────────────────────────────────────

function Get-HtmlDiskSpaceSection {
    <#
    .SYNOPSIS
        Builds per-server disk-space tables, optionally showing only drives below
        the warning threshold.

    .PARAMETER Results
        Output from Get-DiskSpaceReport.

    .PARAMETER WarningOnly
        When $true only servers with at least one drive below $WarningThreshold are shown.

    .PARAMETER CriticalThreshold
        Free-space percentage below which the cell is coloured red (default: 10).

    .PARAMETER WarningThreshold
        Free-space percentage below which the cell is coloured amber (default: 15).
    #>
    param(
        [array]$Results,
        [bool]$WarningOnly = $true,
        [int]$CriticalThreshold = 10,
        [int]$WarningThreshold = 15
    )

    if (-not $Results) { return '' }

    $servers = $Results | Select-Object -ExpandProperty 'Server Name' -Unique
    $serverTables = foreach ($server in $servers) {

        $serverDisks = $Results | Where-Object { $_.'Server Name' -eq $server }

        if ($WarningOnly) {
            $warningDisks = $serverDisks | Where-Object { $_.'Free Percentage' -lt $WarningThreshold }
            if (-not $warningDisks) { continue }
        }

        $diskRows = $serverDisks | ForEach-Object {
            $freePercent = $_.'Free Percentage'

            # Skip rows that have no warning when WarningOnly is set
            if ($WarningOnly -and $freePercent -ge $WarningThreshold) { return }

            $freeCell = if ($freePercent -lt $CriticalThreshold) {
                "<td bgcolor=`"#FF0000`">$freePercent %</td>"
            }
            elseif ($freePercent -lt $WarningThreshold) {
                "<td bgcolor=`"#FFC200`">$freePercent %</td>"
            }
            else {
                "<td>$freePercent %</td>"
            }

            @"
            <tr>
                <td>$($_.'Drive Label')</td>
                <td>$($_.'Volume Name')</td>
                <td>$($_.'Volume Size') GB</td>
                <td>$($_.'Used Space') GB</td>
                <td>$($_.'Free Space') GB</td>
                <td>$($_.'Used Percentage') %</td>
                $freeCell
            </tr>
"@
        }

        if (-not $diskRows) { continue }

        @"
<table style="width:90%;">
    <tbody>
        <tr><th style="text-align:center;">$server</th></tr>
    </tbody>
</table>
<table style="width:90%;">
    <tbody>
        <tr>
            <th>Drive Label</th>
            <th>Volume Name</th>
            <th>Volume Size (GB)</th>
            <th>Used Space (GB)</th>
            <th>Free Space (GB)</th>
            <th>Used Space (%)</th>
            <th>Free Space (%)</th>
        </tr>
        $($diskRows -join '')
    </tbody>
</table>
<br><br>
"@
    }

    if (-not $serverTables) { return '' }

    return @"
<h1>Disk Space Report</h1>
$($serverTables -join "`n")
<br>
"@
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Get-HtmlReportBody'
    'Get-HtmlPingSection'
    'Get-HtmlSiteSection'
    'Get-HtmlDailyChecksSection'
    'Get-HtmlADPasswordChangesSection'
    'Get-HtmlADExpiringPasswordsSection'
    'Get-HtmlADLockedAccountsSection'
    'Get-HtmlDCHealthSection'
    'Get-HtmlStaleUsersSection'
    'Get-HtmlStaleComputersSection'
    'Get-HtmlESXiSection'
    'Get-HtmlDiskSpaceSection'
)

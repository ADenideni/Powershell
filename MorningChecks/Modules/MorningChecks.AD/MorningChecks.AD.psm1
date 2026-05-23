# Author: ADenideni
# Email: a.denideni@hotmail.com
# Version: 1.0.0
# Date: 2026-05-23

#
# MorningChecks.AD.psm1
# Active Directory health and user status checks.
#
# Depends on:  MorningChecks.Logging, ActiveDirectory RSAT module
#

Set-StrictMode -Off

# ──────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ──────────────────────────────────────────────────────────────────────────────

function Assert-ADModule {
    if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-LogError -Message 'Active Directory module is unavailable. Install RSAT and retry.'
            return $false
        }
    }
    return $true
}

# ──────────────────────────────────────────────────────────────────────────────
# Password changes
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADPasswordChanges {
    <#
    .SYNOPSIS
        Returns users who changed their password within the last N days.
    .PARAMETER NumberOfDays
        Look-back window in days (default: 7).
    .OUTPUTS
        Array of PSCustomObject { Name, SamAccountName, Email, PasswordLastSet }
        or $null if no results.
    #>
    [CmdletBinding()]
    param(
        [int]$NumberOfDays = 7
    )

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Querying AD for password changes in the past $NumberOfDays day(s)"

    $adResults = Get-ADUser -Filter * -Properties Enabled, SamAccountName, PasswordLastSet, Mail |
    Where-Object {
        $_.PasswordLastSet -gt (Get-Date).AddDays(-$NumberOfDays) -and
        $_.Enabled -eq $true -and
        $_.Mail -like '*@example.com'
    } |
    Sort-Object PasswordLastSet -Descending

    if (-not $adResults) {
        Write-LogSuccess -Message "No password changes in the past $NumberOfDays day(s)"
        return $null
    }

    Write-LogInfo -Message "$($adResults.Count) password change(s) found"

    return $adResults | ForEach-Object {
        [PSCustomObject]@{
            Name            = $_.Name
            SamAccountName  = $_.SamAccountName
            Email           = $_.Mail
            PasswordLastSet = $_.PasswordLastSet
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Expiring passwords
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADExpiringPasswords {
    <#
    .SYNOPSIS
        Returns enabled users whose password will expire within the next N days.
    .PARAMETER NumberOfDays
        Forward look-ahead window in days (default: 10).
    .OUTPUTS
        Array of PSCustomObject { 'Display Name', 'Expiry Date' } or $null.
    #>
    [CmdletBinding()]
    param(
        [int]$NumberOfDays = 10
    )

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Querying AD for passwords expiring in the next $NumberOfDays day(s)"

    $now = Get-Date
    $cutoff = $now.AddDays($NumberOfDays)

    # 9223372036854775807 = Int64.MaxValue -- means "password never expires"
    # 0 and negative values are also invalid FileTime values.
    # Only attempt conversion when the value is a positive finite FileTime.
    $maxFileTime = [long]::MaxValue

    $results = Get-ADUser -Filter * -Properties DisplayName, 'msDS-UserPasswordExpiryTimeComputed', Enabled |
    Where-Object {
        $_.Enabled -eq $true -and
        $_.'msDS-UserPasswordExpiryTimeComputed' -gt 0 -and
        $_.'msDS-UserPasswordExpiryTimeComputed' -lt $maxFileTime
    } |
    ForEach-Object {
        try { $expiry = [DateTime]::FromFileTime($_.'msDS-UserPasswordExpiryTimeComputed') }
        catch { return }   # skip any remaining edge-case invalid values
        [PSCustomObject]@{
            'Display Name' = $_.DisplayName
            'Expiry Date'  = $expiry
        }
    } |
    Where-Object { $_.'Expiry Date' -gt $now -and $_.'Expiry Date' -lt $cutoff } |
    Sort-Object 'Expiry Date'

    if (-not $results) {
        Write-LogSuccess -Message "No passwords expiring in the next $NumberOfDays day(s)"
        return $null
    }

    Write-LogInfo -Message "$($results.Count) password(s) expiring soon"
    return $results
}

# ──────────────────────────────────────────────────────────────────────────────
# Locked-out accounts
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADLockedOutAccounts {
    <#
    .SYNOPSIS
        Returns all currently locked-out Active Directory accounts.
    .OUTPUTS
        Array of PSCustomObject { Name, SamAccountName, Email } or $null.
    #>
    [CmdletBinding()]
    param()

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Querying AD for locked-out accounts"

    $adResults = Search-ADAccount -LockedOut

    if (-not $adResults) {
        Write-LogSuccess -Message "No accounts are locked out"
        return $null
    }

    Write-LogInfo -Message "$($adResults.Count) locked-out account(s) found"

    # Search-ADAccount does not return Mail by default; fetch it separately
    return $adResults | ForEach-Object {
        $user = Get-ADUser $_.SamAccountName -Properties Mail -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name           = $_.Name
            SamAccountName = $_.SamAccountName
            Email          = $user.Mail
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Domain Controller health
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADDCHealthStatus {
    <#
    .SYNOPSIS
        Runs ping, WMI service checks and DCDiag against every Domain Controller.
        Uses WMI (DCOM/RPC) and local dcdiag /s: so WinRM is not required.
    .PARAMETER Credential
        PSCredential used for WMI connections to remote DCs.
    .OUTPUTS
        Array of PSCustomObject per DC with Ping, service status and DCDiag results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Enumerating Domain Controllers"

    $forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $dcServers = $forest.Domains | ForEach-Object { $_.DomainControllers } | ForEach-Object { $_.Name }

    $results = foreach ($server in $dcServers) {
        Write-LogInfo -Message "Checking DC: $server"

        $pingOk = $false
        $netLogonSvc = 'N/A'
        $ntdsSvc = 'N/A'
        $dnsSvc = 'N/A'
        $dcDiag = $null

        # ── Ping ──────────────────────────────────────────────────────────────
        try {
            Test-Connection -ComputerName $server -Count 1 -ErrorAction Stop | Out-Null
            $pingOk = $true
        }
        catch {
            Write-LogError -Message "Ping failed for $server`: $($_.Exception.Message)"
        }

        if ($pingOk) {
            # ── Service status via WMI (DCOM -- no WinRM required) ────────────
            try {
                $wmiSvcs = Get-WmiObject -Class Win32_Service `
                    -ComputerName $server `
                    -Credential   $Credential `
                    -Filter       "Name='Netlogon' OR Name='NTDS' OR Name='DNS'" `
                    -ErrorAction  Stop

                foreach ($svc in $wmiSvcs) {
                    switch ($svc.Name) {
                        'Netlogon' { $netLogonSvc = $svc.State }
                        'NTDS' { $ntdsSvc = $svc.State }
                        'DNS' { $dnsSvc = $svc.State }
                    }
                }
            }
            catch {
                Write-LogError -Message "WMI service query failed for $server`: $($_.Exception.Message)"
            }

            # ── DCDiag run locally targeting the remote DC ────────────────────
            # dcdiag /s: queries the DC over RPC -- no WinRM needed.
            try {
                $dcDiagOutput = & dcdiag /s:$server 2>&1
                $dcDiag = $dcDiagOutput |
                Select-String -Pattern '\.\s+\S+\s+(passed|failed)\s+test\s+(\S+)' |
                ForEach-Object {
                    [PSCustomObject]@{
                        TestName   = $_.Matches[0].Groups[2].Value
                        TestResult = $_.Matches[0].Groups[1].Value
                    }
                }
            }
            catch {
                Write-LogError -Message "DCDiag failed for $server`: $($_.Exception.Message)"
            }
        }

        [PSCustomObject]@{
            Server              = $server
            'Ping Status'       = if ($pingOk) { 'Successful' } else { 'Failed' }
            'Net Logon Service' = $netLogonSvc
            'NTDS Service'      = $ntdsSvc
            'DNS Service'       = $dnsSvc
            NetLogon            = ($dcDiag | Where-Object { $_.TestName -eq 'NetLogons' }    | Select-Object -ExpandProperty TestResult -ErrorAction SilentlyContinue)
            Replication         = ($dcDiag | Where-Object { $_.TestName -eq 'Replications' } | Select-Object -ExpandProperty TestResult -ErrorAction SilentlyContinue)
            Services            = ($dcDiag | Where-Object { $_.TestName -eq 'Services' }     | Select-Object -ExpandProperty TestResult -ErrorAction SilentlyContinue)
            Advertising         = ($dcDiag | Where-Object { $_.TestName -eq 'Advertising' }  | Select-Object -ExpandProperty TestResult -ErrorAction SilentlyContinue)
        }
    }

    return $results
}

# ──────────────────────────────────────────────────────────────────────────────
# Stale user accounts
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADStaleUsers {
    <#
    .SYNOPSIS
        Returns enabled users who have not logged on in the last N days.
    .PARAMETER NumberOfDays
        Inactivity threshold in days (default: 60).
    .OUTPUTS
        Array of PSCustomObject { Name, samAccountName, 'Last Logon Date', Enabled } or $null.
    #>
    [CmdletBinding()]
    param(
        [int]$NumberOfDays = 60
    )

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Querying AD for users with no logon in the past $NumberOfDays day(s)"

    $cutoff = (Get-Date).AddDays(-$NumberOfDays)

    $results = Get-ADUser -Filter { Enabled -eq $true } -Properties LastLogonDate, SamAccountName |
    Where-Object { $_.LastLogonDate -ne $null -and $_.LastLogonDate -lt $cutoff } |
    Sort-Object LastLogonDate

    if (-not $results) {
        Write-LogSuccess -Message "No stale user accounts"
        return $null
    }

    Write-LogInfo -Message "$($results.Count) stale user account(s) found"

    return $results | ForEach-Object {
        [PSCustomObject]@{
            Name              = $_.Name
            samAccountName    = $_.SamAccountName
            'Last Logon Date' = $_.LastLogonDate
            Enabled           = $_.Enabled
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Stale computer objects
# ──────────────────────────────────────────────────────────────────────────────

function Get-ADStaleComputers {
    <#
    .SYNOPSIS
        Returns computer objects that have not authenticated in the last N days.
    .PARAMETER DaysOld
        Inactivity threshold in days (default: 365).
    .OUTPUTS
        Array of PSCustomObject { ComputerName, LastLogonDate, Created, OperatingSystem } or $null.
    #>
    [CmdletBinding()]
    param(
        [int]$DaysOld = 365
    )

    if (-not (Assert-ADModule)) { return $null }

    Write-LogInfo -Message "Querying AD for computer objects with no logon in the past $DaysOld day(s)"

    $cutoff = (Get-Date).AddDays(-$DaysOld)

    $results = Get-ADComputer -Filter * -Properties Name, OperatingSystem, LastLogonDate, Created |
    Where-Object { $_.LastLogonDate -ne $null -and $_.LastLogonDate -lt $cutoff } |
    Sort-Object LastLogonDate -Descending

    if (-not $results) {
        Write-LogSuccess -Message "No stale computer objects"
        return $null
    }

    Write-LogInfo -Message "$($results.Count) stale computer object(s) found"

    return $results | ForEach-Object {
        [PSCustomObject]@{
            ComputerName    = $_.Name
            LastLogonDate   = $_.LastLogonDate
            Created         = $_.Created
            OperatingSystem = $_.OperatingSystem
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Get-ADPasswordChanges'
    'Get-ADExpiringPasswords'
    'Get-ADLockedOutAccounts'
    'Get-ADDCHealthStatus'
    'Get-ADStaleUsers'
    'Get-ADStaleComputers'
)

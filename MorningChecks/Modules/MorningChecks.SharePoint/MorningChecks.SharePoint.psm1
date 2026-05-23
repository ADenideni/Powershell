#
# MorningChecks.SharePoint.psm1
# Creates the daily checks document in SharePoint Online by copying a template.
#
# Depends on:  MorningChecks.Logging
#              Microsoft.Online.SharePoint.PowerShell  (auto-installed if missing)
#              PnP.PowerShell  (for folder creation)
#
# Author: Adenideni
# Version: 1.0.0
# Date: 2026-05-23

#
Set-StrictMode -Off

function Assert-SharePointModule {
    if (-not (Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        Write-LogInfo -Message "Installing Microsoft.Online.SharePoint.PowerShell..."
        try {
            Install-PackageProvider -Name NuGet -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Force -Confirm:$false -ErrorAction Stop
            Write-LogSuccess -Message "SharePoint module installed"
        }
        catch {
            Write-LogError -Message "Failed to install SharePoint module: $($_.Exception.Message)"
            return $false
        }
    }

    Import-Module Microsoft.Online.SharePoint.PowerShell -WarningAction SilentlyContinue -ErrorAction Stop
    return $true
}

function New-SharePointDailyChecksFile {
    <#
    .SYNOPSIS
        Copies the daily-checks template to the correct dated folder in SharePoint.

    .DESCRIPTION
        Skips execution on Saturdays and Sundays.
        Creates the monthly sub-folder if it does not already exist.

    .PARAMETER SiteURL
        Root SharePoint Online site URL (e.g. https://example.sharepoint.com/sites/operations).

    .PARAMETER SourceFileURL
        Server-relative URL of the template document.

    .PARAMETER TargetFileURL
        Server-relative URL of the destination document (date-stamped).

    .PARAMETER Credential
        PSCredential (username must be the full UPN, e.g. svc_reporting@example.com).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SiteURL,

        [Parameter(Mandatory = $true)]
        [string]$SourceFileURL,

        [Parameter(Mandatory = $true)]
        [string]$TargetFileURL,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    $dayOfWeek = (Get-Date).DayOfWeek
    if ($dayOfWeek -eq 'Saturday' -or $dayOfWeek -eq 'Sunday') {
        Write-LogInfo -Message "Skipping SharePoint file creation — weekend"
        return
    }

    if (-not (Assert-SharePointModule)) { return }

    Write-LogInfo -Message "Creating SharePoint daily checks file"

    try {
        $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials(
            $Credential.UserName,
            $Credential.Password
        )

        # Ensure the monthly folder exists (PnP)
        try {
            $year  = (Get-Date).Year
            $month = Get-Date -Format 'MM'
            $monthName = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month)
            $folderPath = "Technology/Onsite%20Documentation/Daily%20Checks/Site%20Visit%20Report/$year"

            Connect-PnPOnline -Url $SiteURL -Credentials $Credential -ErrorAction SilentlyContinue
            Add-PnPFolder -Name "$month - $monthName" -Folder $folderPath -ErrorAction Stop
        }
        catch {
            # Folder already exists — not an error
            Write-LogInfo -Message "Monthly folder already exists or PnP unavailable: $($_.Exception.Message)"
        }

        # Copy the template
        $sourceFile = $ctx.Web.GetFileByServerRelativeUrl($SourceFileURL)
        $ctx.Load($sourceFile)
        $ctx.ExecuteQuery()

        $sourceFile.CopyTo($TargetFileURL, $true)
        $ctx.ExecuteQuery()

        Write-LogSuccess -Message "Daily checks file created: $($TargetFileURL -replace '%20',' ')"
    }
    catch {
        Write-LogError -Message "Failed to create SharePoint daily checks file: $($_.Exception.Message)"
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function 'New-SharePointDailyChecksFile'

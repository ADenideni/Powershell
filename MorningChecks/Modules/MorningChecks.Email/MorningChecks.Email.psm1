#
# MorningChecks.Email.psm1
# Sends the HTML report email with an automatic fallback to Office 365 SMTP.
#
# Depends on:  MorningChecks.Logging
#
# Author: Adenideni
# Version: 1.0.0
# Date: 2026-05-23

#
Set-StrictMode -Off

function Send-ReportEmail {
    <#
    .SYNOPSIS
        Sends the morning-checks HTML report via email.

    .DESCRIPTION
        Attempts delivery through the internal SMTP relay first.
        If that fails, retries via Office 365 SMTP (smtp.office365.com:587 / TLS).

    .PARAMETER From
        Sender address.

    .PARAMETER To
        Recipient address (or comma-separated list).

    .PARAMETER Subject
        Email subject line.

    .PARAMETER Body
        HTML body string.

    .PARAMETER SMTPServer
        Primary SMTP relay hostname or IP.

    .PARAMETER Credential
        Optional PSCredential for SMTP authentication.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$From,

        [Parameter(Mandatory = $true)]
        [string]$To,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [string]$SMTPServer,

        [PSCredential]$Credential = $null
    )

    Write-LogInfo -Message "Sending report email to: $To"

    $baseParams = @{
        From       = $From
        To         = $To
        Subject    = $Subject
        Body       = $Body
        BodyAsHtml = $true
    }

    if ($Credential) { $baseParams.Credential = $Credential }

    # ── Attempt 1: internal relay ──
    try {
        Send-MailMessage @baseParams -SmtpServer $SMTPServer -ErrorAction Stop
        Write-LogSuccess -Message "Email sent via internal relay ($SMTPServer)"
        return
    }
    catch {
        Write-LogError -Message "Internal relay failed: $($_.Exception.Message)"
    }

    # ── Attempt 2: Office 365 ──
    try {
        Write-LogInfo -Message "Retrying via Office 365 (smtp.office365.com:587)"
        Send-MailMessage @baseParams -SmtpServer 'smtp.office365.com' -Port 587 -UseSsl -ErrorAction Stop
        Write-LogSuccess -Message "Email sent via Office 365"
    }
    catch {
        Write-LogError -Message "Office 365 relay also failed: $($_.Exception.Message)"
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function 'Send-ReportEmail'

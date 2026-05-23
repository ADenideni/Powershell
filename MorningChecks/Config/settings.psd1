#
# settings.psd1
# Central configuration for the Morning Checks report.
# Edit these values to match your environment.
#
@{
    # ── Email ──────────────────────────────────────────────────────────────
    SMTPServer              = 'smtp.example.com'
    EmailFrom               = 'reports@example.com'
    EmailTo                 = 'ops@example.com'
    EmailSubjectPrefix      = 'Morning Checks Report'

    # ── Active Directory check thresholds ──────────────────────────────────
    PasswordExpiryDays      = 10    # Warn if password expires within X days
    PasswordChangesLookback = 7     # Look back X days for password changes
    StaleUserDays           = 60    # Flag users not logged in for X days
    StaleComputerDays       = 365   # Flag computers not logged in for X days

    # ── Disk space thresholds (free space %) ───────────────────────────────
    DiskCriticalThreshold   = 10   # Red alert
    DiskWarningThreshold    = 15   # Amber alert

    # ── VMware ─────────────────────────────────────────────────────────────
    VMwareHost              = 'vcenter.example.com'

    # ── Service account ────────────────────────────────────────────────────
    ServiceAccountName      = 'svc_reporting'

    # DPAPI-encrypted password (machine + account specific).
    # Leave empty to be prompted interactively.
    # Run .\Set-ServiceAccountPassword.ps1 once from the scheduled-task account to populate.
    ServiceAccountPassword  = ''

    # ── SharePoint ─────────────────────────────────────────────────────────
    SharePointSiteURL       = 'https://example.sharepoint.com/sites/operations'
    SharePointSourceFile    = '/Shared%20Documents/Templates/Daily%20Checks%20Template.docx'
}

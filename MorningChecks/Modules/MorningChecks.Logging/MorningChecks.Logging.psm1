# Author: ADenideni
# Email: a.denideni@hotmail.com
# Version: 1.0.0
# Date: 2026-05-23

#
# MorningChecks.Logging.psm1
# Provides structured logging to both the console and a timestamped log file.
#
# Usage:
#   Import-Module .\Modules\MorningChecks.Logging\MorningChecks.Logging.psm1 -Force
#   Initialize-Logging -LogDirectory 'C:\Logs' -Enabled $true
#   Start-Log
#   Write-LogInfo  'Processing...'
#   Write-LogSuccess 'Done.'
#   Stop-Log
#

Set-StrictMode -Off

# Module-scoped state
$script:LogFilePath    = $null
$script:LoggingEnabled = $false

# ──────────────────────────────────────────────────────────────────────────────
# Initialisation
# ──────────────────────────────────────────────────────────────────────────────

function Initialize-Logging {
    <#
    .SYNOPSIS
        Configures the log file path used by all Write-Log* functions.
    .PARAMETER LogDirectory
        Folder in which the timestamped log file will be created.
    .PARAMETER Enabled
        Set to $false to suppress file logging (console output is always shown).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,

        [bool]$Enabled = $true
    )

    $script:LoggingEnabled = $Enabled

    if ($Enabled) {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        $fileName            = "$(Get-Date -Format 'yyyy-MM-dd_HH-mm')_Log.txt"
        $script:LogFilePath  = Join-Path $LogDirectory $fileName

        if (-not (Test-Path $script:LogFilePath)) {
            New-Item -ItemType File -Path $script:LogFilePath -Force | Out-Null
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Internal writer
# ──────────────────────────────────────────────────────────────────────────────

function Write-LogEntry {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Color = 'White'
    )

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - [$Level] - $Message"
    Write-Host $line -ForegroundColor $Color

    if ($script:LoggingEnabled -and $script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $line -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Public log-level functions
# ──────────────────────────────────────────────────────────────────────────────

function Write-LogError {
    <#
    .SYNOPSIS  Writes a red [ERROR] line to the console and log file. #>
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-LogEntry -Level 'ERROR' -Message $Message -Color Red
}

function Write-LogSuccess {
    <#
    .SYNOPSIS  Writes a green [PASS] line to the console and log file. #>
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-LogEntry -Level 'PASS' -Message $Message -Color Green
}

function Write-LogInfo {
    <#
    .SYNOPSIS  Writes a yellow [INFO] line to the console and log file. #>
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-LogEntry -Level 'INFO' -Message $Message -Color Yellow
}

function Write-LogAction {
    <#
    .SYNOPSIS  Writes a cyan [ACTION] line to the console and log file. #>
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-LogEntry -Level 'ACTION' -Message $Message -Color Cyan
}

function Write-LogNewLine {
    <#
    .SYNOPSIS  Writes a blank line to the console and log file for readability. #>
    Write-Host ''
    if ($script:LoggingEnabled -and $script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value '' -ErrorAction SilentlyContinue
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Session boundary markers
# ──────────────────────────────────────────────────────────────────────────────

function Start-Log {
    <#
    .SYNOPSIS  Writes a session-start banner to the console and log file. #>
    $sep   = '*' * 99
    $lines = @(
        $sep
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - Script Started"
        ''
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - User:     $env:USERNAME"
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - Computer: $env:COMPUTERNAME"
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - Domain:   $env:USERDNSDOMAIN"
        ''
        $sep
        ''
    )
    foreach ($line in $lines) {
        Write-Host $line
        if ($script:LoggingEnabled -and $script:LogFilePath) {
            Add-Content -Path $script:LogFilePath -Value $line -ErrorAction SilentlyContinue
        }
    }
}

function Stop-Log {
    <#
    .SYNOPSIS  Writes a session-end banner to the console and log file. #>
    $sep   = '*' * 99
    $lines = @(
        ''
        $sep
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - Script Finished"
        $sep
    )
    foreach ($line in $lines) {
        Write-Host $line
        if ($script:LoggingEnabled -and $script:LogFilePath) {
            Add-Content -Path $script:LogFilePath -Value $line -ErrorAction SilentlyContinue
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Initialize-Logging'
    'Write-LogError'
    'Write-LogSuccess'
    'Write-LogInfo'
    'Write-LogAction'
    'Write-LogNewLine'
    'Start-Log'
    'Stop-Log'
)

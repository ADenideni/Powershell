Function Invoke-TemplateTask {
    <#
    .SYNOPSIS
        Brief Description.

    .DESCRIPTION
        Extended description.

    .EXAMPLE
        Invoke-TemplateTask Example

    .EXAMPLE
        Get the full commands
        Get-Help Invoke-TemplateTask -Full

    .PARAMETER Credential
        Enter the credential to use for SMTP authentication.

    .PARAMETER SendEmail
        BOOL (TRUE/FALSE) - Choose to send email report.

    .PARAMETER From
        Enter the address you wish to send the email from.

    .PARAMETER To
        Enter the address you wish to send the email to.

    .PARAMETER SMTPServer
        Enter the SMTP Server you would like to use.

    .PARAMETER EmailSubject
        Enter the Email Subject you would like to use.

    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Description of objects that are output by the script.

    .LINK
        Links to further documentation.

    .NOTES
        FileName:   Invoke-TemplateTask.ps1
        Author:     Abdel Denideni
        Email:      a.denideni@hotmail.com
        Created:    2022/10/25
        Updated:    2022/10/25

        Version History:
        V1.0.0 - 2022/10/25 - Initial Script Creation.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $false, Position = 1)]
        [bool]$SendEmail = $True,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$From = 'noreply@example.com',

        [Parameter(Mandatory = $false, Position = 3)]
        [string]$To = 'recipient@example.com',

        [Parameter(Mandatory = $false, Position = 4)]
        [string]$SMTPServer = 'smtp.example.com',

        [Parameter(Mandatory = $false, Position = 5)]
        [string]$EmailSubject = "Sample Report - $((Get-Date).ToString("yyyy-MM-dd")) - $(([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "$((Get-TimeZone).id)")).tostring("HH:mm")) $((Get-TimeZone).id)"
    )

    begin {
        # Start of the BEGIN block.

        $MailParams = @{
            From       = $From
            To         = $To
            Subject    = $EmailSubject
            SmtpServer = $SMTPServer
            BodyAsHtml = $true
        }

        if ($Credential) {
            $MailParams.Credential = $Credential
        }

        Function Send-MailMessage365 {

            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false)]
                [String]$From
                ,
                [Parameter(Mandatory = $false)]
                [PSCredential]$Credential
                ,
                [Parameter(Mandatory = $false)]
                [String]$To
                ,
                [Parameter(Mandatory = $false)]
                [String]$Body
                ,
                [Parameter(Mandatory = $false)]
                [String]$Subject
                ,
                [Parameter(Mandatory = $false)]
                [bool]$BodyAsHtml = $true
            )#param

            $Splat = @{
                To         = $To
                From       = $From
                Body       = $Body
                Subject    = $Subject
                SmtpServer = $SMTPServer
                Port       = 587
                UseSsl     = $true
                BodyAsHtml = $BodyAsHtml
            }

            if ($Credential) {
                $Splat.Credential = $Credential
            }

            Send-MailMessage @Splat

        }#Function

        Clear-Host
        $ErrorActionPreference = "Stop"
        Write-Output "[$(Get-Date)] - [INFO] - Script Started"
        $StartDTM = (Get-Date)

        if ([Environment]::Is64BitProcess) {
            Write-Output "[$(Get-Date)] - [INFO] - Script Running in 64-Bit"
        }#if
        else {
            Write-Output "[$(Get-Date)] - [INFO] - Script Running in 32-Bit"
        }#else

    }#begin

    process {
        # Start of PROCESS block.

        $ExampleResults = @(
            [pscustomobject]@{
                Name   = 'Example Item 01'
                Status = 'Success'
                Time   = (Get-Date).AddMinutes(-15)
            }
            [pscustomobject]@{
                Name   = 'Example Item 02'
                Status = 'Warning'
                Time   = Get-Date
            }
        )

    }#process

    end {
        # Start of END block.

        if ($SendEmail -eq $True) {
            $Body = @"
            <!DOCTYPE html>
            <html>
            <head>
            <style>

            body {
                font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif;
            }

            p {
                font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif;
                margin-top:5px;
                margin-bottom:5px;
            }

            h1 {
                text-align: left;
                text-transform: uppercase;
                color: #4CAF50;
                font-size: 25px;
            }

            table {
                font-family: Calibri, Candara, Segoe, "Segoe UI", Optima, Arial, sans-serif;
                border-collapse: collapse;
                width: 90%;
                border: 1px solid #ddd;
            }

            th, td {
                text-align: left;
                padding: 8px;
                border: 1px solid #ddd;
            }

            tr:nth-child(odd){background-color: #f2f2f2}

            th {
                background-color: #4CAF50;
                color: white;
                border: 1px solid #ddd;
            }

            </style>
            </head>

            <body>
                <br>
                <p>
                Hello,<br><br>

                This is sample output generated by the Invoke-TemplateTask example on $((Get-Date).ToLongDateString()) at $((Get-Date).ToString('HH:mm zzz')).<br><br>

                Replace the sample objects and HTML sections below with the real data and layout for your own function.<br><br>

                <br>
                <h1>Example Results</h1>
                $($ExampleResults | Sort-Object Name | ConvertTo-Html -Fragment)
                <br><br>

                </p>
            </body>
            </html>
"@

            try {

                Write-Output "[$(Get-Date)] - [INFO] - Sending Email"

                $PrimaryMailParams = $MailParams.Clone()
                $PrimaryMailParams.Body = $Body
                $PrimaryMailParams.ErrorAction = 'Stop'

                Send-MailMessage @PrimaryMailParams
                Write-Output "[$(Get-Date)] - [INFO] - Email Sent successfully"

            }#try
            catch {

                try {

                    Send-MailMessage365 -From $From -Credential $Credential -To $To -Body $Body -Subject $EmailSubject -ErrorAction Stop

                }#try
                catch {

                    Write-Output "[$(Get-Date)] - [ERROR] - Error occured while sending email"
                    Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

                }#catch

            }#catch

        }#if


        ""
        Write-Output "[$(Get-Date)] - [INFO] - Script Ended"
        $EndDTM = (Get-Date)

        if ([int]$("{0:N2}" -f ($EndDTM - $StartDTM).TotalSeconds) -lt 60) {
            Write-Output "[$(Get-Date)] - [INFO] - Elapsed Time: $("{0:N2}" -f ($EndDTM-$StartDTM).TotalSeconds) Seconds"
        }#if
        else {
            Write-Output "[$(Get-Date)] - [INFO] - Elapsed Time: $("{0:N2}" -f ($EndDTM-$StartDTM).TotalMinutes) Minutes"
        }#else

    }#end

}#function





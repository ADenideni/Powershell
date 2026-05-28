Function Get-AzureStaleNodes {
    <#
    .SYNOPSIS
        Brief Description.

    .DESCRIPTION
        Extended description.

    .EXAMPLE
        Get-AzureStaleNodes Example

    .EXAMPLE
        Get the full commands
        Get-Help Get-AzureStaleNodes -Full

    .PARAMETER Username
        Enter Office 365 Username.

    .PARAMETER Password
        Enter Office 365 Password.

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
        FileName:   Get-AzureStaleNodes.ps1
        Author:     Abdel Denideni
        Email:      a.denideni@hotmail.com
        Created:    2025/04/02
        Updated:    2025/04/02

        Version History:
        V1.0.0 - 2025/04/02 - Initial Script Creation.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [int]$DaysToCheck = 120,

        [Parameter(Mandatory = $false)]
        [string]$TenantName = "example.onmicrosoft.com",

        [Parameter(Mandatory = $false)]
        [string]$ClientID = '11111111-1111-1111-1111-111111111111',

        [Parameter(Mandatory = $false)]
        [string]$ClientSecret = 'REPLACE_WITH_CLIENT_SECRET',

        [Parameter(Mandatory = $false)]
        [string]$Scope = 'https://graph.microsoft.com/.default',

        [Parameter(Mandatory = $false)]
        [string]$MSFT = "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token",

        [Parameter(Mandatory = $false)]
        [String]$GraphURI = 'https://graph.microsoft.com/v1.0/devices',

        [Parameter(Mandatory = $false)]
        [bool]$SendEmail = $false,

        [Parameter(Mandatory = $false)]
        [string]$From = 'noreply@example.com',

        [Parameter(Mandatory = $false)]
        [string]$To = 'your.email@example.com',

        [Parameter(Mandatory = $false)]
        [string]$SMTPServer = 'smtp.example.com',

        [Parameter(Mandatory  = $false)]
        [string]$Username     = 'service_account',

        [Parameter(Mandatory  = $false)]
        [String]$Password     = 'REPLACE_WITH_PASSWORD',

        [Parameter(Mandatory = $false)]
        [string]$EmailSubject = "Stale Nodes Report - $((Get-Date).ToString("yyyy-MM-dd")) - $(([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "$((Get-TimeZone).id)")).tostring("HH:mm")) $((Get-TimeZone).id)"
    )

    begin {
        # Start of the BEGIN block.

        #Convert Password
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential (($From + '@Example Organization.com'), $SecurePassword)

        Function Send-MailMessage365 {

            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $false)]
                [String]$From
                ,
                [Parameter(Mandatory = $false)]
                [String]$FromUserPassword
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

            #Convert Plain text credetials
            $SecurePassword = ConvertTo-SecureString $AzurePassword -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential ($From, $SecurePassword)

            Send-MailMessage -To $To -From $From -Body $Body -Subject $Subject -SmtpServer $SMTPServer -Port 587 -UseSsl -Credential $Credentials -BodyAsHtml

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



        #Headers to retrieve Access Token
        $body = @{
            "client_id"     = $ClientID
            "client_secret" = $ClientSecret
            "grant_type"    = "client_credentials"
            "scope"         = $Scope
        }


        Write-Output "[$(Get-Date)] - [INFO] - Getting Microsoft Access Token"
        try {
            $Authresponse = Invoke-WebRequest -Uri "$MSFT" `
            -Method Post `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $body -erroraction stop
        }
        catch {
            Write-Output "[$(Get-Date)] - [ERROR] - Error occured while getting Microsoft Access Token"
            Write-Output "[$(Get-Date)] - [ERROR MESSAGE] - $($_.Exception.Message)"
        }


        $AccessToken = (Convertfrom-Json $Authresponse.Content).access_token

        #The Headers to use for connections to Microsoft Graph
        $AccessTokenHeaders = @{ Authorization = "Bearer $accessToken" }

    }#begin

    process {
        # Start of PROCESS block.

        #Pull Data from Azure
        $Results = (Invoke-RestMethod -Uri $GraphURI -Headers $AccessTokenHeaders -Method Get -ContentType "application/json").value

        #$FilteredResults = $Results | Where-Object { ($_.approximateLastSignInDateTime -gt $((get-date).AddDays( - [int]$DaysToCheck))) }



        #Filter Date
        #$FilteredResults = $Results | Where-Object { ($_.approximateLastSignInDateTime -gt $((get-date).AddDays(-[int]$DaysToCheck))) -or ($_.onPremisesLastSyncDateTime -gt $((get-date).AddDays(-[int]$DaysToCheck))) }

        $ActiveTableResults = $null
        $ActiveTableResults = @()
        $StaleTableResults = $null
        $StaleTableResults = @()


        foreach ($Result in $FilteredResults){

            $CovertedLastSignInDate = $null
            $onPremisesLastSyncDateTime = $null

            $CovertedLastSignInDate = if ($Result.approximateLastSignInDateTime) { Get-Date ($Result.approximateLastSignInDateTime) }
            $onPremisesLastSyncDateTime = if ($Result.onPremisesLastSyncDateTime) { Get-Date ($Result.onPremisesLastSyncDateTime)}

            "$($Result.displayName) - On Prem sign in = $CovertedLastSignInDate"
            "$($Result.displayName) - Last Sign Prem sign in = $onPremisesLastSyncDateTime"

            if (($CovertedLastSignInDate -lt $((get-date).AddDays(-$DaysToCheck)) -and ($onPremisesLastSyncDateTime -lt $((get-date).AddDays(-$DaysToCheck))) )) {

                #Convert Data to Table
                $StaleTableResults += New-Object PSCustomObject -Property @{
                    DisplayName = $Result.displayName
                    LastSignIn  = $CovertedLastSignInDate
                    LastOnPremSync = $onPremisesLastSyncDateTime
                    OS          = $Result.operatingSystem
                    OSVersion   = $Result.operatingSystemVersion
                    Model       = $Result.model
                    Enabled     = $Result.accountEnabled
                    id          = $Result.id
                }#EndCustomObject
            }


            <#

            if (($onPremisesLastSyncDateTime -ne $null) -and ($onPremisesLastSyncDateTime -lt $((get-date).AddDays(-$DaysToCheck)))){

                #Convert Data to Table
                $StaleTableResults += New-Object PSCustomObject -Property @{
                    DisplayName = $Result.displayName
                    LastSignIn  = $( if ($Result.approximateLastSignInDateTime) { Get-Date ($Result.approximateLastSignInDateTime) }else { ($Result.approximateLastSignInDateTime) })
                    OS          = $Result.operatingSystem
                    OSVersion   = $Result.operatingSystemVersion
                    Model       = $Result.model
                    Enabled     = $Result.accountEnabled
                    id          = $Result.id
                }#EndCustomObject
            }


            elseif ($onPremisesLastSyncDateTime -gt $((get-date).AddDays( - [int]$DaysToCheck))) {
                #Convert Data to Table
                $TableResults += New-Object PSCustomObject -Property @{
                    DisplayName    = $Result.displayName
                    LastSignIn     = ($Result.approximateLastSignInDateTime)
                    LastSignInDate = $(if ($Result.approximateLastSignInDateTime) { Get-Date ($Result.approximateLastSignInDateTime) -Format "yyyy-MM-dd" })
                    LastSignInTime = $(if ($Result.approximateLastSignInDateTime) { Get-Date ($Result.approximateLastSignInDateTime) -Format "HH:mm:ss" })
                    OS             = $Result.operatingSystem
                    OSVersion      = $Result.operatingSystemVersion
                    Model          = $Result.model
                    Enabled        = $Result.accountEnabled
                    id             = $Result.id
                }#EndCustomObject
            }
            #>


        }

        #Display Data
        $StaleTableResults | Select-Object DisplayName, LastSignIn, LastOnPremSync, OS, OSVersion, Model, Enabled, id | Sort-Object LastSignIn
        $StaleTableResults.Count

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
                All,<br><br>

                The following report was automatically generated on $((get-date).ToLongDateString()) at $(([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "GMT Standard Time")).tostring("HH:mm")) GMT - $([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "US Eastern Standard Time").tostring("HH:mm")) EST.<br><br>

                <h1>Stale Nodes</h1>

                $($StaleTableResults.Count) devices have not signed in or syned in $($DaysToCheck) days.
                <br><br><br>

                $($StaleTableResults | Select-Object DisplayName, LastSignIn, LastOnPremSync, OS, OSVersion, Model, Enabled | Sort-Object LastSignIn -Descending  | ConvertTo-Html -Fragment)
                <br><br>

                </p>
            </body>
            </html>
"@

            try {

                Write-Output "[$(Get-Date)] - [INFO] - Sending Email"

                Send-MailMessage -From $From -To $To -Subject $EmailSubject -Body $Body -smtpserver $SMTPServer -BodyAsHtml -Credential $Credentials -ErrorAction Stop
                Write-Output "[$(Get-Date)] - [INFO] - Email Sent successfully"

            }#try
            catch {

                try {

                    Send-MailMessage365 -From $Username -FromUserPassword $Password -To $To -Body $Body -Subject $EmailSubject -ErrorAction Stop

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


Get-AzureStaleNodes -DaysToCheck 120 -SendEmail $true


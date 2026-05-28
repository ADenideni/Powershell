<#
.SYNOPSIS
    Brief Description.

.DESCRIPTION
    Extended description.

.EXAMPLE
    Function-Name Example

.EXAMPLE
    Get the full commands
    Get-Help Get-HyperVHealthReport -Full

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
    FileName:   Get-HyperVHealthReport.ps1
    Author:     Abdel Denideni
    Email:      a.denideni@hotmail.com
    Created:    2025/01/06
    Updated:    2022/01/06

    Version History:
    V1.0.0 - 2022/01/06 - Initial Script Creation.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Username = 'service_account',

    [Parameter(Mandatory = $false, Position = 1)]
    [String]$Password = 'REPLACE_WITH_PASSWORD',

    [Parameter(Mandatory = $false, Position = 2)]
    [bool]$SendEmail = $True,

    [Parameter(Mandatory = $false, Position = 3)]
    [string]$From = 'noreply@example.com',

    [Parameter(Mandatory = $false, Position = 4)]
    [string]$To = 'noreply@example.com',

    [Parameter(Mandatory = $false, Position = 5)]
    [string]$SMTPServer = 'smtp.example.com',

    [Parameter(Mandatory = $false, Position = 6)]
    [string]$EmailSubject = "Hyper-V Report - $((Get-Date).ToString("yyyy-MM-dd")) - $(([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::Now, "$((Get-TimeZone).id)")).tostring("HH:mm")) $((Get-TimeZone).id)"
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




    $HyperVSecurePassword = ConvertTo-SecureString 'REPLACE_WITH_PASSWORD' -AsPlainText -Force
    $HyperVCredentials = New-Object System.Management.Automation.PSCredential (('service_account'), $HyperVSecurePassword)





    $HyperVHostDetails = Invoke-Command -ComputerName ldnhv01, ldnhv02, nyhv01, nyhv02 -Credential $HyperVCredentials -ScriptBlock {

        # Gather Hyper-V host information
        $HostInfo = Get-WmiObject win32_operatingsystem


        $HostDisks = Get-WmiObject win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } # Only fixed drives
        foreach ($disk in $HostDisks) {
            $percentUsed = ($disk.Size - $disk.FreeSpace)
            $percentFree = $disk.FreeSpace
            $($disk.DeviceID)
        }








        $HostCPUUsage = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object -ExpandProperty Average


        # Correct memory usage calculation
        $os = Get-WmiObject win32_operatingsystem

        $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)  # Convert to GB, but display in MB labeled as GB for Windows style
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedMemoryGB = $totalMemoryGB - $freeMemoryGB
        $memoryUsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)

        $Results = New-Object PSCustomObject -Property @{
            Host                = $Env:COMPUTERNAME
            'CPU Usage (%)'     = $HostCPUUsage
            'Total Memory (GB)' = $totalMemoryGB
            'Used Memory (GB)'  = $usedMemoryGB
            'Free Memory (GB)'  = $freeMemoryGB
            'Memory Usage (%)'  = $memoryUsagePercent
        }#EndCustomObject

        $Results

    }


    $VMResults = Invoke-Command -ComputerName ldnhv01, ldnhv02, nyhv01, nyhv02 -Credential $HyperVCredentials -ScriptBlock {

        $os = Get-WmiObject win32_operatingsystem
        $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)  # Convert to GB, but display in MB labeled as GB for Windows style
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedMemoryGB = $totalMemoryGB - $freeMemoryGB
        $memoryUsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)

        $HostDisks = Get-WmiObject win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } # Only fixed drives
        $HostCPUUsage = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select-Object -ExpandProperty Average

        foreach ($disk in $HostDisks) {
            $percentUsed = ($disk.Size - $disk.FreeSpace)
            $percentFree = $disk.FreeSpace
            $($disk.DeviceID)
        }

        $ReplicatedVMs = Get-VM | Where-Object { $_.ReplicationMode -ne "None" }
        $Results = @()
        foreach ($VM in $ReplicatedVMs) {
            $os = Get-WmiObject win32_operatingsystem
            #Get-VMReplication -VMName $VM.Name
            $Disks = $VM | Get-VMHardDiskDrive | Get-VHD
            $totalDiskSpace = ($Disks | Measure-Object -Property Size -Sum).Sum
            $usedDiskSpace = ($Disks | Measure-Object -Property FileSize -Sum).Sum
            $freeDiskSpace = $totalDiskSpace - $usedDiskSpace


            #Add Results to a hash table
            $Results += New-Object PSCustomObject -Property @{
                Host                = $Env:COMPUTERNAME
                'Name'              = $VM.Name
                'State'             = $VM.State
                'Status'            = $VM.Status
                'Replication State' = $VM.ReplicationState
                'Memory'            = [math]::Round($VM.MemoryAssigned / 1MB, 2)
                'Up Time'           = $VM.Uptime
                'Replication Mode'  = $VM.ReplicationMode
                'CPU Usage'         = $VM.CPUUsage
                'Total Memory (GB)' = $VM.MemoryAssigned
            }#EndCustomObject

        }
        $Results
    }



}#begin

process {
    # Start of PROCESS block.

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

            <br>
            <h1>Hyper-V Host Details</h1>
            $($HyperVHostDetails | Where-Object {$_.host -ne $null} | Select-Object Host,'CPU Usage (%)','Memory Usage (%)','Total Memory (GB)','Used Memory (GB)','Free Memory (GB)' | ConvertTo-Html -Fragment)
            <br><br>

            <h1>VM Details</h1>
            $($VMResults | Where-Object {$_.host -ne $null} | Select-Object Host,Name,State,Status,Memory,'Replication State','CPU Usage','Up Time' | Sort-Object Name,Host | ConvertTo-Html -Fragment)
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


Function Get-NetworkHealthChecks {
    <#
    .SYNOPSIS
        Runs a network health report covering connectivity, replication, file access, file copy, and internet speed tests.

    .DESCRIPTION
        Collects network health information for domain controllers, remote endpoints, file shares, internet access, and optional email reporting.
        The internet speed test requires `speedtest.exe` to be present at the path supplied by `SpeedTestExecutablePath`.
        If the executable is not already available, download it first and then point this script to that local file.

    .EXAMPLE
        Get-NetworkHealthChecks Example

    .EXAMPLE
        Get the full commands
        Get-Help Get-NetworkHealthChecks -Full

    .PARAMETER Credential
        Enter the SMTP credential to use for authenticated email delivery.

    .PARAMETER RemoteSiteEndpoints
        Enter the remote endpoints to include in connectivity testing.

    .PARAMETER Shares
        Enter the UNC paths to validate for file access and copy checks.

    .PARAMETER SpeedTestExecutablePath
        Enter the local path to the Ookla Speedtest executable.
        Download `speedtest.exe` first if it is not already present on the machine.

    .NOTES
        FileName:   Get-NetworkHealthChecks.ps1
        Author:     Your Name
        Email:      your.email@example.com
        Created:    2022/09/21
        Updated:    2022/09/26

        Version History:
        V1.0.1 - 2022/09/26 - Added Internet SpeedTest.
        V1.0.0 - 2022/09/21 - Initial Script Creation.

    #>

    [CmdletBinding()]
    param
    (
        [Parameter(
            Mandatory = $false,
            Position = 0,
            HelpMessage = "Enter the SMTP credential."
        )]
        [PSCredential]$Credential
        ,
        [Parameter(
            Mandatory = $false,
            Position = 1,
            HelpMessage = "Send Email."
        )]
        [Bool]$SendEmail = $True
        ,
        [Parameter(
            Mandatory = $false,
            Position = 2,
            HelpMessage = "Send Email - From."
        )]
        [string]$From = 'noreply@example.com'
        ,
        [Parameter(
            Mandatory = $false,
            Position = 3,
            HelpMessage = "Send Email - To."
        )]
        [string]$To = 'recipient@example.com'
        ,
        [Parameter(
            Mandatory = $false,
            Position = 4,
            HelpMessage = "Send Email - SMTP Server."
        )]
        [string]$SMTPServer = 'smtp.example.com'
        ,
        [Parameter(
            Mandatory = $false,
            Position = 5,
            HelpMessage = "Send Email - SMTP Server."
        )]
        [string]$EmailSubject = "Network Health Check Report - $(Get-Date -format yyyy-MM-dd)"
        ,
        [Parameter(
            Mandatory = $false,
            Position = 6,
            HelpMessage = "Enter remote endpoints to test."
        )]
        [object[]]$RemoteSiteEndpoints = @(
            @{Name = 'Site A Router'; IP = '192.0.2.10'; Location = 'Primary Office' },
            @{Name = 'Site B Router'; IP = '198.51.100.20'; Location = 'Secondary Office' }
        )
        ,
        [Parameter(
            Mandatory = $false,
            Position = 7,
            HelpMessage = "Enter UNC paths to validate."
        )]
        [string[]]$Shares = @('\\fileserver01\operations', '\\fileserver02\shared')
        ,
        [Parameter(
            Mandatory = $false,
            Position = 8,
            HelpMessage = "Enter the local path to speedtest.exe."
        )]
        [string]$SpeedTestExecutablePath = 'C:\Tools\speedtest.exe'
    )#param

    begin {
        # Start of the BEGIN block.
        Clear-Host
        $ErrorActionPreference = "Stop"
        Write-Output "[$(Get-Date)] - [INFO] - Script Started"
        $StartDTM = (Get-Date)

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

            $MailParams = @{
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
                $MailParams.Credential = $Credential
            }

            Send-MailMessage @MailParams

        }#Function



        $ADForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        $DomainControllers = $ADForest.GlobalCatalogs.name

    }#begin

    process {
        # Start of PROCESS block.
        Clear-Host

        #Site Connectivity
        $PingTestResults = $null
        $PingTestResults = @()
        foreach ($DomainController in $DomainControllers) {
            ""
            Write-Output "[$(Get-Date)] - [INFO] - Pinging $DomainController"
            try {
                $PingResults = Test-Connection -ComputerName $DomainController -ErrorAction Stop -Count 1

                $PingTestResults += New-Object PSCustomObject -Property @{
                    'Source'       = $PingResults.PSComputerName
                    'Destination'  = $PingResults.Address
                    'IPV4 Address' = $PingResults.IPV4Address
                    'Bytes'        = $PingResults.ReplySize
                    'Time (ms)'    = $PingResults.ResponseTime
                    Result         = "Successful"
                }#EndCustomObject
            }#try
            catch {
                Write-Output "[$(Get-Date)] - [ERROR] - Error occured pinging $DomainController"
                Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

                $PingTestResults += New-Object PSCustomObject -Property @{
                    'Source'       = $PingResults.PSComputerName
                    'Destination'  = $PingResults.Address
                    'IPV4 Address' = $PingResults.IPV4Address
                    'Bytes'        = $PingResults.ReplySize
                    'Time (ms)'    = $PingResults.ResponseTime
                    Result         = "Fail"
                }#EndCustomObject
            }#catch

        }#foreach

        $RemoteSiteDetails = $RemoteSiteEndpoints | ForEach-Object {
            [pscustomobject]@{
                Name     = $_.Name
                IP       = $_.IP
                Location = $_.Location
            }
        }


        #881 Ping Results
        $RemoteSitePingTestResults = $null
        $RemoteSitePingTestResults = @()
        foreach ($RemoteSite in $RemoteSiteDetails) {
            ""
            Write-Output "[$(Get-Date)] - [INFO] - Pinging $($RemoteSite.IP)"
            try {
                $RemoteSitePingResults = Test-Connection -ComputerName $($RemoteSite.IP) -ErrorAction Stop -Count 1

                $RemoteSitePingTestResults += New-Object PSCustomObject -Property @{
                    'Source'      = $RemoteSitePingResults.PSComputerName
                    'Destination' = $RemoteSitePingResults.Address
                    'Bytes'       = $RemoteSitePingResults.ReplySize
                    'Time (ms)'   = $RemoteSitePingResults.ResponseTime
                    Name          = $RemoteSite.Name
                    Location      = $RemoteSite.Location
                    Result        = "Successful"
                }#EndCustomObject
            }#try
            catch {
                Write-Output "[$(Get-Date)] - [ERROR] - Error occured pinging $($RemoteSite.IP)"
                Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

                $RemoteSitePingTestResults += New-Object PSCustomObject -Property @{
                    'Source'      = $RemoteSitePingResults.PSComputerName
                    'Destination' = $RemoteSitePingResults.Address
                    'Bytes'       = $RemoteSitePingResults.ReplySize
                    'Time (ms)'   = $RemoteSitePingResults.ResponseTime
                    Name          = $RemoteSite.Name
                    Location      = $RemoteSite.Location
                    Result        = "Fail"
                }#EndCustomObject
            }#catch

        }#foreach









        #Check Internet Connection
        $InternetTestResults = @()
        ""
        Write-Output "[$(Get-Date)] - [INFO] - Performing Internet Checks"
        try {
            $InternetTest = Test-NetConnection -InformationLevel "Detailed" -ErrorAction Stop

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject
        }#try
        catch {
            Write-Output "[$(Get-Date)] - [ERROR] - Error occured while accessing the internet"
            Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject

        }#catch

        ""
        Write-Output "[$(Get-Date)] - [INFO] - Performing Internet Checks - google.com"
        try {
            $InternetTest = Test-NetConnection -ComputerName "www.google.com" -InformationLevel "Detailed" -ErrorAction Stop

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject
        }#try
        catch {
            Write-Output "[$(Get-Date)] - [ERROR] - Error occured while accessing Google"
            Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject
        }#catch


        ""
        Write-Output "[$(Get-Date)] - [INFO] - Performing Internet Checks - bbc.com"
        try {
            $InternetTest = Test-NetConnection -ComputerName "www.bbc.com" -InformationLevel "Detailed" -ErrorAction stop

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject
        }#try
        catch {
            Write-Output "[$(Get-Date)] - [ERROR] - Error occured while accessing Google"
            Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

            $InternetTestResults += New-Object PSCustomObject -Property @{
                'Website'            = $InternetTest.Computername
                'Website IP Address' = $InternetTest.RemoteAddress
                'Ping Status'        = $InternetTest.PingSucceeded
                'Internet Status'    = if ($InternetTest.PingSucceeded -eq 'True') { "Successful" }else { 'Fail' }
            }#EndCustomObject
        }#catch


        #AD
        $DomainControllerResults = $null
        $DomainControllerResults = @()
        foreach ($DomainController in $DomainControllers) {
            ""
            Write-Output "[$(get-date)] - [INFO] - Checking AD on $DomainController"
            $DomainControllerResult = Get-ADReplicationPartnerMetadata -Target $DomainController -Partition domain | Select-Object Server, @{n = "Partner"; e = { (Resolve-DnsName $_.PartnerAddress).NameHost } }, LastReplicationAttempt

            foreach ($DetailedDomainControllerResult in $DomainControllerResult) {
                $DomainControllerResults += New-Object PSCustomObject -Property @{
                    'Source Domain Controller' = $DetailedDomainControllerResult.Server
                    'Destination DC'           = $DetailedDomainControllerResult.Partner
                    'Last Replication'         = $DetailedDomainControllerResult.LastReplicationAttempt
                    Result                     = if ($DetailedDomainControllerResult.LastReplicationAttempt -gt (get-date).AddMinutes(-15)) { "Successful" }else { "Fail" }

                }#EndCustomObject
            }#foreach

        }#foreach



        #DNS
        Write-Output "[$(Get-Date)] - [INFO] - Performing DNS Checks"
        $DNSResults = $null
        $DNSResults = @()
        foreach ($DomainController in $DomainControllers) {
            $ADPartitionList = repadmin /showrepl $DomainController | select-string "dc=" | Where-Object { $_ -like "*DC=DomainDnsZones*" }

            foreach ($ADPartition in $ADPartitionList) {
                $result = repadmin /showrepl $DomainController $ADPartition
                $result = $result | Where-Object { ([string]::IsNullOrEmpty(($result[$_]))) }
                $index_array_dst = 0..($result.Count - 1) | Where-Object { $result[$_] -like "*via RPC" }

                foreach ($index in $index_array_dst) {
                    $DestinationDC = ($result[$index]).trim()
                    $next_index = [array]::IndexOf($index_array_dst, $index) + 1

                    $msg = ""

                    if ($index -lt $index_array_dst[-1]) {
                        $last_index = $index_array_dst[$next_index]
                    }#if
                    else {
                        $last_index = $result.Count
                    }#else

                    for ($i = $index + 1; $i -lt $last_index; $i++) {

                        if (($msg -eq "") -and ($result[$i])) {
                            $msg += ($result[$i]).trim()
                        }#if
                        else {
                            $msg += " / " + ($result[$i]).trim()
                        }#else

                    }#for


                    $DNSResults += New-Object PSCustomObject -Property @{
                        'Source Domain Controller' = ($DomainController -replace ".$($ADForest.name)", "").toupper()
                        NC                         = $ADPartition
                        'Destination Site'         = (($DestinationDC -replace " via RPC", '') -split '\\')[0]
                        'Destination DC'           = (($DestinationDC -replace " via RPC", '') -split '\\')[1]
                        'Replication Time'         = ((($msg -split '/ Last attempt @ ')[1]) -split ' was ')[0]
                        'Replication Status'       = if ( ((($msg -split '/ Last attempt @ ')[1]) -split ' was ')[1] -eq 'successful.') { "Successful" } else { ((($msg -split '/ Last attempt @ ')[1]) -split ' was ')[1] }
                    }#EndCustomObject

                    if ($DNSResults | Where-Object { $_.'Replication Status' -notlike "*successful*" }) {
                        Write-Output "[$(Get-Date)] - [ERROR] - Replication Error"
                        $message += $DNSResults | Where-Object { $_.'Replication Status' -notlike "*successful*" } | Select-Object 'Source Domain Controller', 'Destination Site', 'Destination DC', 'Replication Time', 'Replication Status', nc
                        $message
                    }#if

                }#foreach

            }#foreach

        }#foreach


        #File Access
        Write-Output "[$(Get-Date)] - [INFO] - Performing File Access Checks"
        $FileAccessResults = $null
        $FileAccessResults = @()


        foreach ($Share in $Shares) {
            try {
                $ShareResults = Test-Path $Share -ErrorAction Stop

                $FileAccessResults += New-Object PSCustomObject -Property @{
                    'Share'      = $Share.toupper()
                    'Accessible' = $ShareResults
                }#EndCustomObject
            }#try
            catch {
                Write-Output "[$(Get-Date)] - [ERROR] - Error occured while accessing $Share"
                Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"

                $FileAccessResults += New-Object PSCustomObject -Property @{
                    'Share'      = $Share.toupper()
                    'Accessible' = $ShareResults
                }#EndCustomObject
            }#catch

        }#foreach

        #File Copy
        Write-Output "[$(Get-Date)] - [INFO] - Performing File Copy Checks"
        $FileTransferResults = $null
        $FileTransferResults = @()


        #Create Dummy File (50MB)
        fsutil file createnew c:\temp\SampleFile.txt 52428800

        $item = get-item 'c:\temp\SampleFile.txt'

        foreach ($Share in $Shares) {

            $Time = Measure-Command -Expression {
                try {
                    Copy-Item -literalpath $item.FullName "$Share\temp\SampleFile.txt" -ErrorAction Stop
                }#try
                catch {
                    Write-Output "[$(Get-Date)] - [ERROR] - Error occured while copying file to $Share\temp\SampleFile.txt"
                    Write-Output "[$(Get-Date)] - [ERROR] - $($_.Exception.Message)"
                }#catch

            }#measure-command

            $TransferRate = ($item.length / 1024 / 1024) / $time.TotalSeconds

            $FileTransferResults += New-Object PSCustomObject -Property @{
                Source          = $item.fullname
                'File Size'     = "$($item.Length /1024/1024) MB"
                'Time Taken'    = "$("{0:N2}" -f ($time.TotalSeconds)) Seconds"
                'Transfer Rate' = "$("{0:N2}" -f ($TransferRate)) MB/s"
                Destination     = "$Share\temp\SampleFile.txt"
            }#custom-object

        }#foreach


        #Internet Speed Test Checks
        Write-Output "[$(Get-Date)] - [INFO] - Performing Internet Speed Test Checks"
        if (Test-Path -LiteralPath $SpeedTestExecutablePath) {
            $localSpeedTestPath = Join-Path -Path $env:TEMP -ChildPath 'speedtest.exe'
            Copy-Item -LiteralPath $SpeedTestExecutablePath -Destination $localSpeedTestPath -Force -Confirm:$false
            $test = & $localSpeedTestPath --accept-license --format=json --accept-gdpr
            $InternetSpeedTestJSONResults = ConvertFrom-Json $test

            $InternetSpeedTestResults = New-Object PSCustomObject -Property @{
                'Time Stamp'       = $InternetSpeedTestJSONResults.timestamp
                'Download Jitter'  = $InternetSpeedTestJSONResults.ping.jitter
                'Download Latency' = $InternetSpeedTestJSONResults.ping.latency
                'Download Speed'   = "$('{0:N2}' -f ($InternetSpeedTestJSONResults.download.bandwidth / 1000000)) MB/s"
                'Upload Speed'     = "$('{0:N2}' -f ($InternetSpeedTestJSONResults.upload.bandwidth / 1000000)) MB/s"
                'Internal ISP'     = $InternetSpeedTestJSONResults.isp
                'Server Host'      = $InternetSpeedTestJSONResults.server.host
                'Server Name'      = $InternetSpeedTestJSONResults.server.name
                'Server Location'  = $InternetSpeedTestJSONResults.server.location
                'Server Country'   = $InternetSpeedTestJSONResults.server.country
                'Server IP'        = $InternetSpeedTestJSONResults.server.ip
                'Status'           = 'Completed'
            }#custom-object
        }
        else {
            Write-Output "[$(Get-Date)] - [ERROR] - Speed test executable not found at $SpeedTestExecutablePath"

            $InternetSpeedTestResults = New-Object PSCustomObject -Property @{
                'Time Stamp'       = Get-Date
                'Download Jitter'  = $null
                'Download Latency' = $null
                'Download Speed'   = 'N/A'
                'Upload Speed'     = 'N/A'
                'Internal ISP'     = 'N/A'
                'Server Host'      = 'N/A'
                'Server Name'      = 'N/A'
                'Server Location'  = 'N/A'
                'Server Country'   = 'N/A'
                'Server IP'        = 'N/A'
                'Status'           = "Executable not found: $SpeedTestExecutablePath"
            }#custom-object
        }


        #Send Email

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
                The following report was automatically generated on $(Get-Date -format yyyy-MM-dd) at $(Get-Date -Format HH:mm).<br><br>

                <br>
                <h1>Ping Results</h1>
                $($PingTestResults | Select-Object Source,Destination,'IPV4 Address','Time (ms)',Bytes,Result | ConvertTo-Html  -Fragment)
                <br><br>

                <h1>Remote Site Ping Results</h1>
                $($RemoteSitePingTestResults | Select-Object Source,Destination,Name,Location,Result | ConvertTo-Html  -Fragment)
                <br><br>

                <h1>Domain Controller Replication Results</h1>
                $($DomainControllerResults | Select-Object 'Source Domain Controller','Destination DC','Last Replication',Result | ConvertTo-Html  -Fragment)
                <br><br>

                <h1>Internet Access Results</h1>
                $($InternetTestResults | Select-Object Website,'Website IP Address','Ping Status', 'Internet Status' | ConvertTo-Html  -Fragment )
                <br><br>

                <h1>Internet Speed Test Results</h1>
                $($InternetSpeedTestResults | Select-Object 'Time Stamp','Internal ISP','Server Country','Server Name','Server Host','Server IP','Server Location','Download Jitter','Download Latency','Download Speed','Upload Speed',Status | ConvertTo-Html -as List -Fragment)
                <br><br>


                <h1>File Access Results</h1>
                $($FileAccessResults | Select-Object Share,Accessible | ConvertTo-Html  -Fragment)
                <br><br>


                <h1>File Copy Results Results</h1>
                $($FileTransferResults | Select-Object Source,'File Size',Destination,'Time Taken','Transfer Rate' | ConvertTo-Html  -Fragment)
                <br><br>



                <h1>DNS Replication Results</h1>
                $($DNSResults | Select-Object 'Source Domain Controller','Destination Site','Destination DC','Replication Time','Replication Status' | ConvertTo-Html  -Fragment)
                <br><br>



                </p>
            </body>
            </html>
"@


        try {

            Write-Output "[$(Get-Date)] - [INFO] - Sending Email"

            $MailParams = @{
                From        = $From
                To          = $To
                Subject     = $EmailSubject
                Body        = $Body
                SmtpServer  = $SMTPServer
                BodyAsHtml  = $true
                ErrorAction = 'Stop'
            }

            if ($Credential) {
                $MailParams.Credential = $Credential
            }

            Send-MailMessage @MailParams
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


    }#process

    end {
        # Start of END block.
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

Get-NetworkHealthChecks
#
# devices.psd1
# Defines the network devices pinged in each section of the morning report.
# Add, remove or edit entries as the estate changes.
#
@{
    # Example domain controllers and core servers
    CoreServers = @(
        @{ Device = 'APP-DC-01'; Name = 'APP-DC-01'; URL = $null }
        @{ Device = 'APP-DC-02'; Name = 'APP-DC-02'; URL = $null }
        @{ Device = 'APP-FILE-01'; Name = 'APP-FILE-01'; URL = $null }
        @{ Device = 'APP-WEB-01'; Name = 'APP-WEB-01'; URL = $null }
        @{ Device = 'APP-APP-01'; Name = 'APP-APP-01'; URL = $null }
    )

    # Example network appliances, NAS and other infrastructure
    CoreDevices = @(
        @{ Device = '192.0.2.10';    Name = 'Primary Firewall';   URL = 'https://192.0.2.10/' }
        @{ Device = '192.0.2.11';    Name = 'Secondary Firewall'; URL = 'https://192.0.2.11/' }
        @{ Device = 'nas-primary';   Name = 'Primary NAS';        URL = 'https://nas-primary.example.com/' }
        @{ Device = 'nas-dr';        Name = 'DR NAS';             URL = 'https://nas-dr.example.com/' }
    )

    # Subnet-to-location map used by the ping report to populate the Device Location column.
    # Each entry: Pattern (wildcard) -> Location name.
    # Evaluated top-to-bottom; first match wins.
    Subnets     = @(
        @{ Pattern = '192.0.2.*'; Location = 'Primary Site' }
        @{ Pattern = '198.51.100.*'; Location = 'Secondary Site' }
        @{ Pattern = '203.0.113.*'; Location = 'Cloud Network' }
    )

    # Example printers
    Printers    = @(
        @{ Device = '198.51.100.20'; Name = 'Printer A'; URL = 'https://198.51.100.20/' }
        @{ Device = '198.51.100.21'; Name = 'Printer B'; URL = 'https://198.51.100.21/' }
        @{ Device = '198.51.100.22'; Name = 'Printer C'; URL = 'https://198.51.100.22/' }
        @{ Device = '198.51.100.23'; Name = 'Printer D'; URL = 'https://198.51.100.23/' }
    )
}

#
# sites.psd1
# Defines the websites whose availability is tested in the morning report.
# Add, remove or edit entries as required.
#
@{
    # Internal example sites
    CoreSites = @(
        @{ URL = 'https://intranet.example.com/';      Name = 'Intranet' }
        @{ URL = 'https://portal.example.com/';        Name = 'Operations Portal' }
        @{ URL = 'https://workstation.example.com/';   Name = 'Workstation' }
    )

    # Third-party SaaS and vendor portals
    ThirdPartySites = @(
        @{ URL = 'https://adminconsole.adobe.com/';                   Name = 'Adobe' }
        @{ URL = 'https://www.logicmonitor.com/';                     Name = 'LogicMonitor' }
        @{ URL = 'https://account.brivo.com/';                        Name = 'Brivo' }
        @{ URL = 'https://www.dubber.net/';                           Name = 'Dubber' }
        @{ URL = 'https://admin.duosecurity.com/';                    Name = 'DUO' }
        @{ URL = 'https://www.dynamosoftware.com/';                   Name = 'Dynamo' }
        @{ URL = 'https://www.esentire.com/';                         Name = 'eSentire' }
        @{ URL = 'https://www.globalrelay.com/';                      Name = 'Global Relay' }
        @{ URL = 'https://dcc.godaddy.com/';                          Name = 'GoDaddy' }
        @{ URL = 'https://www.proofpoint.com/';                       Name = 'Proofpoint' }
        @{ URL = 'https://example.sharepoint.com/';                   Name = 'SharePoint' }
        @{ URL = 'https://www.sumologic.com/';                        Name = 'Sumo Logic' }
        @{ URL = 'https://symphony.com/';                             Name = 'Symphony' }
        @{ URL = 'https://cloud.tenable.com/';                        Name = 'Tenable' }
        @{ URL = 'https://unifi.ui.com/';                             Name = 'UniFi OS' }
        @{ URL = 'https://zoom.us/';                                  Name = 'Zoom' }
    )
}

@{
    Scopes = @{
        Endpoint   = @{
            location = "EndpointDlpLocation"
            adaptive = "EndpointDlpAdaptiveScopes"
        }
        ThirdParty = @{
            location = "ThirdPartyAppDlpLocation"
        }
        SharePoint = @{
            location = "SharePointLocation"
            adaptive = "SharePointAdaptiveScopes"
        }
        PowerBI    = @{
            location = "PowerBIDlpLocation"
        }
        Teams      = @{
            location = "TeamsLocation"
            adaptive = "TeamsAdaptiveScopes"
        }
        OneDrive   = @{
            location = "OneDriveLocation"
            adaptive = "OneDriveAdaptiveScopes"
            sharedby = "OneDriveSharedBy"
        }
        Exchange   = @{
            location = "ExchangeLocation"
            adaptive = "ExchangeAdaptiveScopes"
            memberof = "ExchangeSenderMemberOf"
        }
    }
    Mode   = @{
        enable  = "Enable"
        disable = "Enable"
        audit   = "TestWithNotifications"
        silent  = "TestWithoutNotifications"
    }
}
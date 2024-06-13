@{
    Build         = @{
        InputPath  = "..\config\rules\*.yml"
        OutputPath = "build-output\rules\"
    }
    SubConditions = @{
        extension    = "ContentExtensionMatchesWords"
        scancomplete = "ProcessingLimitExceeded"
        messagetype  = "MessageTypeMatches"
        email        = @{
            subject       = @{
                contains = "SubjectContainsWords"
                matches  = "SubjectMatchesPatterns"
            }
            subjectorbody = @{
                contains = "SubjectOrBodyContainsWords" 
                matches  = "SubjectOrBodyMatchesPatterns"
            }
            from          = @{
                contains = "FromAddressContainsWords"
                matches  = "FromAddressMatchesPatterns"
                domain   = "SenderDomainIs"
            }
            to            = @{
                contains = "AnyOfRecipientAddressContainsWords" 
                matches  = "AnyOfRecipientAddressMatchesPatterns"
                domain   = "RecipientDomainIs"
            }
        }
        content      = "ContentContainsSensitiveInformation"       
    }
    Actions       = @{
        notify   = "NotifyUser"
        generate = @{
            alert   = "GenerateAlert"
            report  = "GenerateIncidentReport"
            content = "IncidentReportContent"
        }
    }
    Mode          = @{
        enable  = "Enable"
        disable = "Enable"
        audit   = "TestWithNotifications"
        silent  = "TestWithoutNotifications"
    }
}
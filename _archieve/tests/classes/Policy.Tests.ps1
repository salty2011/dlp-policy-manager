# Save this as Policy.Tests.ps1

BeforeAll {
    # Dot-source the PS1 file containing the Policy class
    . dlp-policy-manager\classes\Policy.ps1
}

Describe "Policy Class Tests" {
    Context "Policy Creation" {
        It "Should create a valid Policy object" {
            $validData = @{
                Name = "TestPolicy"
                Description = "A test policy"
                Mode = "audit"
                Include = @{exchange = @{location = "all"}}
                Exclude = @{}
                SplitByType = $false
            }
            $policy = [Policy]::new($validData)
            $policy.Name | Should -Be "TestPolicy"
            $policy.Mode | Should -Be "audit"
            $policy.Include.Keys | Should -Contain "exchange"
        }

        It "Should throw an error for missing name" {
            $invalidData = @{
                Description = "A test policy"
                Mode = "audit"
                Include = @{exchange = @{location = "all"}}
            }
            { [Policy]::new($invalidData) } | Should -Throw "Policy name is required"
        }

        It "Should throw an error for invalid mode" {
            $invalidData = @{
                Name = "TestPolicy"
                Mode = "invalid"
                Include = @{exchange = @{location = "all"}}
            }
            { [Policy]::new($invalidData) } | Should -Throw "Invalid mode 'invalid'. Valid modes are: enable, disable, audit, silent"
        }

        It "Should throw an error for invalid location" {
            $invalidData = @{
                Name = "TestPolicy"
                Mode = "audit"
                Include = @{invalidLocation = @{location = "all"}}
            }
            { [Policy]::new($invalidData) } | Should -Throw "Invalid location 'invalidLocation' in policy"
        }
    }

    Context "Policy Properties" {
        BeforeAll {
            $validData = @{
                Name = "TestPolicy"
                Description = "A test policy"
                Mode = "audit"
                Include = @{exchange = @{location = "all"}}
                Exclude = @{sharepoint = @{location = "site1"}}
                SplitByType = $true
            }
            $policy = [Policy]::new($validData)
        }

        It "Should have correct Name" {
            $policy.Name | Should -Be "TestPolicy"
        }

        It "Should have correct Description" {
            $policy.Description | Should -Be "A test policy"
        }

        It "Should have correct Mode" {
            $policy.Mode | Should -Be "audit"
        }

        It "Should have correct Include" {
            $policy.Include.Keys | Should -Contain "exchange"
            $policy.Include.exchange.location | Should -Be "all"
        }

        It "Should have correct Exclude" {
            $policy.Exclude.Keys | Should -Contain "sharepoint"
            $policy.Exclude.sharepoint.location | Should -Be "site1"
        }

        It "Should have correct SplitByType" {
            $policy.SplitByType | Should -BeTrue
        }
    }
}
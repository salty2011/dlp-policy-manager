BeforeDiscovery {
    $ModuleName = 'DLP Policy Manager'
    $PathToManifest = [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Import-Module $PathToManifest -Force
}

InModuleScope 'DLP Policy Manager' {
    Describe "Convert-HashtableToArray" {
        BeforeAll {
            # Mock Write-Error to capture error messages
            Mock Write-Error { }
        }

        Context "Function Behavior" {
            It "Should exist as a function" {
                { Get-Command -Name Convert-HashtableToArray -ErrorAction Stop } | Should -Not -Throw
            }

            It "Should convert a simple hashtable to a custom object array" {
                $hashtableList = @(
                    @{Name = 'Rule1'; Policy = 'Policy1'; BlockAccess = $true}
                )

                $result = Convert-HashtableToArray -HashtableList $hashtableList

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be 'Rule1'
                $result[0].Policy | Should -Be 'Policy1'
                $result[0].BlockAccess | Should -BeTrue
            }

            It "Should handle multiple hashtables in the input array" {
                $hashtableList = @(
                    @{Name = 'Rule1'; Policy = 'Policy1'; BlockAccess = $true},
                    @{Name = 'Rule2'; Policy = 'Policy2'; BlockAccess = $false}
                )

                $result = Convert-HashtableToArray -HashtableList $hashtableList

                $result.Count | Should -Be 2
                $result[0].Name | Should -Be 'Rule1'
                $result[1].Name | Should -Be 'Rule2'
                $result[1].BlockAccess | Should -BeFalse
            }

            It "Should handle empty hashtables" {
                $hashtableList = @(@{})

                $result = Convert-HashtableToArray -HashtableList $hashtableList

                $result | Should -Not -BeNullOrEmpty
                $result.Count | Should -Be 1
                $result[0].PSObject.Properties.Count | Should -Be 0
            }

            It "Should handle pipeline input" {
                $hashtable1 = @{Name = 'Rule1'; Policy = 'Policy1'}
                $hashtable2 = @{Name = 'Rule2'; Policy = 'Policy2'}

                $result = @($hashtable1, $hashtable2) | Convert-HashtableToArray

                $result.Count | Should -Be 2
                $result[0].Name | Should -Be 'Rule1'
                $result[1].Name | Should -Be 'Rule2'
            }

            It "Should handle null values in hashtable" {
                $hashtableList = @(
                    @{Name = 'Rule1'; Policy = $null; BlockAccess = $true}
                )

                $result = Convert-HashtableToArray -HashtableList $hashtableList

                $result[0].Name | Should -Be 'Rule1'
                $result[0].Policy | Should -BeNullOrEmpty
                $result[0].BlockAccess | Should -BeTrue
            }
        }

        Context "Error Handling" {
            It "Should handle invalid input gracefully" {
                $invalidInput = "Not a hashtable"

                $result = Convert-HashtableToArray -HashtableList $invalidInput

                Should -Invoke Write-Error -Times 1
                $result | Should -BeNullOrEmpty
            }

            It "Should return empty array for empty input" {
                $result = Convert-HashtableToArray -HashtableList @()

                $result | Should -BeNullOrEmpty
            }
        }

        Context "Output Type" {
            It "Should return an array of PSCustomObject" {
                $hashtableList = @(
                    @{Name = 'Rule1'; Policy = 'Policy1'}
                )

                $result = Convert-HashtableToArray -HashtableList $hashtableList

                $result | Should -BeOfType [PSCustomObject]
            }
        }
    }
}
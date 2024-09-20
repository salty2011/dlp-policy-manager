# Test-ModuleRequirements.Tests.ps1

BeforeDiscovery {
    $ModuleName = 'DLP Policy Manager'
    $PathToManifest = [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', $ModuleName, "$ModuleName.psd1")
    Import-Module $PathToManifest -Force
}

InModuleScope 'DLP Policy Manager' {
    Describe "Test-ModuleRequirements" {
        BeforeAll {
            # Mock Get-Module to return specific versions for our tests
            Mock Get-Module -MockWith {
                param($Name)
                switch ($Name) {
                    'ExactModule' { return @{ Version = [Version]'1.0.0' } }
                    'GreaterModule' { return @{ Version = [Version]'2.1.0' } }
                    'LesserModule' { return @{ Version = [Version]'1.5.0' } }
                    Default { return $null }
                }
            }

            # Mock Write-Warning to capture warnings
            Mock Write-Warning { }
            Mock Write-Verbose { }
        }

        It "Function exists" {
            { Get-Command -Name Test-ModuleRequirements -ErrorAction Stop } | Should -Not -Throw
        }

        It "Can be called without throwing an error" {
            $tempFile = New-TemporaryFile
            Set-Content -Path $tempFile -Value "TestModule=1.0.0"
            { Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName } | Should -Not -Throw
            Remove-Item -Path $tempFile -Force
        }

        Context "Operator tests" {
            BeforeEach {
                $tempFile = New-TemporaryFile
                Mock Write-Warning { }
            }

            AfterEach {
                Remove-Item -Path $tempFile -Force
            }

            It "Correctly identifies an exact version match" {
                Set-Content -Path $tempFile -Value "ExactModule=1.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }

            It "Correctly identifies when a module is greater than or equal to required version" {
                Set-Content -Path $tempFile -Value "GreaterModule>=2.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }

            It "Correctly identifies when a module is less than or equal to required version" {
                Set-Content -Path $tempFile -Value "LesserModule<=2.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 0
            }

            It "Correctly identifies when a module doesn't meet the exact version requirement" {
                Set-Content -Path $tempFile -Value "ExactModule=2.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -like "*ExactModule with version = 2.0.0 is not installed.*"
                }
            }

            It "Correctly identifies when a module doesn't meet the greater than or equal requirement" {
                Set-Content -Path $tempFile -Value "GreaterModule>=3.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -like "*GreaterModule with version >= 3.0.0 is not installed.*"
                }
            }

            It "Correctly identifies when a module doesn't meet the less than or equal requirement" {
                Set-Content -Path $tempFile -Value "LesserModule<=1.0.0"
                $result = Test-ModuleRequirements -RequirementsFilePath $tempFile.FullName
                $result | Should -BeNullOrEmpty
                Should -Invoke Write-Warning -Times 1 -ParameterFilter {
                    $Message -like "*LesserModule with version <= 1.0.0 is not installed.*"
                }
            }
        }
    }
}
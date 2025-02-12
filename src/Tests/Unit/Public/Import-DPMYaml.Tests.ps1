BeforeDiscovery {
    $ModuleName = 'DLP Policy Manager'
    $PathToManifest = [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', $ModuleName, "$ModuleName.psd1")

    # Check and import required modules
    if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
        throw "The required module 'powershell-yaml' is not installed. Please install it using: Install-Module powershell-yaml -Scope CurrentUser"
    }
    Import-Module powershell-yaml -Force
    Import-Module $PathToManifest -Force
}

InModuleScope 'DLP Policy Manager' {
    Describe "Import-DPMYaml" {
        BeforeAll {
            # Create a temporary test directory
            $script:TestPath = Join-Path -Path $TestDrive -ChildPath 'YamlTests'
            New-Item -Path $script:TestPath -ItemType Directory -Force

            # Mock ConvertFrom-Yaml function with debugging
            Mock ConvertFrom-Yaml {
                Write-Host "Mock ConvertFrom-Yaml called with parameters:"
                $PSBoundParameters.Keys | ForEach-Object {
                    Write-Host "  $_ = $($PSBoundParameters[$_])"
                }
                Write-Host "Pipeline input: $input"

                # Return a hashtable that matches the actual YAML structure
                return @{
                    Policies = @(
                        @{
                            name = "Core PII - Exchange"
                            description = "DLP Policy for detection of PII data"
                            mode = "enable"
                            locations = @{
                                Exchange = @{
                                    Type = "All"
                                }
                            }
                            'split-by-type' = $false
                            priority = 1
                            rules = @("Credit Card Number", "PII")
                        }
                    )
                }
            } -ParameterFilter {
                Write-Host "ParameterFilter evaluated with args: $args"
                $true
            }

            # Create a test YAML file
            $TestYamlContent = @'
policies:
  - name: Core PII - Exchange
    description: DLP Policy for detection of PII data
    mode: enable
    locations:
      Exchange:
        Type: "All"
    split-by-type: false
    priority: 1
    rules:
      - "Credit Card Number"
      - "PII"
'@
            $TestYamlPath = Join-Path -Path $script:TestPath -ChildPath 'policy1.yml'
            Set-Content -Path $TestYamlPath -Value $TestYamlContent

            # Mock New-DPMDLPPolicy function
            Mock New-DPMDLPPolicy {
                param($PolicyData)
                return $PolicyData
            }

            # Mock Write-Verbose to avoid cluttering test output
            Mock Write-Verbose { }
            Mock Write-Warning { }
        }

        Context "Parameter validation" {
            It "Should throw when path doesn't exist" {
                { Import-DPMYaml -Path "NonExistentPath" } |
                Should -Throw "Cannot validate argument on parameter 'Path'. Path 'NonExistentPath' does not exist or is not a directory."
            }

            It "Should accept valid ImportType values" {
                { Import-DPMYaml -Path $script:TestPath -ImportType 'Policies' } |
                Should -Not -Throw
            }
        }

        Context "YAML file processing" {
            It "Should successfully import policies from YAML" {
                $result = Import-DPMYaml -Path $script:TestPath -ImportType 'Policies'

                # First verify $result itself isn't null
                $result | Should -Not -BeNullOrEmpty

                # Output the actual content for debugging
                Write-Host "Result content: $($result | ConvertTo-Json -Depth 10)"

                # Check if Policies exists as a key (for hashtable) or property
                ($result.Keys -contains 'Policies' -or $result.PSObject.Properties.Name -contains 'Policies') | Should -BeTrue

                # Then check the Policies content
                $result.Policies | Should -Not -BeNullOrEmpty
                $result.Policies.Count | Should -Be 1

                $policy = $result.Policies[0]
                $policy.name | Should -Be "Core PII - Exchange"
                $policy.description | Should -Be "DLP Policy for detection of PII data"
                $policy.mode | Should -Be "enable"
                $policy.priority | Should -Be 1
                $policy.rules | Should -Contain "Credit Card Number"
                $policy.rules | Should -Contain "PII"
            }

            It "Should handle empty YAML files" {
                $emptyFilePath = Join-Path -Path $script:TestPath -ChildPath 'empty.yml'
                Set-Content -Path $emptyFilePath -Value ""

                $result = Import-DPMYaml -Path $script:TestPath -ImportType 'Policies'
                Should -Invoke Write-Warning -ParameterFilter {
                    $Message -like "*is empty*"
                }
            }

            It "Should return empty arrays for non-requested import types" {
                $result = Import-DPMYaml -Path $script:TestPath -ImportType 'Rules'

                $result.Rules | Should -BeNullOrEmpty
                $result.Policies | Should -BeNullOrEmpty
                $result.Labels | Should -BeNullOrEmpty
            }

            It "Should process all supported file extensions" {
                # Create a .yaml file with the same content
                $yamlFilePath = Join-Path -Path $script:TestPath -ChildPath 'policy1.yaml'
                Set-Content -Path $yamlFilePath -Value $TestYamlContent

                $result = Import-DPMYaml -Path $script:TestPath -ImportType 'Policies'
                $result.Policies.Count | Should -Be 2  # Should find both .yml and .yaml files
            }
        }

        AfterAll {
            # Cleanup
            Remove-Item -Path $script:TestPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
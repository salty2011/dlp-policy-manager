Describe 'Test-DPMPolicySyntax' {
    BeforeAll {
        # Define the function here or dot-source it from your script file
        . .\dlp-policy-manager\internal\functions\policy\Test-DPMPolicySyntax.ps1

        # Helper function to create temporary YAML files for testing
        function New-TestYamlFile {
            param (
                [string]$Content,
                [string]$TestName
            )
            $tempDir = [System.IO.Path]::GetTempPath()
            $fileName = "test_policy_${TestName}_$(Get-Random).yaml"
            $tempPath = Join-Path $tempDir $fileName
            Set-Content -Path $tempPath -Value $Content
            return $tempPath
        }
    }

    AfterAll {
        # Clean up any remaining test files
        Get-ChildItem -Path $env:TEMP -Filter "test_policy_*.yaml" | Remove-Item -Force
    }

    Context 'Valid Policy' {
        It 'Should return valid for a correct policy' {
            $validYaml = @"
policy:
  - name: TestPol3
    description: Testing creation via code
    mode: audit
    include:
      exchange:
        location: all
    split-by-type: false
"@
            $tempFile = New-TestYamlFile -Content $validYaml
            $result = Test-DPMPolicySyntax -FilePaths $tempFile
            $result.IsValid | Should -Be $true
            $result.Locations | Should -Contain 'exchange'
            $result.Locations | Should -Contain 'exchange.location:all'
            Remove-Item $tempFile
        }
    }

    Context 'Invalid Policies' {
        It 'Should detect invalid mode' {
            $invalidModeYaml = @"
policy:
  - name: TestPol3
    description: Testing creation via code
    mode: invalid_mode
    include:
      exchange:
        location: all
    split-by-type: false
"@
            $tempFile = New-TestYamlFile -Content $invalidModeYaml
            $result = Test-DPMPolicySyntax -FilePaths $tempFile
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Invalid mode: invalid_mode. Valid modes are: enable, disable, audit, silent"
            Remove-Item $tempFile
        }

        It 'Should detect invalid split-by-type' {
          $invalidSplitYaml = @"
policy:
- name: TestPol3
  description: Testing creation via code
  mode: audit
  include:
    exchange:
      location: all
  split-by-type: not_a_boolean
"@
          $tempFile = New-TestYamlFile -Content $invalidSplitYaml -TestName 'InvalidSplit'
          $result = Test-DPMPolicySyntax -FilePaths $tempFile
          $result.IsValid | Should -Be $false
          $result.Errors | Should -Contain "Invalid split-by-type value: not_a_boolean. Must be true or false"
          Remove-Item $tempFile
      }

      It 'Should accept valid boolean for split-by-type' {
          $validSplitYaml = @"
policy:
- name: TestPol3
  description: Testing creation via code
  mode: audit
  include:
    exchange:
      location: all
  split-by-type: true
"@
          $tempFile = New-TestYamlFile -Content $validSplitYaml -TestName 'ValidSplit'
          $result = Test-DPMPolicySyntax -FilePaths $tempFile
          $result.IsValid | Should -Be $true
          $result.Errors | Should -Not -Contain "Invalid split-by-type value: true. Must be true or false"
          Remove-Item $tempFile
      }

        It 'Should detect invalid locations' {
            $invalidLocationsYaml = @"
policy:
  - name: TestPol3
    description: Testing creation via code
    mode: audit
    include:
      invalid_location:
        location: all
    split-by-type: false
"@
            $tempFile = New-TestYamlFile -Content $invalidLocationsYaml
            $result = Test-DPMPolicySyntax -FilePaths $tempFile
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Invalid locations in 'include'"
            Remove-Item $tempFile
        }

        It 'Should detect missing required keys' {
            $missingKeysYaml = @"
policy:
  - name: TestPol3
    description: Testing creation via code
"@
            $tempFile = New-TestYamlFile -Content $missingKeysYaml
            $result = Test-DPMPolicySyntax -FilePaths $tempFile
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Missing 'mode' key"
            $result.Errors | Should -Contain "Missing 'include' key"
            $result.Errors | Should -Contain "Missing 'split-by-type' key"
            Remove-Item $tempFile
        }
    }

    Context 'Multiple Policies' {
        It 'Should correctly process multiple policies in a file' {
            $multiPolicyYaml = @"
policy:
  - name: ValidPolicy
    description: This policy is valid
    mode: audit
    include:
      exchange:
        location: all
    split-by-type: false
  - name: InvalidPolicy
    description: This policy has an invalid mode
    mode: invalid_mode
    include:
      exchange:
        location: all
    split-by-type: true
"@
            $tempFile = New-TestYamlFile -Content $multiPolicyYaml
            $results = Test-DPMPolicySyntax -FilePaths $tempFile
            $results.Count | Should -Be 2
            $results[0].IsValid | Should -Be $true
            $results[1].IsValid | Should -Be $false
            $results[1].Errors | Should -Contain "Invalid mode: invalid_mode. Valid modes are: enable, disable, audit, silent"
            Remove-Item $tempFile
        }
    }

    Context 'File Handling' {
        It 'Should handle non-existent files' {
            $nonExistentFile = "C:\path\to\non\existent\file.yaml"
            $result = Test-DPMPolicySyntax -FilePaths $nonExistentFile
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Failed to read or parse file"
        }

        It 'Should handle invalid YAML content' {
            $invalidYaml = @"
This is not valid YAML content
  - just some random text
    with improper indentation
"@
            $tempFile = New-TestYamlFile -Content $invalidYaml
            $result = Test-DPMPolicySyntax -FilePaths $tempFile
            $result.IsValid | Should -Be $false
            $result.Errors | Should -Contain "Failed to read or parse file"
            Remove-Item $tempFile
        }
    }
}
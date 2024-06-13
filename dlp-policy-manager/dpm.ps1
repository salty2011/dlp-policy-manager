foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/scripts" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

$dpm_policy_config = Import-LocalizedData -BaseDirectory "$PSScriptRoot/internal/" -FileName "policy.config.psd1"
$dpm_rule_config = Import-LocalizedData -BaseDirectory "$PSScriptRoot/internal/" -FileName "rule.config.psd1"
using module .\classes\DLPClass.psm1

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/functions" -Filter *.ps1 -Recurse) {
    . $file.FullName
}

foreach ($file in Get-ChildItem -Path "$PSScriptRoot/internal/scripts" -Filter *.ps1 -Recurse) {
    . $file.FullName
}



#Initialize dpm global varaibles
$policies = @()
$rules = @()
$classifiers = @()

#Initialize dpm configurations
$template = [string](Get-Content "$PSScriptRoot/internal/templates/rule.template")
$dpm_policy_config = Import-LocalizedData -BaseDirectory "$PSScriptRoot/internal/" -FileName "policy.config.psd1"
$dpm_rule_config = Import-LocalizedData -BaseDirectory "$PSScriptRoot/internal/" -FileName "rule.config.psd1"

$typeAcceleratorsClass = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
$existingTypeAccelerators = $typeAcceleratorsClass::Get

$exportableTypes = @(
  [Policy]
)

foreach ($type in $exportableTypes) {
    # !! $TypeAcceleratorsClass::Add() quietly ignores attempts to redefine existing
    # !! accelerators with different target types, so we check explicitly.
    $existing = $existingTypeAccelerators[$type.FullName]
    if ($null -ne $existing -and $existing -ne $type) {
      throw "Unable to register type accelerator [$($type.FullName)], because it is already defined with a different type ([$existing])."
    }
    $typeAcceleratorsClass::Add($type.FullName, $type)
  }
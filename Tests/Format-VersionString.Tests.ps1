BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Version string is in correct format" {
    It "formats version in string when there are non-digit characters in it" {
        $test = Format-VersionString "19.2.1.ad"
        $test | Should -Be "19.2.1.0"

        $test = Format-VersionString "19.2.1. "
        $test | Should -Be "19.2.1.0"

        $test = Format-VersionString "21.1-alpha"
        $test | Should -Be "21.1.0"
    }
    It "does not format version in string when there are only digit characters in it" {
        $test = Format-VersionString "19.2.1"
        $test | Should -Be "19.2.1"
    }
}
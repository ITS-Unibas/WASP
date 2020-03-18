$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Version string is in correct format" {
    It "formats version in string when there are non-digit characters in it" {
        $test = Format-VersionString "19.2.1.ad"
        $test | Should be "19.2.1.0"

        $test = Format-VersionString "19.2.1. "
        $test | Should be "19.2.1.0"
    }
    It "does not format version in string when there are only digit characters in it" {
        $test = Format-VersionString "19.2.1"
        $test | Should be "19.2.1"
    }
}
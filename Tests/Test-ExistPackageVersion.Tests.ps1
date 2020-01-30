$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}
Describe "Package version existence" {

    $Repository = "repo"
    $Package = "package"
    $Version = "1.0.0"
    $Branch = "package@1.0.0"

    It "tests if package with a given version and git branch exists in given git repository" {
        Mock Invoke-GetRequest {Throw 'url not found error'}

        $test = Test-ExistPackageVersion $Repository $Package $Version $Branch
        $test | Should be $false
    }

    It "tests if package with a given version and git branch exists in given git repository" {
        Mock Invoke-GetRequest { return '{some json}'}

        $test = Test-ExistPackageVersion $Repository $Package $Version $Branch
        $test | Should be $true
    }
}
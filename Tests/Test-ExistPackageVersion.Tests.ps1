BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Package version existence" {
    BeforeAll {
        $Repository = "repo"
        $Package = "package"
        $Version = "1.0.0"
        $Branch = "package@1.0.0"

        Mock Write-Log { }
    }
    It "tests if package with a given version and git branch exists in given git repository" {
        Mock Invoke-GetRequest { Throw 'url not found error' }

        $test = Test-ExistPackageVersion $Repository $Package $Version $Branch
        $test | Should -Be $false
    }

    It "tests if package with a given version and git branch exists in given git repository" {
        Mock Invoke-GetRequest { return '{some json}' }

        $test = Test-ExistPackageVersion $Repository $Package $Version $Branch
        $test | Should -Be $true
    }
}
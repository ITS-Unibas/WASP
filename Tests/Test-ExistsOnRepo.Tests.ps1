$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}
Describe "Package exists on repo" {

    $Repository = "Dev"
    $Package = "package"
    $Version = "1.0.0"
    $ValidAnswer = [PSCustomObject]@{
        items = @([PSCustomObject]@{
            name = "msedge"
        })
    }
    $EmptyAnswer = [PSCustomObject]@{
        items = @()
    }

    Mock Write-Log { }

    It "tests if package with a given version and exists on repo, should be false if an error is thrown" {
        Mock Invoke-RestMethod { Throw 'url not found error' }

        $test = Test-ExistsOnRepo $Package $Version $Repository
        $test | Should be $false
    }

    It "tests if package with a given version and exists on repo, should be false if not exists" {
        Mock Invoke-RestMethod { $EmptyAnswer }

        $test = Test-ExistsOnRepo $Package $Version $Repository
        $test | Should be $false
    }

    It "tests if package with a given version and exists on repo, should be true if exists" {
        Mock Invoke-RestMethod { return $ValidAnswer }

        $test = Test-ExistsOnRepo $Package $Version $Repository
        $test | Should be $true
    }
}
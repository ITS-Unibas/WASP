$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}
Describe "Package exists on repo" {

    $Repository = "Dev"
    $Hash = "b0354ce98bc98de17aec6c61891c7fefe7a5eabe81924560fc6e02283c922cd30ad7b21d6197706a9756dbbd856351879982af4c01f832b2237b1fe17843c194"
    $ValidAnswer = [PSCustomObject]@{
        items = @([PSCustomObject]@{
                name = "msedge"
            })
    }
    $EmptyAnswer = [PSCustomObject]@{
        items = @()
    }

    Mock Write-Log { }

    It "tests if package with a given hash exists on repo, should be false if an error is thrown" {
        Mock Invoke-RestMethod { Throw 'url not found error' }

        $test = Test-ExistsOnRepo $Hash  $Repository
        $test | Should be $false
    }

    It "tests if package with a given hash exists on repo, should be false if not exists" {
        Mock Invoke-RestMethod { $EmptyAnswer }

        $test = Test-ExistsOnRepo $Hash $Repository
        $test | Should be $false
    }

    It "tests if package with a given hash exists on repo, should be true if exists" {
        Mock Invoke-RestMethod { return $ValidAnswer }

        $test = Test-ExistsOnRepo $Hash $Repository
        $test | Should be $true
    }
}
BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Removing remote branch" {
    BeforeAll {
        $config = '{
            "Application": {
                "GitProject": "csswcs",
                "GitBaseUrl": "https://git.its.unibas.ch"
            }
        }'
        Mock Read-ConfigFile { return ConvertFrom-Json $config }
        Mock Write-Log { }
        Mock Invoke-DeleteRequest { }

        $repo = 'repo'
        $branch = 'branch-1'
    }

    It "Finds branch in remote repository branches" {
        Mock Get-RemoteBranches { return @('branch-1', 'branch-2') }
        Remove-RemoteBranch $repo $branch
        Assert-MockCalled Invoke-DeleteRequest -Exactly 1 -Scope It
    }
    It "Does not find branch in remote repository branches" {
        Mock Get-RemoteBranches { return @('branch-0', 'branch-2') }
        Remove-RemoteBranch $repo $branch
        Assert-MockCalled Invoke-DeleteRequest -Exactly 0 -Scope It
    }
}
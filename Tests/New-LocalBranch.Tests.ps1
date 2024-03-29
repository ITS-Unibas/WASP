BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }
}

Describe "Creating new local git branch in repository" {

    BeforeEach {
        $RepoPath = 'an\arbitrary\path'
        $Branch = 'branch'
    }
    It "exists a repository and no branch" {
        Mock Write-Log { }
        Mock Test-Path { return $true }
        Mock git { return 'wrong-branch' }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled git -Exactly 1 -Scope It
        Assert-MockCalled Write-Log -Exactly 1 -Scope It
    }
    It "exists a repository and the local branch too" {
        Mock Write-Log { }
        Mock git { return 'branch' }
        Mock Test-Path { return $true }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled git -Exactly 1 -Scope It
        Assert-MockCalled Write-Log -Exactly 1 -Scope It
    }
    It "exists no repository at that path" {
        Mock Write-Log { }
        Mock Test-Path { return $false }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled Write-Log -Exactly 1 -Scope It
    }
}
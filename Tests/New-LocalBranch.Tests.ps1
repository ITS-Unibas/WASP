$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}
Describe "Creating new local git branch in repository" {

    $RepoPath = 'an\arbitrary\path'
    $Branch = 'branch'

    It "exists a repository and no branch" {
        Mock Write-Log { }
        Mock Test-Path { return $true }
        Mock git { return 'wrong-branch' }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled git -Exactly 1
        Assert-MockCalled Write-Log -Exactly 1
    }
    It "exists a repository and the local branch too" {
        Mock Write-Log { }
        Mock git { return 'branch' }
        Mock Test-Path { return $true }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled git -Exactly 2
        Assert-MockCalled Write-Log -Exactly 2
    }
    It "exists no repository at that path" {
        Mock Write-Log { }
        Mock Test-Path { return $false }
        New-LocalBranch $RepoPath $Branch
        Assert-MockCalled Write-Log -Exactly 3
    }
}
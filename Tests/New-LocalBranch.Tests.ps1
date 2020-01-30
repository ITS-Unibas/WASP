$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}
Describe "Creating new local git branch in repository" {

    $RepoPath = "an\arbitrary\path"
    $Branch = "branch"

    It "exists a repository and no branch" {

    }
    It "exists a repository and the local branch too" {

    }
    It "exists no repository at that path" {
        Moch Test-Path {return $false}
        New-LocalBranch $RepoPath $Branch
        
    }
}
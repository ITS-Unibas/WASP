function Remove-LocalBranches {
    <#
    .SYNOPSIS
        Delete local branches of a given repository as path
    .DESCRIPTION
        Deletes a local branch only of it is not contained in remote branches of the repository
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [string]
        $Repository
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $repository
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $RepositoryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        $remoteBranches = Get-RemoteBranches $Repository

        Set-Location $RepositoryPath
        Write-Log ([string] (git checkout $config.Application.GitBranchPROD 2>&1))
        Write-Log ([string] (git pull 2>&1))
        $localBranches = git branch
        ForEach ($local in $localBranches) {
            # TODO: Investigate what this does
            if ($local -match "\*") {
                # Skip currently checked out prod branch
                continue
            }
            if (-Not ($remoteBranches.Contains($local.Trim()))) {
                # local branch not anymore a remote branch, so it can be deleted locally
                Write-Log ([string] (git branch -D $local.Trim() 2>&1))
            }
        }
    }

    end {
    }
}
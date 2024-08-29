function Remove-LocalBranches {
    <#
    .SYNOPSIS
        Delete local branches of a given repository as path
    .DESCRIPTION
        Deletes local branches only of they are no longer in the remote repository
    .INPUTS
        $Repository: The repository to delete the local branches from
        $User: The user of the repository
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Repository,
		
		[Parameter(Mandatory = $true)]
        [string]
        $User
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $Repository
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $RepositoryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        $remoteBranches = Get-RemoteBranches -Repo $GitFolderName -User $User

        $localBranches = git -C $RepositoryPath branch

        ForEach ($local in $localBranches) {
            $localAsterixRemoved = $local -replace "\*", ""
            $localAsterixRemoved = $localAsterixRemoved.Trim()
            if (-Not ($remoteBranches.Contains($localAsterixRemoved))) {
                # local branch not anymore a remote branch, so it can be deleted locally
                Write-Log ([string] (git -C $RepositoryPath branch -D $localAsterixRemoved 2>&1)) -Severity 1
            }
        }
    }

    end {
    }
}
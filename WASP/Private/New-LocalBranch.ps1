function New-LocalBranch {
    <#
    .SYNOPSIS
        Creates a new local git branch
    .DESCRIPTION
        Creates a new local git branch with a given name in a given repository path when it does not yet exist.
    .PARAMETER Repository
        Repository which the branch should be created for
    .PARAMETER BranchName
        Name of the branch to be created
    .NOTES
        FileName: New-LocalBranch.ps1
        Author: Kevin Schaefer, Maximilian Burgert
        Contact: its-wcs-ma@unibas.ch
        Created: 2020-30-01
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $RepositoryPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BranchName
    )

    begin {
    }

    process {
        # Get all local branches in the repository path
        if (Test-Path $RepositoryPath) {
            $localBranches = (git -C $RepositoryPath branch)

            if ($localBranches -match $BranchName) {
                Write-Log "Local branch $branchName already exist. No new branch will be created."
                return
            }

            # Create an checkout new branch
            Write-Log ([string](git -C $RepositoryPath checkout -b $BranchName 2>&1))
        } else {
            Write-Log "Path to repository $ReopsitoryPath does not exist."
        }
    }

    end {

    }
}
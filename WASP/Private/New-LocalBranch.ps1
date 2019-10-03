function New-LocalBranch {
    <#
    .SYNOPSIS
        Creates a new local branch
    .DESCRIPTION
        Creates a new local branch with a given name for a given repository
    .PARAMETER Repository
        Repository which the branch should be created for
    .PARAMETER BranchName
        Define a branchname
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
        $localBranches = (git -C $RepositoryPath branch)

        if ($localBranches -match $BranchName) {
            Write-Log "Local branch $branchName already exist. No new branch will be created."
            return
        }

        Write-Log ([string](git -C $RepositoryPath checkout -b $BranchName 2>&1))
    }

    end {

    }
}
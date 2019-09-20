function Switch-GitBranch {
    <#
    .SYNOPSIS
        Function to switch to a given branch in a given path
    .DESCRIPTION
        Performs checkout of a given branch, checks whether the branch could be checked out and if so, pulls the branch.
    .EXAMPLE
        PS C:\> Switch-GitBranch new-feauture
        Performs checkout of the given branch, checks whether the branch could be checked out and if so, pulls the branch.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $path,

        [Parameter(Mandatory = $true)]
        [string]
        $branch
    )

    process {
        Write-Log ([string] (git -C $path checkout $branch 2>&1))

        # Check if we could checkout the correct branch
        if ((Get-CurrentBranchName -Path $path) -ne $branch) {
            Write-Log "Couldn't checkout $branch in $path. Make sure the location to the repository path was set and the branch does exist" -Severity 3
        }

        Write-Log ([string] (git pull 2>&1))
    }
}
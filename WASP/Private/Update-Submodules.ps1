function Update-Submodules {
    <#
    .SYNOPSIS
        Update submodules in a given repository path
    .DESCRIPTION
        Long description
    .INPUTS
        Path to repository
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryPath
    )

    begin {
    }

    process {
        # TODO: Find a better location for the reset elsewhere if necessary
        <#
        if (Test-Path $PackagesInboxFilteredPath) {
            Set-Location $PackagesInboxFilteredPath
            Write-Log ([string](git reset origin/HEAD --hard 2>&1))
        } #>
        if (Test-Path $RepositoryPath) {
            Set-Location $RepositoryPath
            # use update-git-for-windows instead of just update, since it is deprecated
            #Write-Log ([string](git submodule foreach 'git update-git-for-windows --yes' 2>&1))
            #This seems to work better?
            Write-Log ([string](git submodule update --remote --recursive 2>&1))
        }
        else {
            Write-Log "$RepositoryPath does not exist. Make sure to clone $RepositoryPath" -Severity 3
        }
    }

    end {
    }
}
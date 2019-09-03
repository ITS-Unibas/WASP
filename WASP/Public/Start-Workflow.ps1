function Start-Workflow {
    <#
    .SYNOPSIS
        This function initiates the workflow of automated packaging
    .DESCRIPTION
        TODO: Update description
        The update of the git repositories first removes all local and remote branches which have been handled.
        Then, it updates the whishlist by inserting the current package versions. To get the latest changes from
        the package source repositories, the submodules of the package inbox will be updated and then determined,
        which package will be moved to which of the git branches of the package gallery. The filtered package inbox
        is then updated.
    #>
    [CmdletBinding()]
    param (
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        Remove-LocalBranch
        Remove-HandledBranches
        # TODO: Rename repository
        # Update windows software repository
        Set-Location $PSScriptRoot
        Write-Log ([string] (git checkout master 2>&1))
        Write-Log ([string] (git pull 2>&1))

        # TODO: implement function
        Update-Submodules

        # Get all the packages which are to accept and further processed
        $list = Get-PackagesManual
        $list += Get-PackagesAutomatic

        Update-Wishlist

        Update-PackageInboxFiltered($list)
    }

    end {
    }
}
function Update-GitRepositories {
    <#
    .SYNOPSIS
        This function initiates an update of the several used git repositories.
    .DESCRIPTION
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
    }

    process {

    }

    end {
    }
}
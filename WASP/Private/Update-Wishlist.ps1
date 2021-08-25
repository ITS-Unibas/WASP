function Update-Wishlist {
    <#
    .SYNOPSIS
        Add and commit changes made to the wishlist in given repository
    .DESCRIPTION
        Add and commit changes made to the wishlist in given repository where the whishlist is directly located
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]
        $RepositoryPath,

        [parameter(Mandatory = $true)]
        [string]
        $Branch
    )

    begin {
        $wishlistPath = Join-Path -Path $RepositoryPath -ChildPath 'wishlist.txt'
    }

    process {
        Write-Log ([string] (git -C $RepositoryPath checkout $Branch 2>&1))
        Write-Log ([string] (git -C $RepositoryPath pull origin $Branch 2>&1))
        Write-Log ([string] (git -C $RepositoryPath add $wishlistPath 2>&1))
        Write-Log ([string] (git -C $RepositoryPath commit -m "Commits changes to wishlist" 2>&1))
        Write-Log ([string] (git -C $RepositoryPath push 2>&1))
    }

    end {
    }
}
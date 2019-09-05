function Update-Wishlist {
    <#
    .SYNOPSIS
        Add and commit changes made to the whitelist in given repository
    .DESCRIPTION
        Add and commit changes made to the whitelist in given repository where the whishlist is directly located
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]
        $RepositoryPath
    )

    begin {
        $wishlistPath = Join-Path -Path $RepositoryPath -ChildPath 'wishlist.txt'
    }

    process {
        Set-Location $PackageGalleryPath
        Switch-GitBranch $config.Application.GitBranchPROD
        Write-Log ([string] (git add $wishlistPath 2>&1))
        Write-Log ([string] (git commit -m "Automated push to commit changes to the wishlist" 2>&1))
        Write-Log ([string] (git push 2>&1))
    }

    end {
    }
}
function Update-Wishlist {
    <#
    .SYNOPSIS
        Add and commit changes made to the whitelist in package-gallery repository
    .DESCRIPTION
        Add and commit changes made to the whitelist in package-gallery repository
    #>
    [CmdletBinding()]
    param (

    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.WindowsSoftware
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $wishlistPath = Join-Path -Path $PackageGalleryPath -ChildPath 'wishlist.txt'
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
function Find-PackageInWishlist {
    <#
    .SYNOPSIS
        Takes a package name and searches for it in the wishlist. Returns true if found, false otherwise.
    .DESCRIPTION
        Find a package in the wishlist by its name.
    .NOTES
        FileName: Find-PackageInWishlist.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-10-16
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $packageName
    )

    begin {
        $config = Read-ConfigFile
        
        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $wishlistPath = Join-Path -Path  $PackagesWishlistPath -ChildPath "wishlist.txt"
        $wishlistContent =  Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }
    }

    process { 
        Write-Log "Searching for $packageName in wishlist..." -Severity 0
        $foundInWishlist = $false
        foreach ($line in $wishlistContent) {
            $line = $line -replace "@.*", ""
            if ($line -eq $packageName) {
                $foundInWishlist = $true
            }
        }
        if (!$foundInWishlist) {
            Write-Log "$packageName not found in wishlist." -Severity 0
            return $false
        } else {
            Write-Log "$packageName found in wishlist." -Severity 0
            return $true
        }
    }

    end {
    }
}
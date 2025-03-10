function Search-NewPackages {
    <#
    .SYNOPSIS
        Searches for new packages in a given path
    .DESCRIPTION
        Search if there is a new package in a git repository. If a new package
        is found, it will add the package to a given array list.
    #>
 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]
        $NewPackagesList,
 
        [Parameter(Mandatory)]
        [System.Object[]]
        $Packages,
 
        [Parameter()]
        [switch]
        $Manual
    )
    begin {
        $config = Read-ConfigFile
 
        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $wishlistPath = Join-Path -Path  $PackagesWishlistPath -ChildPath "wishlist.txt"
    }
 
    process {
        $wishlistContent = Get-Content -Path $wishlistPath | Select-String -Pattern "#" -NotMatch | ForEach-Object {$_ -replace "@.*", ""}
 
        foreach ($package in $Packages) {
            # Check if the package is in (not deactivated) wishlist. Only scan for packages that are relevant
            if (!(($package.Name) -in $wishlistContent)) {
                continue
            } else {
                if ($Manual) {
                    $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
                    $nuspec = Get-ChildItem -Path $latest.FullName -recurse | Where-Object { $_.Extension -like "*nuspec*" }
                } else {
                    $nuspec = Get-ChildItem -Path $package.FullName -recurse | Where-Object { $_.Extension -like "*nuspec*" }
                }
                if (-Not $nuspec -or $nuspec.GetType().ToString() -eq "System.Object[]") {
                    continue
                }
                try {
                    $version = ([xml](Get-Content -Path $nuspec.FullName)).Package.metadata.version
                }
                catch {
                    Write-Log "Error reading $($nuspec.FullName)" -Severity 3
                    Write-Log "$($_.Exception.Message)" -Severity 3
                    continue
                }
                $FoundPackages = Search-Wishlist $package $version -manual:$Manual
                 
                if ($FoundPackages) {
                    $null = $NewPackagesList.Add($FoundPackages)
                }   
            }
        }
 
        return , $NewPackagesList
    }  
}
function Search-Wishlist {
    <#
    .SYNOPSIS
        Search in the wishlist for a package Name
    .DESCRIPTION
        When the package name is found, the version will locally be added in this manner: "packageName@1.0.0.0"
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Name of the package and version of the package
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $packageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $packageVersion
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.PackagesWishlist
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesWishlistPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $wishlistPath = Join-Path -Path  $PackagesWishlistPath -ChildPath "wishlist.txt"

        $GitRepo = $config.Application.PackagesInboxFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInbxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $updatedPackages = New-Object System.Collections.ArrayList

        $NameAndVersionSeparator = $config.Application.WishlistSeperatorChar
    }

    process {
        $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }

        Foreach ($line in $wishlist) {
            if ($line -match "@") {
                $packageNameWhishlist, $previousVersion = $line.split($NameAndVersionSeparator)
            }
            else {
                $previousVersion = "0.0.0.0"
                $packageNameWhishlist = $line.Trim()
            }

            if ($packageName -like $packageNameWhishlist.Trim()) {

                try {
                    # Make Version parsable so we can compare with '-le'
                    if (-Not ($packageVersion -match "^(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)$")) {
                        Write-Log "The version $packageVersion / $previousVersion will not able to be parsed. Going to format it"
                        $packageVersion = Format-VersionString -VersionString $packageVersion
                        $previousVersion = Format-VersionString -VersionString $previousVersion
                        Write-Log "Formatted versions now $packageVersion / $previousVersion"
                    }

                    if (([version]$packageVersion) -le ([version]$previousVersion)) {
                        continue
                    }
                }
                catch [System.Management.Automation.RuntimeException] {
                    Write-Log "The version $packageVersion could not be parsed" -Severity 2
                }

                Write-Log "Copying $communityPackName $packageVersion." -Severity 1
                #Create directory structure if not existing
                $destPath = $PackagesInbxFilteredPath + "\" + $packageName + "\" + $packageVersion

                Copy-Item $package.FullName -Destination $destPath -Recurse -Force

                # Return list of destPaths
                $tmp = New-Object psobject @{'path' = $destPath; 'name' = $packageName; 'version' = $packageVersion }
                #$updatedPackages += , $tmp
                $null = $updatedPackages.Add($tmp)
            }
        }
    }

    end {
        return $updatedPackages
    }
}
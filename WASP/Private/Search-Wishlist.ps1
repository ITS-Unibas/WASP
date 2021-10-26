function Search-Wishlist {
    <#
    .SYNOPSIS
        Search in the wishlist for a package Name
    .DESCRIPTION
        When the package name is found, the version will locally be added in this manner: "packageName@1.0.0.0"
        Additionally, copies package to update into filtered inbox repository path.
        These changes will later be committed an pushed to git.
    .NOTES
        FileName: Search-Wishlist.ps1
        Author: Kevin Schaefer, Maximilian Burgert, Tim Königl
        Contact: its-wcs-ma@unibas.ch
        Created: 2020-20-02
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $packagePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $packageVersion,

        [Parameter()]
        [switch]
        $manual

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

        $NameAndVersionSeparator = $config.Application.WishlistSeperatorChar
    }

    process {
        try {
            $wishlist = Get-Content -Path $wishlistPath | Select-String -Pattern "#" -NotMatch
            $packageName = $packagePath.Name

            Foreach ($line in $wishlist) {
                if ($line -match "@") {
                    $packageNameWhishlist, $previousVersion = $line.Line.split($NameAndVersionSeparator)
                }
                else {
                    $previousVersion = "0.0.0.0"
                    $packageNameWhishlist = $line.ToString().Trim()
                }
                # Check if previousVersion is not empty
                if(-Not $previousVersion) {
                    Write-Log "$packageNameWhishlist has $NameAndVersionSeparator but no version is given. Handling it as if new package version" -Severity 2
                    $previousVersion = "0.0.0.0"
                }

                if ($packageName -like $packageNameWhishlist.Trim()) {
                    try {
                        # Make Version parsable so we can compare with '-le'
                        if (-Not ($packageVersion -match "^(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)$")) {
                            Write-Log "The version $packageVersion / $previousVersion for package $packageName cannot be parsed. Going to format it"
                            $packageVersion = Format-VersionString -VersionString $packageVersion
                            $previousVersion = Format-VersionString -VersionString $previousVersion
                            Write-Log "Formatted versions now $packageVersion / $previousVersion for package $packageName"
                        }

                        if (([version]$packageVersion) -le ([version]$previousVersion)) {
                            continue
                        }
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Log "The version $packageVersion could not be parsed" -Severity 2
                    }

                    #Create directory structure if not existing
                    # if ($manual) {
                    #     $destPath = Join-Path $PackagesInbxFilteredPath $packageName
                    # }
                    # else {
                    #     $destPath = Join-Path $PackagesInbxFilteredPath (Join-Path $packageName $packageVersion)
                    # }

                    $destPath = Join-Path $PackagesInbxFilteredPath (Join-Path $packageName $packageVersion)

                    try {
                        Write-Log "Copying $($packagePath.FullName) to $destPath"
                        if ($manual) {
                            $sourcePath = Join-Path $packagePath.FullName $packageVersion
                        }
                        else {
                            $sourcePath = $packagePath.FullName
                        }
                        Copy-Item $sourcePath -Destination $destPath -Recurse -Force
                    }
                    catch {
                        Write-Log "$($_.Exception)"
                    }

                    Write-Log "Found package to update: $packageName with version $packageVersion"

                    return New-Object psobject @{'path' = $destPath; 'name' = $packageName; 'version' = $packageVersion }
                }
            }
        }
        catch {
            Write-Log "$($_.Exception)"
        }
    }
}
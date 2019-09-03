function Get-PackagesAutomatic {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (

    )

    begin {
    }

    process {

        Write-Log "Start moving packages to filtered package inbox" -Severity 1
        $updatedPackages = @()

        $packagesCore = @(Get-ChildItem $communityRepoFolder)
        $packagesAutomatic = @(Get-ChildItem $automaticPackagesRepoFolder)
        $packagesCore += @(Get-ChildItem $openJDKRepoFolder)

        # Iterate over all community packages
        Foreach ($package in $packagesCore) {
            $updatedPackages += Search-Whitelist $package.Name $version
        }

        # TODO: Needs rework

        # Iterate over all automatic packages. All packages will be moved and written to the wishlist, plus an entry of the last copied version
        Foreach ($package in $packagesAutomatic) {
            $automaticPackName = $package.Name
            $copy = $True
            $versionChange = $False

            $nuspecVersion = (ExtractXMLValue $package.FullName "version")
            $latestVersion = 0

            Foreach ($line in $wishlist) {
                $origLine = $line

                if ($line -match "@") {
                    $line, $latestVersion = $line.split($nameAndVersionSeparator)
                }
                else {
                    continue
                }

                if ($automaticPackName -like $line) {
                    # There was already a move of this package, check if the version is new.
                    if ([version]$nuspecVersion -le [version]$latestVersion) {
                        $copy = $FalFse
                        break
                    }
                    else {
                        $versionChange = $True
                        break
                    }
                }
            }
            if ($copy -eq $True) {
                Write-Log "Found a new verison of the automatic package $automaticPackName." -Severity 1
                $destPath = $filteredFolderPath + "\" + $automaticPackName + "\" + $nuspecVersion
                $copyComm = Copy-Item $package.FullName -Destination $destPath -Recurse

                if ($versionChange -eq $True ) {
                    $setVersionChangeComm = (Get-Content -Path $wishlistPath) -replace ($automaticPackName + $nameAndVersionSeparator + $latestVersion), ($automaticPackName + $nameAndVersionSeparator + $nuspecVersion) | Set-Content $wishlistPath
                }
                else {
                    $addVersionComm = Add-Content $wishlistPath "$automaticPackName@$nuspecVersion"
                }

                $tmp = @{'path' = $destPath; 'name' = $automaticPackName; 'version' = $nuspecVersion }
                $updatedPackages += , $tmp
            }
        }

        Write-Log "Move community packages finished." -Severity 1
        return $updatedPackages
    }

    end {
    }
}
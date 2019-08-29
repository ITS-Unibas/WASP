function Move-Packages {
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
        Returns list of moved packages.
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (

    )

    begin {
        $config = Read-ConfigFile

        $wishlistPath = (Join-Path $PSScriptRoot ..\wishlist.txt)
        $filteredFolderPath = $env:PackagesFilteredRepoPath
        $manualSoftwareFolder = $env:PackagesManualRepoPath
        $communityRepoFolder = $env:ChocoCommunityRepoPath + "\automatic"
        $automaticPackagesRepoFolder = $env:PackagesAutomaticRepo + "\automatic"
        $openJDKRepoFolder = $env:OpenJDKRepo
        $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }
        $nameAndVersionSeparator = "@"
    }

    process {
        Write-Log "Start moving packages to filtered package inbox" -Severity 1
        $updatedPackages = @()

        $packagesCore = @(Get-ChildItem $communityRepoFolder)
        $packagesManual = @(Get-ChildItem $manualSoftwareFolder)
        $packagesAutomatic = @(Get-ChildItem $automaticPackagesRepoFolder)
        $packagesCore += @(Get-ChildItem $openJDKRepoFolder)
        # Iterate over all community packages
        Foreach ($package in $packagesCore) {
            $communityPackName = $package.Name
            Foreach ($line in $wishlist) {
                $origLine = $line
                if ($line -match "@") {
                    $line, $latestVersion = $line.split($nameAndVersionSeparator)
                }
                else {
                    $latestVersion = "0.0.0.0"
                }
                if ($communityPackName -like $line.Trim()) {
                    # This packages are on our wishlist and will be copied into our Cache
                    $version = (ExtractXMLValue $package.FullName "version")
                    if (-Not $version -or (([version]$version) -le ([version]$latestVersion.Trim()))) {
                        continue
                    }
                    Write-Log "Copying $communityPackName $version." -Severity 1
                    #Create directory structure if not existing
                    $destPath = $filteredFolderPath + "\" + $line + "\" + $version

                    Copy-Item $package.FullName -Destination $destPath -Recurse

                    $SetContentComm = (Get-Content -Path $wishlistPath) -replace $origLine, ($line + $nameAndVersionSeparator + $version) | Set-Content $wishlistPath
                    # Return list of destPaths
                    $tmp = @{'path' = $destPath; 'name' = $line; 'version' = $version }
                    $updatedPackages += , $tmp
                }
            }
        }
        # Iterate over all manual packages
        # TODO Adapt handling to folder structure of manual packages (The structure wanted at the moment is a folder for each software with subfolders for each version)
        Foreach ($package in $packagesManual) {
            $manualPackName = $package.Name
            $copy = $True
            $versionChange = $False
            Foreach ($line in $wishlist) {
                $origLine = $line
                if ($line -match "@") {
                    $line, $latestVersion = $line.split($nameAndVersionSeparator)
                }
                else {
                    continue
                }
                if ($manualPackName -match $line) {
                    # IMPORTANT: Getting latest version by creation date!
                    $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
                    if (-Not $latest) {
                        Write-Log "Manual package $manualPackName has no version folders. Please Check." -Severity 2
                        $copy = $False
                        break
                    }
                    if (([version]$latest.Name) -le ([version]$latestVersion)) {
                        $copy = $False
                        break
                    }
                    else {
                        $versionChange = $True
                        break
                    }
                }
            }
            if ($copy -eq $True) {
                $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
                $version = (ExtractXMLValue $latest.FullName "version")
                if ($version) {
                    Write-Log "Found a new verison of the manual package $manualPackName." -Severity 1
                    $destPath = $filteredFolderPath + "\" + $manualPackName + "\" + $version
                    $copyComm = Copy-Item $latest.FullName -Destination $destPath -Recurse

                    if ($versionChange -eq $True ) {
                        $setVersionChangeComm = (Get-Content -Path $wishlistPath) -replace ($manualPackName + $nameAndVersionSeparator + $latestVersion), ($manualPackName + $nameAndVersionSeparator + $version) | Set-Content $wishlistPath
                    }
                    else {
                        $addVersionComm = Add-Content $wishlistPath "$manualPackName@$version"
                    }

                    $tmp = @{'path' = $destPath; 'name' = $manualPackName; 'version' = $version }
                    $updatedPackages += , $tmp
                }
            }
        }

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
function Get-PackagesManual {
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
        $packagesManual = @(Get-ChildItem $manualSoftwareFolder)
    }

    process {

        # TODO: Needs rework. Especially the path to manual packages

        # Iterate over all manual packages
        # TODO: Adapt handling to folder structure of manual packages (The structure wanted at the moment is a folder for each software with subfolders for each version)
        Foreach ($package in $packagesManual) {
            $manualPackName = $package.Name
            $copy = $True
            $versionChange = $False

            $latest = Get-ChildItem -Path $package.FullName | Sort-Object CreationTime -Descending | Select-Object -First 1
            $version = (ExtractXMLValue $latest.FullName "version")

            $updatedPackages += Search-Whitelist $package.Name $version

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

            # TODO: Rework since Search-Whitelist is used

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

    }

    end {
    }
}
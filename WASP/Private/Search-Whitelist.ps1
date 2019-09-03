function Search-Whitelist {
    <#
    .SYNOPSIS
        Search in the whitelist for a package Name
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
        # Mandatory
        [string]
        $packageName,

        # Mandatorys
        [string]
        $version
    )

    begin {
        $config = Read-ConfigFile

        $wishlistPath = (Join-Path $PSScriptRoot ..\wishlist.txt)
        $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }

        $updatedPackages = @()
    }

    process {

        # TODO: The paths need to be updated here

        Foreach ($line in $wishlist) {
            $origLine = $line
            if ($line -match "@") {
                $line, $latestVersion = $line.split($nameAndVersionSeparator)
            }
            else {
                $latestVersion = "0.0.0.0"
            }
            if ($packageName -like $line.Trim()) {
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

    end {
        return $updatedPackages
    }
}
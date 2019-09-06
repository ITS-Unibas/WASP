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

        # Mandatory
        [string]
        $packageVersion
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInbxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $wishlistPath = Join-Path -Path  $PackagesInbxFilteredPath -ChildPath "wishlist.txt"

        $GitRepo = $config.Application.PackagesInboxFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInbxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $updatedPackages = @()
    }

    process {
        $wishlist = Get-Content -Path $wishlistPath | Where-Object { $_ -notlike "#*" }

        Foreach ($line in $wishlist) {
            $origLine = $line
            if ($line -match "@") {
                $packageNameWhitelist, $previousVersion = $line.split($nameAndVersionSeparator)
            }
            else {
                $previousVersion = "0.0.0.0"
            }

            if (([version]$packageVersion) -le ([version]$previousVersion)) {
                continue
            }

            if ($packageName -like $packageNameWhitelist.Trim()) {
                Write-Log "Copying $communityPackName $version." -Severity 1
                #Create directory structure if not existing
                $destPath = $PackagesInbxFilteredPath + "\" + $packageName + "\" + $packageVersion

                Copy-Item $package.FullName -Destination $destPath -Recurse

                $SetContentComm = (Get-Content -Path $wishlistPath) -replace $origLine, ($packageName + $nameAndVersionSeparator + $packageVersion) | Set-Content $wishlistPath
                # Return list of destPaths
                $tmp = @{'path' = $destPath; 'name' = $packageName; 'version' = $packageVersion }
                $updatedPackages += , $tmp
            }
        }
    }

    end {
        return $updatedPackages
    }
}
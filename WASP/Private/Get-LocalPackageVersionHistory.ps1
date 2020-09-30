function Get-LocalPackageVersionHistory {
    <#
    .SYNOPSIS
        Get a history list of subfolders to a given directory that are named as versions.
    .DESCRIPTION
        Get a history list of subfolders to a given directory that are named as versions. Orders the versions in descending order.
    .EXAMPLE
        PS C:\> Get-LocalPackageVersionHistory C:\ProgramData\Unibasel\wasp\PackageGallery\firefoxesr
        Lists all versions in descending order from subdirectory names for given directory
    .INPUTS
        Path to a package directory.
    .OUTPUTS
        List containing all versions found.
    .NOTES
        FileName: Get-LocalPackageVersionHistory
        Author: Kevin Schaefer, Maximilian Burgert
        Contact: its-wcs-ma@unibas.ch
        Created: 2020-09-29
        Updated: 2020-09-29
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $ParentSWDirectory
    )

    begin {

    }

    process {
        [string[]]$StringVersions = Get-ChildItem -Path $ParentSWDirectory -Directory | Select-Object -ExpandProperty Name
        if ($StringVersions.Length -gt 1) {
            $VersionList = New-Object System.Collections.ArrayList
            $StringVersionList = New-Object System.Collections.ArrayList
            $StringVersions | ForEach-Object {
                $SplitVersion = $_.Split('.')
                # Ensure to have minimum x.x or else ps is not able to cast
                if ($SplitVersion -gt 1) {
                    # Loop through each version part an remove any character which is not a number, so it can be casted.
                    for ($i = 0; $i -lt $SplitVersion.Length; $i++) {
                        $SplitVersion[$i] = $SplitVersion[$i] -replace "\D+"
                    }
                }
                $Version = $SplitVersion -join "."
                # need to cast it to a version or else the sorting will not
                # work correctly, like for chrome
                $null = $VersionList.Add([version]$Version)
                $null = $StringVersionList.Add($Version)
            }
            $VersionList.Sort()
            $VersionList.Reverse()
            Write-Log ("Previous version of package found: " +$StringVersionList[1]) -Severity 1
            return $VersionList, $StringVersionList
        }
    }

    end {

    }
}
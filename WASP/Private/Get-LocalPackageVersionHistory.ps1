function Get-LocalPackageVersionHistory {
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
                $null = $VersionList.Add($Version)
            }
            $VersionList.Sort()
            $VersionList.Reverse()
            Write-Log ("Previous version of package found: " + $VersionList[1]) -Severity 1
            return $VersionList
        }
    }

    end {

    }
}
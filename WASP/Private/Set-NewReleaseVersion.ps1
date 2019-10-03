function Set-NewReleaseVersion() {
    <#
    .SYNOPSIS
        Retrieves the package release version from the name and iterates it to the next version. It then sets the new release version in the nusepc file of a package.

    .DESCRIPTION
        This function gets the information if it is the first release of a package or not. If it is the first release it just appends the release 000 to the package version in the nupkg.
        If it is not the first version it retrieves the release version by extracting it out of the nuspec.

        The versions of chocolatey always have maximum 4 segments X.X.X.X. If the package which is versioned has 4 segments the release version is appended to the last segment (X.X.X.X000).
        If the number of segments is less than 4, a new segment is created for the release version (X.X.X.000).

    .PARAMETER firstReleaseVersion
        A boolean which indicates if this is the first time this package is versioned, the release version will be then 000

    .PARAMETER nuspecPath
        The absolute path to the nuspec file of the package

    .OUTPUTS
        This function does not output anything it just modifies the nuspec file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [boolean]
        $firstReleaseVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $nuspecPath
    )

    begin {
        $version = Get-NuspecXMLValue $nuspecPath "version"

    }

    process {
        # remove characters from a version
        if (-Not ($version -match "^(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)$")) {
            $versionSplit = $version.split(".")
            $versionList = New-Object System.Collections.ArrayList
            foreach($ver in $versionSplit) {
                if($ver -match "^(\d*)$") {
                    $null = $versionList.Add($ver)
                } else {
                    # prevent version malforming (hope so)
                    $null = $versionList.Add("0")
                }
            }
            $version = $versionList -join "."
        }

        $versionOld = $version

        $versionTag = "<version>" + $version + "</version>"
        $hasFourSegments = [regex]::Match($versionTag, "<version>(\w|\d)+\.(\w|\d)+\.(\w|\d)+\.(\w|\d)+<\/version>").Success

        if ($hasFourSegments -eq $true -or (($hasFourSegments -eq $false) -and ($firstReleaseVersion -eq $false))) {
            $versionSplit = $version.split(".")
            $versionSplit = $versionSplit[0..($versionSplit.Length - 2)]
            $version = $versionSplit -join "."
        }

        if ($firstReleaseVersion -eq $true) {
            # This is the first time this package will be build so we append the release version 000
            # TODO: If there is already .0000 set, but process failed, the 0000 will be chained with each run. for example 13.0.0.0000.0000.0000
            $set = (Get-Content $nuspecPath) -replace "<version>.*</version>", ("<version>" + $version + ".000" + "</version>") | Set-Content $nuspecPath
        }
        else {
            $releaseVersion = [int]($versionOld.Substring($versionOld.length - 3))
            $newRelease = $releaseVersion + 1
            $newRelease = ([string]$newRelease).PadLeft(3, "0")
            $set = (Get-Content $nuspecPath) -replace "<version>.*</version>", ("<version>" + $version + "." + $newRelease + "</version>") | Set-Content $nuspecPath
        }
    }

    end {

    }
}
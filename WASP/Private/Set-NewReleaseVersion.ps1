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
        $version = ([xml](Get-Content -Path $nuspecPath)).Package.metadata.version
        $id = ([xml](Get-Content -Path $nuspecPath)).Package.metadata.id
    }

    process {
        # remove characters from a version
        if (-Not ($version -match "^(\d+\.)?(\d+\.)?(\d+\.)?(\*|\d+)$")) {
            $version = Format-VersionString -VersionString $version
        }

        $versionOld = $version

        $versionTag = "<version>" + $version + "</version>"
        $hasFourSegments = [regex]::Match($versionTag, "<version>(\w|\d)+\.(\w|\d)+\.(\w|\d)+\.(\w|\d)+<\/version>").Success

        if (($hasFourSegments -eq $true) -or ($firstReleaseVersion -eq $false)) {
            $versionSplit = $version.split(".")
            $versionSplit = $versionSplit[0..($versionSplit.Length - 2)]
            $version = $versionSplit -join "."
        }

        if ($firstReleaseVersion -eq $true) {
            # This is the first time this package will be build so we append the release version 000
            # This check will prevent adding .000 to version.
            if (-not($version -match "(0{3})$")) {
                # If we have four segments, we should check if there isn't
                # already a 000 version of an older minor increase
                if($hasFourSegments) {
                    $LatestVersion = Get-LatestVersionFromRepo -PackageName $id -Repository "Dev"
                    if(([version]$LatestVersion).Major -eq ([version]$version).Major -and ([version]$LatestVersion).Minor -eq ([version]$version).Minor -and
                     ([version]$LatestVersion).Build -eq ([version]$version).Build) {
                        if(([version]$LatestVersion).Revision -ge 100) {
                            $Rel = ([version]$LatestVersion).Revision.ToString()
                        } elseif (([version]$LatestVersion).Revision -ge 10) {
                            $Rel = "0" + ([version]$LatestVersion).Revision.ToString()
                        } else {
                            $Rel = "00" + ([version]$LatestVersion).Revision.ToString()
                        }
                    } else {
                        $Rel = "000"
                    }
                } else {
                    $Rel = "000"
                }
                $set = (Get-Content $nuspecPath) -replace "<version>.*</version>", ("<version>" + $version + ".$Rel" + "</version>") | Set-Content $nuspecPath
            }
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
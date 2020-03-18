function Format-VersionString {
    <#
    .SYNOPSIS
        Formats version string
    .DESCRIPTION
        Formats version string to replace any non-digit characters with a 0
    .NOTES
        FileName: Format-VersionString.ps1
        Author: Kevin Schaefer, Maximilian Burgert
        Contact: its-wcs-ma@unibas.ch
        Created: 2020-30-01
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $VersionString
    )

    begin {

    }

    process {
        $versionSplit = $VersionString.split(".")
        $versionList = New-Object System.Collections.ArrayList
        foreach ($ver in $versionSplit) {
            if ($ver -match "^(\d*)$") {
                $null = $versionList.Add($ver)
            }
            else {
                # prevent version malforming (hope so)
                $null = $versionList.Add("0")
            }
        }
        return $versionList -join "."
    }

    end {
    }
}
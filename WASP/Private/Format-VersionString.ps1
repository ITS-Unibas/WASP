function Format-VersionString {
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
        $version = $versionList -join "."
    }

    end {
        return $version
    }
}
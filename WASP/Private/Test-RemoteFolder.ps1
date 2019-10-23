function Test-RemoteFolder {
    <#
    .SYNOPSIS
        Tests if a folder exists on a given branch in given repository
    .DESCRIPTION
        The folder is defined by $packageName/$version
    .NOTES
        URL will look like this:  https://git.its.unibas.ch/rest/api/1.0/projects/csswcs/repos/package-gallery/browse/sourcetree/3.1.3?at=prod
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BranchName
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        # https://git.its.unibas.ch/rest/api/1.0/projects/csswcs/repos/package-gallery/browse?at=test
        $folders = New-Object System.Collections.ArrayList
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/browse/{3}/{4}?at={5}" -f $config.Application.GitBaseURL, $config.Application.GitProject, $Repository, $PackageName, $Version, $BranchName)
        try {
            $r = Invoke-GetRequest $url
        }
        catch {
            # Get request failed for the given url, this means that either the version or the package does not yet exist in that branch
            return $false
        }

        Write-Log "Package $PackageName and version $Version exist in branch $BranchName."
        return $true
    }

    end {

    }
}
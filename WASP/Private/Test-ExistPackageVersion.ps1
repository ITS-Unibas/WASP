function Test-ExistPackageVersion {
    <#
    .SYNOPSIS
        Tests if package exists on a given branch with a given version.
    .DESCRIPTION
        By checking the url, the existence of a folder with a given version name is checked.
        The folder is defined by $packageName/$version
        URL will look like this:  https://git.its.unibas.ch/rest/api/1.0/projects/csswcs/repos/package-gallery/browse/sourcetree/3.1.3?at=prod
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
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Package,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Branch
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/browse/{3}/{4}?at={5}" -f $config.Application.GitBaseURL, $config.Application.GitProject, $Repository, $Package, $Version, $Branch)
        try {
            $request = Invoke-GetRequest $url
            return $true
        }
        catch {
            # Get request failed for the given url, this means that either the version or the package does not yet exist in that branch
            Write-Log "Get request for $url failed. Package $Package with version $Version does not exist in branch $Branch."
            return $false
        }
    }

    end {

    }
}
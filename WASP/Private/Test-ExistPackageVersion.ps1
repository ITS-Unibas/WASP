function Test-ExistPackageVersion {
    <#
    .SYNOPSIS
        Tests if a package exists on a given branch with a given version
    .DESCRIPTION
        By checking the url, the existence of a folder with a given version name is checked
        The folder is defined by $packageName/$version
        URL will look like this:  https://api.github.com/repos/wasp-its/zzz-test-package-gallery/contents/git.install/2.37.0?ref=dev/git.install@2.37.0
    .NOTES
        FileName: Test-ExistPackageVersion.ps1
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
        $url = ("{0}/repos/{1}/{2}/contents/{3}/{4}?ref={5}" -f $config.Application.GitHubBaseUrl, $config.Application.GitHubOrganisation, $Repository, $Package, $Version, $Branch)
        try {
            $request = Invoke-GetRequest $url
            return $true         
        }
        catch {
            # Get request failed for the given url, this means that either the version or the package does not yet exist in that branch
            Write-Log "Package $Package with version $Version does not exist in branch $Branch." -Severity 1
            return $false
        }
    }

    end {

    }
}
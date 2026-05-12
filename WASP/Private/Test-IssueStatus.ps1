function Test-IssueStatus {
    <#
    .SYNOPSIS
        Tests if a jira issue status is true for a given package name and version
    .DESCRIPTION
        Invokes the REST API of the jira board to check the issues status
    .Notes 
        FileName: Test-IssueStatus.ps1
        Author: Tim Keller, Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-09-04
        Updated: 2026-05-12
        Version: 1.0.1
    #>

    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Development", "Testing", "Production")]
        [String]
        $Status
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUserAPIToken = $config.Application.JiraUserAPIToken
        $JiraUrl = $config.Application.JiraBaseURL
        $ProjectKey = $config.Application.ProjectKey
    }

    process {
        $Uri = $JiraUrl + "/rest/api/2/search?jql=project=$ProjectKey%20AND%20issuetype=%20Story%20AND%20status=%20$Status%20AND%20summary~`"$PackageName@$PackageVersion`""
        Write-Log "Checking Issue-Status for Package $PackageName with version $PackageVersion"
        try {
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -Headers @{Authorization = "Bearer $JiraUserAPIToken" }
            if ($Response.total -eq 1){
                return $true
            }
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
        }
        return $false
    }
}
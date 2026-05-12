function Get-JiraIssue {
    <#
    .SYNOPSIS
        Invokes a REST API call to check the existing of a specific issue
    .DESCRIPTION
        Invokes a REST API call to check the existing of a specific issue
    .NOTES
        FileName: Get-JiraIssue.ps1
        Author: Tim Keller, Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-09-04
        Created: 2026-05-12
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
        $PackageVersion
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $config.Application.JiraBaseURL
        $ProjectKey = $config.Application.ProjectKey
        $JiraUserAPIToken = $Config.Application.JiraUserAPIToken
    }

    process {
        $Uri = $JiraUrl + "/rest/api/2/search?jql=project=$ProjectKey%20AND%20issuetype=%20Story%20AND%20summary~`"$PackageName@$PackageVersion`""
        Write-Log -Message "Check if issue for Package $PackageName with version $PackageVersion exists..." -Severity 0
        try {
            $response = Invoke-RestMethod -Uri $Uri -Method Get -Headers @{Authorization = "Bearer $JiraUserAPIToken" }

            if ($response.total -ne 0){
                Write-Log -Message "Issue for package $PackageName with version $PackageVersion already exists!" -Severity 2
            } else {
                Write-Log -Message "Issue for package $PackageName with version $PackageVersion does not exist" -Severity 0
            }

            return $response
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
        }
    }
}

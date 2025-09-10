function Get-JiraIssueKeyFromName {
    <#
    .SYNOPSIS
        Retrieves a Jira issue key from an issue name (summary).
    .DESCRIPTION
        Uses Jira REST API search to find an issue by its summary/title
        and returns the issue key (e.g., PROJ-123).
    .NOTES
        FileName: Get-JiraIssueKeyFromName.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-09-09
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $issueName
    )

    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword
        $projectKey = $config.Application.ProjectKey
    }

    process {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type"  = "application/json"
        }

        # JQL to search by issue summary
        $jql = "project = $projectKey AND summary ~ `"$issueName`""
        $searchUrl = "$jiraBaseUrl/rest/api/2/search?jql=$([System.Web.HttpUtility]::UrlEncode($jql))"

        Write-Log -Message "Searching for Jira issue with summary: $issueName" -Severity 1
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $header

        if ($response.issues.Count -eq 0) {
            Write-Log -Message "No Jira issue found with summary: $issueName" -Severity 2
            return $null
        }

        # Return all matching issue keys
        $issueKeys = $response.issues | ForEach-Object { $_.key }

        Write-Log -Message "Found Jira issues: $($issueKeys -join ', ')" -Severity 0
        return $issueKeys
    }

    end { }
}

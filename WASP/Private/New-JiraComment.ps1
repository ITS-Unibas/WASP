function New-JiraComment {
    <#
    .SYNOPSIS
        Adds a comment to a Jira Ticket
    .DESCRIPTION
        Adds a comment to a Jira Ticket
    .NOTES
        FileName: New-JiraComment.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-08-21
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $issueKey,
        [Parameter(Mandatory = $true)][string] $comment
    )

    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword
        $projectKey = $config.Application.ProjectKey
        $issueType = $config.Application.IssueType # Story
    }

    process { 
        $url = "$($jiraBaseUrl)/rest/api/2/issue/$issueKey/comment"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        # Create the JSON payload for the new comment
        $body = @{
            body = $comment
        } | ConvertTo-Json -Depth 3

        Write-Log -Message "Commenting jira ticket $issueKey with comment: $comment" -Severity 1
        
        $response = Invoke-WebRequest -Uri $url -Method Post -Headers $header -Body $body  

        if ($response.StatusCode -eq 201) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            Write-Log -Message "Jira ticket successfully commented." -Severity 0
        } else {
            Write-Log -Message "Failed to comment jira ticket! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }

    end {
    }
}
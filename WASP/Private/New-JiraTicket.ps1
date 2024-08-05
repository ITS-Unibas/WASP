function New-JiraTicket {
    <#
    .SYNOPSIS
        Creates a new Jira Ticket
    .DESCRIPTION
        Creates a new Jira Ticket with the given parameters
    .NOTES
        FileName: New-JiraTicket.ps1
        Author: Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-08-05
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$summary
    )

    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword
        $jiraAPIToken = $config.Application.JiraToken
        $projectKey = $config.Application.JiraProjectKey
        $issueType = $config.Application.IssueType
    }

    process { 
    $description = "Automatically created ticket by WASP"

    # Create the JSON payload for the new issue
    $issuePayload = @{
        fields = @{
            # assignee = $jiraUser
            project = @{
                key = $projectKey
            }
            summary = $summary
            description = $description
            issuetype = @{
                name = $IissueType
            }
        }
    } | ConvertTo-Json -Depth 3

    # Encode credentials to Base64
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${JiraUsername}:${JiraAPIToken}")))

    # Create the new issue
    $response = Invoke-RestMethod -Uri "$JiraBaseUrl/rest/api/2/issue" `
        -Method Post `
        -Headers @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } `
        -Body $IssuePayload

    # Output the response
    $response

    }

    end {
    }
}

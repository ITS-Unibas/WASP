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
        $projectKey = $config.Application.ProjectKey
        $issueType = $config.Application.IssueType # Story
    }

    process { 
        $url = "$($jiraBaseUrl)/rest/api/2/issue"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        $description = "Automatically created ticket by WASP"

        # Create the JSON payload for the new issue
        $body = @{
            fields = @{
                # assignee = $jiraUser
                project = @{
                    key = $projectKey
                }
                summary = $summary
                description = $description
                issuetype = @{
                    name = $issueType
                }
            }
        } | ConvertTo-Json -Depth 3

        # Create the new issue
        Write-Log -Message "Creating new JIRA ticket for '$summary'" -Severity 1
        
        $response = Invoke-WebRequest -Uri $url -Method Post -Headers $header -Body $body  

        if ($response.StatusCode -eq 201) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            Write-Log -Message "New Jira ticket successfully created: $($response.Content)" -Severity 0
        } else {
            Write-Log -Message "Failed to create new Jira ticket! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }

    end {
    }
}
function Flag-JiraTicket {
    <#
    .SYNOPSIS
        Flags a Jira Ticket
    .DESCRIPTION
        Flags or unflags and optionally comments a Jira Ticket with the given parameters
    .NOTES
        FileName: Flag-JiraTicket.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-08-21
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $issueKey,
        [Parameter(Mandatory = $false)][string] $comment,
        [Parameter(Mandatory = $false)][bool] $unflag
    )

    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword
        $projectKey = $config.Application.ProjectKey
        $issueType = $config.Application.IssueType
    }

    process { 
        $url = "$($jiraBaseUrl)/rest/api/2/issue/$issueKey"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        # Create comment if provided
        if ($comment) {
            $flagComment = "(flag) " + $comment
            if ($unflag) {
                $flagComment = "(flagoff) " + $comment
            }
        }
        # Create the JSON payload
        $value = "Impediment"

        if ($unflag) {
            $value = $null
        }
        
        $body = @{
            fields = @{
                # This field is used for the flagging
                customfield_10000 = @(
                    @{ value = $value }
                )
            
            }
        } | ConvertTo-Json -Depth 3
        
        Write-Log -Message "Flagging jira ticket $issueKey" -Severity 1
        $response = Invoke-WebRequest -Uri $url -Method Put -Headers $header -Body $body  

        if ($comment) {
            New-JiraComment -issueKey $issueKey -comment $flagComment
        }

        if ($response.StatusCode -eq 204) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            if ($unflag) {
                Write-Log -Message "Jira ticket successfully unflagged" -Severity -0
            } else {
                Write-Log -Message "Jira ticket successfully flagged" -Severity -0
            }
        } else {
            Write-Log -Message "Failed to flag/unflag jira ticket! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }

    end {
    }
}

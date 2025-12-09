function Test-IssueFlag {
    <#
    .SYNOPSIS
        Checks if a Jira Ticket is currently flagged.
    .DESCRIPTION
        Retrieves the flag status of the specified Jira issue by checking the 'Flagged' field value.
    .NOTES
        FileName: Get-JiraFlagStatus.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-11-13
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $issueKey
    )

    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword

        $base64AuthInfo = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("${jiraUser}:${jiraPassword}")
        )
        $headers = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type"  = "application/json"
        }

        $customfield = "customfield_10000"

        # Request only the custom field representing the flag
        $url = "$jiraBaseUrl/rest/api/2/issue/$($issueKey)?fields=$customfield"
    }

    process {
        Write-Log -Message "Checking flag status for Jira ticket $issueKey" -Severity 1

        try {
            $response = Invoke-WebRequest -Uri $url -Method Get -Headers $headers -UseBasicParsing
            $issue = $response.Content | ConvertFrom-Json

            if (-not $issue.fields) {
                Write-Log -Message "No fields found for Jira ticket $issueKey" -Severity 2
                return $null
            }

            $flagField = $issue.fields.$customfield

            if ($flagField -and $flagField.value -eq "Impediment") {
                Write-Log -Message "Jira ticket $issueKey is currently flagged." -Severity 0
                return $true
            } else {
                Write-Log -Message "Jira ticket $issueKey is not flagged." -Severity 0
                return $false
            }
        }
        catch {
            Write-Log -Message "Failed to retrieve flag status for Jira ticket $($issueKey): $($_.Exception.Message)" -Severity 3
            return $null
        }
    }

    end { }
}

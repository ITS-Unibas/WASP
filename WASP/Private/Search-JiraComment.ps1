function Search-JiraComment {
    <#
    .SYNOPSIS
        Searches for a specific comment in a Jira Ticket
    .DESCRIPTION
        Retrieves all comments from the specified Jira ticket and searches for a comment containing the given search string.
    .NOTES
        FileName: Search-JiraComment.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-11-04
        Version: 1.0.0
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string] $issueKey,
        [Parameter(Mandatory = $true)][string] $searchString
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

        $url = "$jiraBaseUrl/rest/api/2/issue/$issueKey/comment"
    }

    process {
        Write-Log -Message "Searching Jira ticket $issueKey for comment containing '$searchString'" -Severity 1

        try {
            $response = Invoke-WebRequest -Uri $url -Method Get -Headers $headers -UseBasicParsing
            $comments = ($response.Content | ConvertFrom-Json).comments

            if (-not $comments) {
                Write-Log -Message "No comments found for Jira ticket $issueKey" -Severity 2
                return $null
            }

            $matched = $comments | Where-Object { $_.body -match [Regex]::Escape($searchString) }

            if ($matched) {
                Write-Log -Message "Found $($matched.Count) matching comment(s) in $issueKey" -Severity 0
                return $matched | Select-Object id, author, created, body
            } else {
                Write-Log -Message "No comment matching '$searchString' found in $issueKey" -Severity 2
                return $null
            }
        }
        catch {
            Write-Log -Message "Failed to retrieve comments for Jira ticket $(issueKey): $($_.Exception.Message)" -Severity 3
            return $null
        }
    }

    end { }
}

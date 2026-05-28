function Get-JiraStatusChangedDate {
    <#
    .SYNOPSIS
        Get the last time the Status of a given Jira Issue changed.
    .DESCRIPTION
        Retrieves the most recent timestamp when the Status field of the specified Jira issue was updated,
        using the Jira REST API changelog endpoint.
    .NOTES
        FileName: Get-JiraStatusChangedTime.ps1
        Author: Julian Bopp
        Contact: its-wcs-ma@unibas.ch
        Created: 2025-11-10
        Version: 1.0.0
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$IssueKey
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $Config.Application.JiraBaseURL
        $JiraUser = $Config.Application.JiraUser
        $JiraPassword = $Config.Application.JiraPassword

        $Base64Auth = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $JiraUser, $JiraPassword))
        )

        Write-Log "Retrieving last status change time for Jira issue $IssueKey"
    }

    process {
        $Url = "$JiraUrl/rest/api/2/issue/$($IssueKey)?expand=changelog"

        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers @{ Authorization = "Basic $Base64Auth" }
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Failed to retrieve issue changelog for $IssueKey (HTTP $StatusCode)" -Severity 3
            return $null
        }

        # Extract changelog histories related to status changes
        $StatusChanges = @()
        foreach ($history in $Response.changelog.histories) {
            foreach ($item in $history.items) {
                if ($item.field -eq "status") {
                    $StatusChanges += [PSCustomObject]@{
                        From    = $item.fromString
                        To      = $item.toString
                        Changed = [datetime]$history.created
                    }
                }
            }
        }

        if (-not $StatusChanges) {
            Write-Log "No status changes found for $IssueKey" -Severity 2
            return $null
        }

        # Get the most recent status change
        $LastChange = $StatusChanges | Sort-Object Changed -Descending | Select-Object -First 1

        Write-Log "Last status change for $($IssueKey): $($LastChange.From) → $($LastChange.To) at $($LastChange.Changed)"
        return $LastChange
    }
}

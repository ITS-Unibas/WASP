function Update-JiraStatus {
    <#
    .SYNOPSIS
        Invokes a REST API call to change the status of a specific issue
    .DESCRIPTION
        Invokes a REST API call to change the status of a specific issue
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ticket,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DestinationStatus
    )


    begin {
        $config = Read-ConfigFile
        $jiraBaseUrl = $config.Application.JiraBaseUrl
        $jiraUser = $config.Application.JiraUser
        $jiraPassword = $config.Application.JiraPassword
    }

    process { 
        # Check if the Jira ticket already exists
        $package, $version = $ticket -split "@"
        $issue = Get-JiraIssue -PackageName $package -PackageVersion $version

        if ($issue.total -eq 0) {
            Write-Log -Message "Jira ticket for $package with version $version does not exist yet!" -Severity 0
            New-JiraTicket -summary $ticket
            $issue = Get-JiraIssue -PackageName $package -PackageVersion $version
        }

        $key = $issue.issues.key
        $SourceStatus = $issue.issues.fields.status.name

        # The URL to trigger the transition of the ticket status
        $url = "$($jiraBaseUrl)/rest/api/2/issue/$($key)/transitions"

        # Transition: Dev -> Test
        if ($SourceStatus -eq "Development" -and $DestinationStatus -eq "Testing") {
            $transitionId = 11
        # Transition: Test -> Dev
        } elseif ($SourceStatus -eq "Testing" -and $DestinationStatus -eq "Development") {
            $transitionId = 21
        } elseif ($SourceStatus -eq "Testing" -and $DestinationStatus -eq "Production") {
            $transitionId = 31
        } elseif ($SourceStatus -eq "Production" -and $DestinationStatus -eq "Development") {
            $transitionId = 41
        } else {
            Write-Log -Message "Invalid status transition from $SourceStatus to $DestinationStatus" -Severity 3
            return
        }


        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        # Create the JSON payload for the changes in the
        # Change Status from Test to Dev
        $body = @{
            transition = @{
                id = $($transitionId)
            }
        } | ConvertTo-Json -Depth 3

        # Create the new issue
        Write-Log -Message "Moving jira ticket $key for package $package from $SourceStatus to $DestinationStatus" -Severity 1

        $response = Invoke-WebRequest -Uri $url -Method Post -Headers $header -Body $body  

        if ($response.StatusCode -eq 204) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            Write-Log -Message "Jira ticket status successfully updated: $($response.Content)" -Severity 0
        } else {
            Write-Log -Message "Failed to update Jira ticket status! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }
        
    end {
        }
}
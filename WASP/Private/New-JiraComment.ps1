function New-JiraComment {
    <#
    .SYNOPSIS
        Invokes a REST API call to add a comment to a specific issue
    .DESCRIPTION
        Invokes a REST API call to add a comment to a specific issue
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ticket,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $comment
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
        $url = "$($jiraBaseUrl)/rest/api/2/issue/$($key)/comment"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        # Create the JSON payload for the changes in the
        # Change Status from Test to Dev
        $body = @{
            body = $($comment)
        } | ConvertTo-Json -Depth 3
        

        # Create the new issue
        Write-Log -Message "Add Comment to ticket $key for package $package" -Severity 1

        $response = Invoke-WebRequest -Uri $url -Method Post -Headers $header -Body $body  

        if ($response.StatusCode -eq 201) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            Write-Log -Message "Comment succcessfully added to Jira ticket" -Severity 0
        } else {
            Write-Log -Message "Failed to add comment to Jira ticket! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }
        
    end {
        }
}
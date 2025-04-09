function Add-JiraFlag {
    <#
    .SYNOPSIS
        Invokes a REST API call to add a flag to a specific issue
    .DESCRIPTION
        Invokes a REST API call to add a flag to a specific issue
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ticket
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

        # The URL to change the flag status of the ticket
        $url = "$($jiraBaseUrl)/rest/api/2/issue/$($key)"

        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("${jiraUser}:${jiraPassword}")))

        $header = @{
            "Authorization" = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        } 

        # The flag is set by changing the value of customfield_10000 to "Impediment"
        $body = @{
            fields = @{
                customfield_10000 = @(
                    @{ value = "Impediment" }
                )
            }
        } | ConvertTo-Json -Depth 3
        

        
        Write-Log -Message "Moving jira ticket $key for package $package from $SourceStatus to $DestinationStatus" -Severity 1

        # For this kind of request, the Put Method is needed.
        $response = Invoke-WebRequest -Uri $url -Method Put -Headers $header -Body $body  

        if ($response.StatusCode -eq 204) {
            Write-Log -Message "StatusCode: $($response.StatusCode)" -Severity 0
            Write-Log -Message "Flag successfully added to the Jira Ticket!" -Severity 0
        } else {
            Write-Log -Message "Failed to add the flag to the Jira Ticket! StatusCode: $($response.StatusCode):  $($response.StatusDescription)" -Severity 3
        }
    }
        
    end {
        }
}
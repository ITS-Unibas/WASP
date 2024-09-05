function Get-JiraIssues () {
    <#
    .Synopsis 
    Get the Current Jira Issues for the given Project.
    .Description 
    Get the Current Jira Issues for the given Project.
    .Notes 
    FileName: Get-JiraIssues.ps1
    Author: Tim Keller 
    Contact: tim.keller@unibas.ch
    Created: 2024-09-04
    Updated: 2024-09-05
    Version: 1.0.0
    #>
    param(
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $Config.Application.JiraBaseURL
        $ProjectKey = $Config.Application.ProjectKey

    } process {
        <#Create the URL for the Jira Issues API Endpoint#>
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $Url = $JiraUrl + "/rest/api/latest/search?jql=project=$ProjectKey&maxResults=500"
        Write-Log "Retrieving Jira Issues for Project $ProjectKey"
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers @{Authorization = "Basic $Base64Auth" }
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
        }
        <#Save the number of total issues to check if all of them were downloaded.#>
        $totalIssues = $Response.total

        <#Iteratively save the Issues for all of the steps in one object.#>
        $Results = @()
        $Results += $Response.Issues

        <#Make a new request until all issues are stored in the Reults object#>
        while($Results.Count -ne $totalIssues){
            <#The starting point for the pagination of the request is the number of issues already pulled#>
            $StartAt =  $Response.startAt + $Response.issues.Count
            $UrlIter = $JiraUrl + "/rest/api/latest/search?jql=project=$ProjectKey&startAt=$StartAt&maxResults=500"
            try {
                $Response = Invoke-RestMethod -Uri $UrlIter -Method Get -Headers @{Authorization = "Basic $Base64Auth" }
            }
            catch {
                $StatusCode = $_.Exception.Response.StatusCode.value__
                Write-Log "Get request failed with $StatusCode" -Severity 3
            }
            $Results += $Response.Issues
            
        }
        Write-Log "Successfully Retrieved $totalIssues Jira Issues for the Project $ProjectKey"
        Return $Results
    }
}
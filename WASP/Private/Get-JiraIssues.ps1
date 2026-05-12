function Get-JiraIssues () {
    <#
    .Synopsis 
        Get the Current Jira Issues for the given Project.
    .Description 
        Get the Current Jira Issues for the given Project.
    .Notes 
        FileName: Get-JiraIssues.ps1
        Author: Tim Keller, Uwe Molnar
        Contact: its-wcs-ma@unibas.ch
        Created: 2024-09-04
        Updated: 2026-05-12
        Version: 1.0.1
    #>
    param(
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $Config.Application.JiraBaseURL
        $JiraUserAPIToken = $config.Application.JiraUserAPIToken
        $ProjectKey = $Config.Application.ProjectKey

    } process {
        $Url = $JiraUrl + "/rest/api/latest/search?jql=project=$ProjectKey&maxResults=500"
        Write-Log "Retrieving Jira Issues for Project $ProjectKey"

        try {
            $Response = Invoke-RestMethod -Uri $Url -Method Get -Headers @{Authorization = "Bearer $JiraUserAPIToken" }
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
            return $null
        }
    
        $totalIssues = $Response.total
        
        $Results = @()
        $Results += $Response.Issues

        <#Make a new request until all issues are stored in the Reults object#>
        while($Results.Count -ne $totalIssues){
            <#The starting point for the pagination of the request is the number of issues already pulled#>
            $StartAt =  $Response.startAt + $Response.issues.Count
            $UrlIter = $JiraUrl + "/rest/api/latest/search?jql=project=$ProjectKey&startAt=$StartAt&maxResults=500"
            try {
                $Response = Invoke-RestMethod -Uri $UrlIter -Method Get -Headers @{Authorization = "Bearer $JiraUserAPIToken" }
            }
            catch {
                $StatusCode = $_.Exception.Response.StatusCode.value__
                Write-Log "Get request failed with $StatusCode" -Severity 3
                return $null
            }
            $Results += $Response.Issues
            
        }
        
        Write-Log "Successfully Retrieved $totalIssues Jira Issues for the Project $ProjectKey"
        return $Results    
    }
}
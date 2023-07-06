function Test-JiraIssue {
    <#
    .SYNOPSIS
        Tests if a jira issue is in 'Testing' and if no new updates were made on the corresponding git-branch
    .DESCRIPTION
        If a software-package is in 'Testing' the workflow should not process it. Only if there are changes made on the corresponding git-branch.
        This function avoids that the workflow processes a package that is already in 'Testing' and no changes were made.
        If this function returns $true the workflow should process the package. 
    #>

    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PackageVersion
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $config.Application.JiraBaseURL
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackageGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
        $ProjectKey = $config.Application.ProjectKey

        $Headers = @{
            Authorization = "Basic $Base64Auth"
            'Content-Type' = 'application/json'
        }
    }

    process {
        # Test if the JIRA-Issue is in 'Testing'
        $JiraStatusTesting = Test-IssueStatus -PackageName $packageName -PackageVersion $packageVersion -Status "Testing"  
        
        if ($JiraStatusTesting){
            # Get the JIRA-Issue-Key for the package
            $getIssueKeyUri = $JiraUrl + "/rest/api/2/search"

            $Body = @{
                jql = "project = `"$ProjectKey`" AND summary ~ `"$packageName@$PackageVersion`""
                startAt = 0
                maxResults = 1
                fields = @('key')
            } | ConvertTo-Json
    
            Write-Log "Getting the Issue-Key for $packageName@$PackageVersion" -Severity 0
    
            try {
                $getIssueKeyResponse = Invoke-RestMethod -Uri $getIssueKeyUri -Method Post -Headers $Headers -Body $Body
                $IssueKey = $getIssueKeyResponse.issues.key
                Write-Log "Issue-Key found: $IssueKey" -Severity 0
            } catch {
                $StatusCode = $_.Exception.getDateTimeResponse.StatusCode.value__
                Write-Log "Post request failed with $StatusCode" -Severity 3
            }
    
            # Get the last update date and time of the JIRA-Issue
            try {
                $Headers.Remove('Content-Type')
                $getDateTimeUri = "https://jira.its.unibas.ch/rest/api/2/issue/$IssueKey"
                $getDateTimeResponse = Invoke-RestMethod -Uri $getDateTimeUri -Method Get -Headers $Headers
        
                $LastUpdatedJIRA = $getDateTimeResponse.fields.updated
                Write-Log "Last update date and time of the JIRA-Issue: $LastUpdatedJIRA" -Severity 0                               
            }
            catch {
                $StatusCode = $_.Exception.getDateTimeResponse.StatusCode.value__
                Write-Log "Post request failed with $StatusCode" -Severity 3
            }

            # Get the last update date and time of the corresponding git-branch
            $branch = (git -C $PackageGalleryPath branch --show-current 2>&1)
            [DateTime]$lastGitCommit = (git -C $PackageGalleryPath log -1 $branch --format="%ai" 2>&1)
            Write-Log "Last update date and time of the corresponding git-branch: $lastGitCommit" -Severity 0

            # Compare the last update date and time of the JIRA-Issue and the last commit date and time of the corresponding git-branch
            if ($lastGitCommit -lt $LastUpdatedJIRA){
                Write-Log "Skip $packageName@$PackageVersion - JIRA-Ticket is in Testing and no changes detected." -Severity 1
                return $false
            } else {
                Write-Log "JIRA-Ticket for $packageName@$PackageVersion is in Testing and there are new changes detected. Continue processing..." -Severity 1
                return $true
            }
        } else  {
            return $true
        }
    }
}
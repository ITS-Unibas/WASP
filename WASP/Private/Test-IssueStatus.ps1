function Test-IssueStatus {
    <#
    .SYNOPSIS
        Tests if a jira issue status is true for a given package name and version
    .DESCRIPTION
        Invokes the REST API of the jira board to check the issues status
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
        $PackageVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Development", "Testing", "Production")]
        [String]
        $Status
    )

    begin {
        $Config = Read-ConfigFile
        $JiraUrl = $config.Application.JiraBaseURL
        $ProjectKey = $config.Application.ProjectKey
    }

    process {
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Config.Application.RepositoryManagerAPIUser, $Config.Application.RepostoryManagerAPIPassword)))
        $Uri = $JiraUrl + "/rest/api/2/search?jql=project=$ProjectKey%20AND%20issuetype=%20Story%20AND%20status=%20$Status%20AND%20summary~`"$PackageName@$PackageVersion`""
        Write-Log "Checking Issue-Status for Package $PackageName with version $PackageVersion"
        try {
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -Headers @{Authorization = "Basic $Base64Auth" }
            if ($Response.total -eq 1){
                return $true
            }
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
        }
        return $false
    }
}
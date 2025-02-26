function Get-JiraIssue {
    <#
    .SYNOPSIS
        Invokes a REST API call to check the existing of a specific issue
    .DESCRIPTION
        Invokes a REST API call to check the existing of a specific issue
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
        $ProjectKey = $config.Application.ProjectKey
        $User = $Config.Application.JiraUser
        $Pass = $Config.Application.JiraPassword
    }

    process {
        $Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $Pass)))
        $Uri = $JiraUrl + "/rest/api/2/search?jql=project=$ProjectKey%20AND%20issuetype=%20Story%20AND%20summary~`"$PackageName@$PackageVersion`""
        Write-Log -Message "Check if issue for Package $PackageName with version $PackageVersion exists..." -Severity 0
        try {
            $response = Invoke-RestMethod -Uri $Uri -Method Get -Headers @{Authorization = "Basic $Base64Auth" }

            if ($response.total -ne 0){
                Write-Log -Message "Issue for package $PackageName with version $PackageVersion already exists!" -Severity 2
            } else {
                Write-Log -Message "Issue for package $PackageName with version $PackageVersion does not exist" -Severity 0
            }

            return $response
        }
        catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            Write-Log "Get request failed with $StatusCode" -Severity 3
        }
    }
}

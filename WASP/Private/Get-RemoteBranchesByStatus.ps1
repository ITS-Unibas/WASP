function Get-RemoteBranchesByStatus {
    <#
    .SYNOPSIS
        Function returns a list of branches with pull-requests in given repo with a given status.
    .DESCRIPTION
        Status can either be OPEN, MERGED or DECLINED
    .PARAMETER Repo
        Name of the repository from which the remote branchnames should fetched for
    .PARAMETER User
        Name of the user of the remote repository
    .PARAMETER Status
        Pull request status to filter
    #>
    [CmdletBinding()]
    param (
        # Name of repository
        [string]
        $Repo,

        # Name of User
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        # Status of PR in branch to filter
        [string]
        $Status
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $branches = New-Object System.Collections.ArrayList
        $url = ("{0}/repos/{1}/{2}/pulls?state=$Status" -f $config.Application.GitHubBaseUrl, $config.Application.GitHubOrganisation, $Repo)
        try {
            $JSONbranches = Invoke-GetRequest $url
            $JSONbranches | ForEach-Object { $null = $branches.Add($_.base.ref) }
        } catch {
            Write-Log "Get request failed for $url" -Severity 3
        }
        return $branches
    }
}
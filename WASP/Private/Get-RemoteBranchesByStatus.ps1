function Get-RemoteBranchesByStatus {
    <#
    .SYNOPSIS
        Function returns a list of branches with pull-requests in given repo with a given status.
    .DESCRIPTION
        Status can either be OPEN, MERGED or DECLINED
    #>
    [CmdletBinding()]
    param (
        # Name of repository
        [string]
        $Repo,

        # Status of PR in branch to filter
        [string]
        $Status
    )
    
    begin {
        $config = Read-ConfigFile
    }
    
    process {
        $branches = New-Object System.Collections.ArrayList
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/pull-requests?state=$Status" -f $config.Application.GitBaseURL, $config.Application.GitProject, $Repo)
        $r = Invoke-GetRequest $url
        $JSONbranches = $r.values
        $JSONbranches | ForEach-Object { $branches.Add($_.fromRef.displayID) }
        return $branches

    }
}
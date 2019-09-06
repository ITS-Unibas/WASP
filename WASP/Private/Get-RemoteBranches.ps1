function Get-RemoteBranches {
    <#
    .SYNOPSIS
        Returns all remote branches of a given repository
    .DESCRIPTION
        Returns all remote branches of a given repository by using Atlassian Bitbucket REST Api
    .PARAMETER Repo
        Name of the repository which the remote branchnames should fetched for
    #>

    [CmdletBinding()]
    param (
        # Name of repository
        [string]
        $repo
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $branches = New-Object System.Collections.ArrayList
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/branches" -f $config.Application.GitBaseURL, $config.Application.GitProject, $repo)
        try {
            $r = Invoke-GetRequest $url
            $JSONbranches = $r.values
            $JSONbranches | ForEach-Object { $null = $branches.Add($_.displayID) }
        }
        catch {
            Write-Log "Get request failed for $url" -Severity 3
        }
        return $branches
    }
}
function Get-RemoteBranches {
    <#
    .SYNOPSIS
        Returns all remote branches of a given repository
    .DESCRIPTION
        Returns all remote branches of a given repository by using Atlassian Bitbucket REST Api
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
        $r = Invoke-GetRequest $url
        $JSONbranches = $r.values
        
        $JSONbranches | ForEach-Object { $branches.Add($_.displayID) }
        return $branches
    }
}
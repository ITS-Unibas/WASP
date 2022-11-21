function Get-RemoteBranches {
    <#
    .SYNOPSIS
        Returns all remote branches of a given repository
    .DESCRIPTION
        Returns all remote branches of a given repository by using Atlassian Bitbucket REST Api
    .PARAMETER Repo
        Name of the repository from which the remote branchnames should fetched for
    .PARAMETER User
        Name of the user of the remote repository
    #>

    [CmdletBinding()]
    param (
        # Name of repository
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repo,

        # Name of User
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User
    )

    begin {
        $config = Read-ConfigFile
    }
    
    process {
        $branches = New-Object System.Collections.ArrayList
        $url = ("{0}/repos/{1}/{2}/branches" -f $config.Application.GitHubBaseUrl,  $User, $Repo)
        try {
            $JSONbranches = Invoke-GetRequest $url
            $JSONbranches | ForEach-Object { $null = $branches.Add($_.name) }
        }
        catch {
            Write-Log "Get request failed for $url" -Severity 3
        }
        return $branches
    }
}
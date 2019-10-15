function New-RemoteBranch {
    <#
    .SYNOPSIS
        Creates a new remote branch
    .DESCRIPTION
        Creates a new remote branch with a given name for a given repository
    .PARAMETER Repository
        Repository which the branch should be created for
    .PARAMETER BranchName
        Define a branchname
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BranchName
    )

    begin {
        $RemoteBranches = Get-RemoteBranches -Repo $Repository
        $Config = Read-ConfigFile
    }

    process {
        if ($RemoteBranches.Contains($BranchName)) {
            Write-Log "Branch $branchName already exist. Nothing to do"
            return
        }

        Write-Log "Branch $BranchName does not exist. Will create a new branch from master."
        $url = ("{0}/rest/api/1.0/projects/{1}/repos/{2}/branches" -f $Config.Application.GitBaseUrl, $Config.Application.GitProject, $Repository)
        # Convert Hashtable to JSON: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-6
        $json = @{"name" = $BranchName; "startPoint" = "refs/heads/{0}" -f $Config.Application.GitBranchPROD } | ConvertTo-Json
        try {
            $null = Invoke-PostRequest -Url $url -Body $json
        } catch {
            Write-Log "We were not able to create a new branch named $BranchName for repository $Repository" -Severity 3
        }
        Write-Log "Branch $BranchName was successfully created for $Repository"

    }
}
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
        $User,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $BranchName
    )

    begin {
        $Config = Read-ConfigFile
        $RemoteBranches = Get-RemoteBranches -Repo $Repository -User $User
    }

    process {
        if ($RemoteBranches.Contains($BranchName)) {
            if (($BranchName -eq "prod") -or ($BranchName -eq "test")) {
                # Exception for prod and test branch, no log-entry should be created
                return
            } 
            Write-Log "Branch $branchName already exist. Nothing to do"
            return
        }

        Write-Log "Branch $BranchName does not exist in $Repository. Will create a new branch."
        
        # URL to get all branches including all infos (ref, node_id, commits/sha...)
        $url = ("{0}/repos/{1}/{2}/git/refs/heads" -f $config.Application.GitHubBaseUrl, $User, $Repository)
        
        # Get the latest commit / sha-Value from prod to checkout a new branch
        $branchValues = Invoke-GetRequest -Url $url
        $branchValueProd = $branchValues | Where-Object {$_.ref -eq "refs/heads/prod"}
        $lastCommitProd = $branchValueProd.object.sha
        
        # Convert Hashtable to JSON: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertto-json?view=powershell-6
        $json = @{"ref" = "refs/heads/$BranchName"; "sha" = $lastCommitProd} | ConvertTo-Json

        # URL to set up new branch 
        $url = ("{0}/repos/{1}/{2}/git/refs" -f $config.Application.GitHubBaseUrl, $User, $Repository)
        
        $null = Invoke-PostRequest -Url $url -Body $json -ErrorAction Stop
        Write-Log "Branch $BranchName was successfully created for $Repository"

    }
}
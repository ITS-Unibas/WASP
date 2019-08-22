function Remove-RemoteBranch {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        [string]
        $Repo,

        [string]
        $Branch
    )
    
    begin {
        $config = Read-ConfigFile
    }
    
    process {
        $remoteBranches = Get-RemoteBranches $Repo
        if ($remoteBranches.Contains($Branch)) {
            Write-Log "Branch $Branch will be deleted."
            $url = ("{0}/rest/branch-utils/1.0/projects/{1}/repos/{2}/branches" -f $config.Application.GitBaseURL, $config.Application.GitProject, $Repo)
            $json = @{"name" = "refs/heads/$Branch"; "dryRun" = "false" } | ConvertTo-Json
            Invoke-DeleteRequest $url $json
        }
        else {
            Write-Log "Branch $Branch to delete does not exist."
        }
    }
    
    end {
    }
}
function Remove-RemoteBranch {
    <#
    .SYNOPSIS
        Removes a remote branch
    .DESCRIPTION
        Removes a given branch from a given repo
    .EXAMPLE
        PS C:\> Remove-Remote-Branch -Repo package-gallery -Branch nicePackage@1.0.0
        Removes branch 'nicePackage@1.0.0' from repository 'package-gallery'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repo,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
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
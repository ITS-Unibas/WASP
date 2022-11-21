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
        $User,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Branch
    )

    begin {
        $config = Read-ConfigFile
    }

    process {
        $remoteBranches = Get-RemoteBranches $Repo -User $User
        if ($remoteBranches.Contains($Branch)) {
            Write-Log "Branch $Branch will be deleted from Repo '$Repo'." -Severity 1
            $url = ("{0}/repos/{1}/{2}/git/refs/heads/{3}" -f $config.Application.GitHubBaseUrl, $User, $Repo, $Branch)
            $null = Invoke-DeleteRequest $url
        }
        else {
            Write-Log "Branch $Branch to delete in Repo $Repo does not exist." -Severity 1
        }
    }

    end {
    }
}
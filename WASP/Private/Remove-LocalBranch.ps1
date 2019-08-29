function Remove-LocalBranch {
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
        $branch,

        [string]
        $repository
    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.$WindowsSoftware
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $WindowsSoftwarePath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        Set-Location $WindowsSoftwarePath

        $remoteBranches = Get-RemoteBranches $WinSoftwareRepoName

        Write-Log ([string] (git checkout $config.Application.GitBranchPROD 2>&1))
        Write-Log ([string] (git pull 2>&1))
        $localBranches = git branch
        ForEach ($local in $localBranches) {
            if ($local -match "\*") {
                # Skip currently checked out prod branch
                continue
            }
            if (-Not ($remoteBranches.Contains($local.Trim()))) {
                # local branch not anymore a remote branch, so it can be deleted locally
                Write-Log ([string] (git branch -D $local.Trim() 2>&1))
            }
        }
    }

    end {
    }
}
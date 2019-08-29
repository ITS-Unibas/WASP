function Remove-HandledBranches {
    <#
    .SYNOPSIS
        Removes branches which already have been handled
    .DESCRIPTION
        Remove remote and local development branches of a package if the pull request has been declined or accepted and moved to the prod branch
    #>
    [CmdletBinding()]
    param (

    )

    begin {
        $config = Read-ConfigFile

        $GitRepo = $config.Application.$PackagesIncomingFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesIncomingFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.$WindowsSoftware
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $WindowsSoftwarePath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        Write-Log "Getting branches with status: Open"
        # Get all branches which have open pull requests in windows software repo from packages incoming filtered
        $pullrequestsOpen = Get-RemoteBranchesByStatus $WinSoftwareRepoName 'Open'
        # Get all branches in packages incoming filtered repository
        $PackagesIncomingFilteredBranches = Get-RemoteBranches $PackagesFilteredRepoName
        $nameAndVersionSeparator = '@'

        ForEach ($remoteBranch in $PackagesIncomingFilteredBranches) {

            Set-Location $PackagesIncomingFilteredPath
            Write-Log ([string](git pull 2>&1))

            if ((-Not ($remoteBranch -eq 'master')) -and ((-Not $pullrequestsOpen.contains($remoteBranch)) -or $pullrequestsOpen.length -eq 0)) {
                Write-Log "PR for $remoteBranch is not Open anymore. Deleting from our filtered packages, because it was merged or declined..."
                Remove-RemoteBranch $PackagesFilteredRepoName $remoteBranch
                Switch-GitBranch 'master'
                # Delete the local branch
                Write-Log ([string](git branch -D $remoteBranch 2>&1))

                Set-Location $WindowsSoftwarePath

                $packageName, $packageVersion = $remoteBranch.split($nameAndVersionSeparator)
                $packageName = $packageName -replace $config.Application.GitBranchDEV, ""

                if (-Not (Test-Path ('.\' + $packageName + '\' + $packageVersion))) {
                    # The branch on windows software was not merged, because there is no package folder, so we have to delete it.
                    Write-Log "Deleting branch $remoteBranch in Windows software because the PR was declined."
                    Remove-RemoteBranch $WinSoftwareRepoName $remoteBranch
                    # Checkout prod and
                    Switch-GitBranch $config.Application.GitBranchPROD
                    # Delete the local branch
                    Write-Log ([string](git branch -D $remoteBranch 2>&1))
                }
            }

        }

        # TODO: Is this necessary?
        Set-Location ..
    }
}
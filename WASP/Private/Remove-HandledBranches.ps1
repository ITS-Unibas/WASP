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

        $GitRepo = $config.Application.$PackagesInboxFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName
    }

    process {
        Write-Log "Getting branches with status: Open"
        # Get all branches which have open pull requests in windows software repo from packages incoming filtered
        $pullrequestsOpen = Get-RemoteBranchesByStatus $WinSoftwareRepoName 'Open'
        # Get all branches in packages incoming filtered repository
        $PackagesInboxFilteredBranches = Get-RemoteBranches $PackagesFilteredRepoName

        ForEach ($remoteBranch in $PackagesInboxFilteredBranches) {
            Set-Location $PackagesInboxFilteredPath
            if ((-Not ($remoteBranch -eq 'master')) -and ((-Not $pullrequestsOpen.contains($remoteBranch)) -or $pullrequestsOpen.length -eq 0)) {
                Write-Log "PR for $remoteBranch is not open anymore. Deleting branch from our filtered packages, because it was merged or declined..."
                # Remove remote package branch in filtered repository
                Remove-RemoteBranch $PackagesFilteredRepoName $remoteBranch
                # Switch to master branch
                Switch-GitBranch 'master'
                # Delete the local branch
                Write-Log ([string](git branch -D $remoteBranch 2>&1))
            }
        }

        # Remove local branches from package-gallery where the remote branch does not exist anymore
        Remove-LocalBranches $config.Application.WindowsSoftware
    }
}
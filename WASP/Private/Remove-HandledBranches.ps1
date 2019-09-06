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

        $GitRepo = $config.Application.PackagesInboxFiltered
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $GitFolderName = $GitFile.Replace(".git", "")
        $PackagesInboxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $GitFolderName

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $PackageGalleryRepositoryName = $GitFile.Replace(".git", "")
    }

    process {
        Write-Log "Getting branches with pull request status: Open"
        # Get all branches which have open pull requests in windows software repo from packages incoming filtered
        $pullrequestsOpen = Get-RemoteBranchesByStatus $PackageGalleryRepositoryName 'Open'
        # Get all branches in packages incoming filtered repository
        $PackagesInboxFilteredBranches = Get-RemoteBranches $Repository
        # Checkout master branch on packages-inbox-filtered to avoid beeing on a branch to delete
        Write-Log ([string](git -C $PackagesInboxFilteredPath checkout 'master' 2>&1))
        ForEach ($remoteBranch in $PackagesInboxFilteredBranches) {
            if ((-Not ($remoteBranch -eq 'master')) -and ((-Not $pullrequestsOpen.contains($remoteBranch)) -or $pullrequestsOpen.length -eq 0)) {
                Write-Log "PR for $remoteBranch is not open anymore. Deleting branch from our filtered packages, because it was merged or declined..."
                # Remove remote package branch in filtered repository
                Remove-RemoteBranch $PackagesFilteredRepoName $remoteBranch
                # Delete the local branch
                Write-Log ([string](git -C $PackagesInboxFilteredPath branch -D $remoteBranch 2>&1))
            }
        }

        # Remove local branches from package-gallery where the remote branch does not exist anymore
        Remove-LocalBranches $config.Application.PackageGallery
    }
}
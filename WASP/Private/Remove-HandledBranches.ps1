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
        $PackagesInboxFilteredRepoName = $GitFile.Replace(".git", "")
        $PackagesInboxFilteredPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $PackagesInboxFilteredRepoName

        $GitRepo = $config.Application.PackageGallery
        $GitFile = $GitRepo.Substring($GitRepo.LastIndexOf("/") + 1, $GitRepo.Length - $GitRepo.LastIndexOf("/") - 1)
        $PackageGalleryRepositoryName = $GitFile.Replace(".git", "")
    }

    process {
        Write-Log "Getting branches with pull request status: Open"
        # Get all branches which have open pull requests in windows software repo from packages incoming filtered
        $pullrequestsOpen = Get-RemoteBranchesByStatus $PackageGalleryRepositoryName 'Open'
        # Get all branches in packages incoming filtered repository
        $PackagesInboxFilteredBranches = Get-RemoteBranches $PackagesInboxFilteredRepoName
        # Checkout master branch on packages-inbox-filtered to avoid beeing on a branch to delete
        Switch-GitBranch $PackagesInboxFilteredPath 'master'
        ForEach ($remoteBranch in $PackagesInboxFilteredBranches) {
            if ((-Not ($remoteBranch -eq 'master')) -and (($pullrequestsOpen.Count -eq 0 -or -Not $pullrequestsOpen.contains($remoteBranch)))) {
                Write-Log "The pull request for $remoteBranch is was either declined or merged and can therefore be deleted."
                # Remove remote package branch in filtered repository
                Remove-RemoteBranch $PackagesInboxFilteredRepoName $remoteBranch
            }
        }
        # Remove local branches from inbox filtered where the corresponding remote branch does not exist anymore
        Remove-LocalBranches $config.Application.PackagesInboxFiltered

        # Remove local branches from package-gallery where the corresponding remote branch does not exist anymore
        Remove-LocalBranches $config.Application.PackageGallery
    }
}
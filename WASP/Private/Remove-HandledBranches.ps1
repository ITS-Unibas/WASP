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
        $PackagesGalleryPath = Join-Path -Path $config.Application.BaseDirectory -ChildPath $PackageGalleryRepositoryName

        $GitHubUser = $config.Application.GitHubUser
        $GitHubOrganisation =  $config.Application.GitHubOrganisation

    }

    process {
        Write-Log "$($PackageGalleryRepositoryName): Checking branches with PR status: Open"
        # Get all branches which have open pull requests in package gallery
        $pullrequestsOpen = Get-RemoteBranchesByStatus -Repo $PackageGalleryRepositoryName -User $GitHubOrganisation -Status 'Open'

        # Get all branches in packages incoming filtered repository
        $PackagesInboxFilteredRemoteBranches = Get-RemoteBranches -Repo $PackagesInboxFilteredRepoName -User $GitHubUser
        
        # Checkout master branch on packages-inbox-filtered to avoid beeing on a branch to delete
        Switch-GitBranch $PackagesInboxFilteredPath 'main'
        ForEach ($remoteBranch in $PackagesInboxFilteredRemoteBranches) {
            if ((-Not ($remoteBranch -eq 'main')) -and (($pullrequestsOpen.Count -eq 0 -or -Not $pullrequestsOpen.contains($remoteBranch)))) {
                Write-Log "Pull request for $remoteBranch was declined or merged and will be deleted from '$PackagesInboxFilteredRepoName'."
                # Remove remote package branch in filtered repository
                Remove-RemoteBranch -Repo $PackagesInboxFilteredRepoName -Branch $remoteBranch -User $GitHubUser
            }
        }
        
        # Remove local branches from inbox filtered where the corresponding remote branch does not exist anymore
        Remove-LocalBranches -Repo $config.Application.PackagesInboxFiltered -User $GitHubUser

        Write-Log "$($PackageGalleryRepositoryName): Checking all dev-branches for automatic deletion"

        # Get all branches in package gallery
        $PackagesGalleryRemoteBranches = Get-RemoteBranches -Repo $PackageGalleryRepositoryName -User $GitHubOrganisation
        
        # Checkout prod branch on package gallery to avoid beeing on a branch to delete
        Switch-GitBranch $PackagesGalleryPath 'prod'
        ForEach ($remoteBranch in $PackagesGalleryRemoteBranches) {
            # Remove all dev-branches where:
            # + the initial PR to the package-gallery was declined or [= state is "closed" no "merge-at"-Flag]
            # + the repackaging-branch is finished processing [= PR "merged to prod"-state is "closed" and "merge-at"-Flag is set]
            
            $packageInfos   = $remoteBranch.split("@")
            $packageName    = $packageInfos[0].replace("dev/", "")
            $packageVersion = $packageInfos[1]

            if (($packageInfos.Length) -eq 3){
                $testPullRequest = Test-PullRequest -Repository $PackageGalleryRepositoryName -User $GitHubOrganisation -Branch $remoteBranch -Repackaging
            } else {
                $testPullRequest = Test-PullRequest -Repository $PackageGalleryRepositoryName -User $GitHubOrganisation -Branch $remoteBranch
            }         

            if ((-Not (($remoteBranch -eq 'prod') -or ($remoteBranch -eq 'test'))) -and ($testPullRequest -eq $true)) {
                if (($packageInfos.Length) -eq 3){
                    Write-Log "'$remoteBranch' merged into prod and will be deleted from '$PackageGalleryRepositoryName'."
                } else {    
                    Write-Log "Pull request for $remoteBranch was declined and will be deleted from '$PackageGalleryRepositoryName'."
                }
                # Remove remote branch in pacakge gallery
                Remove-RemoteBranch -Repo $PackageGalleryRepositoryName -Branch $remoteBranch -User $GitHubOrganisation
            }

            # Stop here for repackaging-Branches because the next step would otherwise remove the repackaging-Branches
            if (($packageInfos.Length) -eq 3){
                continue
            }

            # Remove all dev-branches that are merged into prod            
            # Check if merged into prod by looking at the existence of a nuspec-File in prod branch
            $devBranchMergedIntoProd = Test-Path -Path ("$PackagesGalleryPath" + "\" + $packageName + "\" + $packageVersion + "\" + "$packageName.nuspec")

            if ((-Not (($remoteBranch -eq 'prod') -or ($remoteBranch -eq 'test'))) -and ($devBranchMergedIntoProd -eq $true)) {
                Write-Log "'$remoteBranch' merged into prod and will be deleted from '$PackageGalleryRepositoryName'."
                # Remove remote branch in pacakge gallery
                Remove-RemoteBranch -Repo $PackageGalleryRepositoryName -Branch $remoteBranch -User $GitHubOrganisation
            }
        }
        # Remove local branches from package-gallery where the corresponding remote branch does not exist anymore
        Remove-LocalBranches -Repository $PackageGalleryRepositoryName -User $GitHubOrganisation
    }
}
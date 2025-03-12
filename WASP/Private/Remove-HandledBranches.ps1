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

        # Get all branches in packages-inbox-filtered repository
        $PackagesInboxFilteredRemoteBranches = Get-RemoteBranches -Repo $PackagesInboxFilteredRepoName -User $GitHubUser
        
        # Checkout main branch on packages-inbox-filtered to avoid beeing on a branch to delete
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

        # Remove all dev-branches that are declined or merged into prod
        ForEach ($remoteBranch in $PackagesGalleryRemoteBranches) {
            
            $packageInfos   = $remoteBranch.split("@")
            $packageName    = $packageInfos[0].replace("dev/", "")
            $packageVersion = $packageInfos[1]
            
            $latestPullRequest = Test-PullRequest -Branch $remoteBranch        

            $scope  = $latestPullRequest.Branch
            $state  = $latestPullRequest.Details.state
            $merged = $latestPullRequest.Details.merged_at

            # Remove all dev-branches that are merged into prod - except for branches with declinced PRs! And remove all dev-branches for new software versions when an initial PR was declined
            if (-Not (($remoteBranch -eq 'prod') -or ($remoteBranch -eq 'test')) -and ($state -eq "closed")) {
                $remove = $false
                # Check if a dev-branch was merged into prod 
                if (($scope -eq "prod") -and ($null -ne $merged)) { 
                    # Double check if the nuspec-File exists in prod branch
                    $devBranchMergedIntoProd = Test-Path -Path ("$PackagesGalleryPath" + "\" + $packageName + "\" + $packageVersion + "\" + "$packageName.nuspec")
                    if ($devBranchMergedIntoProd) {
                        Write-Log "'$remoteBranch' merged into prod and will be deleted from remote '$PackageGalleryRepositoryName'."
                        $remove = $true
                    }
                # Check if PR is declined for a new software version
                } elseif (($scope -eq "dev") -and ($null -eq $merged)) {    
                    Write-Log "Pull request for $remoteBranch was declined and will be deleted from remote '$PackageGalleryRepositoryName'."
                    $remove = $true
                }

                # Remove remote branch in pacakge gallery if the conditions are met 
                if ($remove) {
                    Remove-RemoteBranch -Repo $PackageGalleryRepositoryName -Branch $remoteBranch -User $GitHubOrganisation
                }
            }
        }
        # Remove local branches from package-gallery where the corresponding remote branch does not exist anymore
        Remove-LocalBranches -Repository $PackageGalleryRepositoryName -User $GitHubOrganisation
    }
}